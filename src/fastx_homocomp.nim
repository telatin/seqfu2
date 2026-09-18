import docopt
import malebolgia
import os
import readfx
import strutils

import ./seqfu_legacy_fastx
import ./seqfu_utils

type
  HomocompRecord = object
    record: FQRecord
    isFastq: bool

  HomocompBatch = object
    records: seq[HomocompRecord]
    output: string

proc appendRecord(output: var string, item: HomocompRecord) =
  let record = item.record
  if record.sequence.len == 0:
    output.add(if item.isFastq: '@' else: '>')
    output.add(record.name)
    if record.comment.len > 0:
      output.add(' ')
      output.add(record.comment)
    output.add('\n')
    if item.isFastq:
      output.add("\n+\n\n")
  else:
    output.add($record)
    output.add('\n')

proc processHomocompBatch(batch: ptr HomocompBatch) {.gcsafe.} =
  {.cast(gcsafe).}:
    for item in batch[].records:
      var compressed = item
      compressed.record = compressHomopolymers(item.record)
      batch[].output.appendRecord(compressed)

proc flushHomocompBatches(batches: var seq[HomocompBatch], threads: int) =
  if batches.len == 0:
    return

  if threads > 1 and batches.len > 1:
    var master = createMaster()
    master.awaitAll:
      for i in 0 ..< batches.len:
        master.spawn processHomocompBatch(addr batches[i])
  else:
    for i in 0 ..< batches.len:
      processHomocompBatch(addr batches[i])

  for batch in batches:
    stdout.write(batch.output)
  batches.setLen(0)

proc fastx_homocomp*(argv: var seq[string]): int =
  let args = docopt("""
Usage:
  homocomp [options] [<FASTX>...]

Collapse each homopolymer run to one base. FASTA and FASTQ input are supported;
FASTQ output retains the first quality score from each collapsed run.

Options:
  -t, --threads INT       Number of worker threads [default: 1]
  --batch-size INT        Records processed per worker job [default: 1000]
  -v, --verbose           Print processing information
  -h, --help              Show this help
""", version=version(), argv=argv)

  var
    threads: int
    batchSize: int
  try:
    threads = parseInt($args["--threads"])
    batchSize = parseInt($args["--batch-size"])
  except ValueError:
    stderr.writeLine("ERROR: --threads and --batch-size must be integers.")
    return 1

  if threads < 1:
    stderr.writeLine("ERROR: --threads must be >= 1.")
    return 1
  if batchSize < 1:
    stderr.writeLine("ERROR: --batch-size must be >= 1.")
    return 1

  var inputFiles = @(args["<FASTX>"])
  if inputFiles.len == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu homocomp] Waiting for STDIN... [Ctrl-C to quit, type --help for info].")
    inputFiles.add("-")

  var stdinCount = 0
  for filename in inputFiles:
    if filename == "-":
      stdinCount += 1
    elif not fileExists(filename):
      stderr.writeLine("ERROR: input file not found: ", filename)
      return 1
  if stdinCount > 1:
    stderr.writeLine("ERROR: standard input ('-') can only be specified once.")
    return 1

  let
    verbose = bool(args["--verbose"])
    jobWindow = max(1, min(threads, ThreadPoolSize))
  var
    batches = newSeqOfCap[HomocompBatch](jobWindow)
    current = HomocompBatch(records: newSeqOfCap[HomocompRecord](batchSize))
    processed = 0

  try:
    for filename in inputFiles:
      if verbose:
        stderr.writeLine("homocomp: reading ", filename)
      var
        input = xopen[GzFile](filename)
        raw: FastxRecord
      try:
        while input.readFastx(raw):
          let record = FQRecord(
            name: raw.name,
            comment: raw.comment,
            sequence: raw.seq,
            quality: raw.qual,
            status: raw.status,
            lastChar: raw.lastChar
          )
          current.records.add(HomocompRecord(
            record: record,
            isFastq: raw.lastChar == 0
          ))
          processed += 1
          if current.records.len >= batchSize:
            batches.add(move(current))
            current = HomocompBatch(records: newSeqOfCap[HomocompRecord](batchSize))
            if batches.len >= jobWindow:
              flushHomocompBatches(batches, threads)
        if raw.status < -1:
          raise newException(ValueError,
                             "unable to parse " & filename &
                             " (status " & $raw.status & ")")
      finally:
        discard input.close()

    if current.records.len > 0:
      batches.add(move(current))
    flushHomocompBatches(batches, threads)
  except CatchableError as e:
    stderr.writeLine("ERROR: ", e.msg)
    return 1

  if verbose:
    stderr.writeLine("homocomp: processed ", processed, " records")
  return 0
