## seqfu tail — Print the last sequences from FASTA/FASTQ files.
##
## Selects sequences from the end of each input file, with optional
## subsampling via --skip. Must read the entire file to determine the
## last N sequences. Supports renaming, format conversion, interleaved
## paired-end input, and streaming from stdin.

import readfx
import strutils
import deques
import math
from os import fileExists, dirExists
import docopt
import ./seqfu_utils
import ./filter_utils


proc keepSeq(pool: var Deque[FQRecord], sequence: FQRecord, max: int) =
  ## Maintain a sliding window of the last `max` sequences using a deque.
  ## O(1) per operation, unlike seq.delete(0) which is O(n).
  if pool.len >= max:
    pool.popFirst()
  pool.addLast(sequence)

proc keepPair(pool: var Deque[(FQRecord, FQRecord)], pair: (FQRecord, FQRecord), max: int) =
  ## Maintain a sliding window of the last `max` pairs using a deque.
  if pool.len >= max:
    pool.popFirst()
  pool.addLast(pair)


proc fastx_tail(argv: var seq[string]): int =
    let args = docopt("""
Usage: tail [options] [<inputfile> ...]

Print the last sequences from FASTA/FASTQ files. The entire file must
be read to determine which sequences are last.

If no files are provided, reads from standard input.

Options:
  -n, --num NUM          Print the last NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP (0 to disable) [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  --interleaved          Treat input as interleaved paired-end; -n counts pairs
  -s, --strip-comments   Remove comments
  -b, --basename         Prepend basename to sequence name
  -v, --verbose          Verbose output
  -h, --help             Show this help

Output:
  -o, --output FILE      Write output to FILE (.gz extension for compression)
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]

  """, version=version(), argv=argv)

    # --- Set global output flags ---
    verbose       = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta    = bool(args["--fasta"])
    forceFastq    = bool(args["--fastq"])
    defaultQual   = parseInt($args["--fastq-qual"])

    # --- Parse arguments ---
    var
      num, skip    : int
      prefix       : string
      files        : seq[string]
      printBasename: bool
      separator    : string

    let interleaved = bool(args["--interleaved"])

    try:
      num  = parseInt($args["--num"])
      skip = parseInt($args["--skip"])
      printBasename = args["--basename"]
      separator = $args["--sep"]
      if num < 0 or skip < 0:
        raise newException(ValueError, "negative value")
    except ValueError:
      stderr.writeLine("Error: invalid value for --num or --skip (expected non-negative integer).")
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    # --- Open output writer (stdout, plain file, or gzip file) ---
    let outputPath = if args["--output"]: $args["--output"] else: ""
    var writer = openFilterWriter(outputPath, fxfFastq, 6)
    defer: writer.close()

    proc writeOut(rec: FQRecord) =
      ## Apply format globals and write one record to the output writer.
      var r = rec
      if stripComments:
        r.comment = ""
      if forceFasta:
        r.quality = ""
        writer.format = fxfFasta
      elif forceFastq:
        if r.quality.len == 0:
          r.quality = repeat(chr(defaultQual + 33), r.sequence.len)
        writer.format = fxfFastq
      else:
        writer.format = if r.quality.len > 0: fxfFastq else: fxfFasta
      writer.writeRecord(r)

    # --- Collect input files ---
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu tail] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)

    # --- Process each file ---
    for filename in files:
      if filename != "-" and not fileExists(filename):
        if dirExists(filename):
          stderr.writeLine("WARNING: Directories are not supported. Skipping ", filename)
        else:
          stderr.writeLine("WARNING: File not found, skipping: ", filename)
        continue

      echoVerbose(filename, verbose)

      var subsampleIdx = 0

      if interleaved:
        var
          pairCount = 0
          lastPairs = initDeque[(FQRecord, FQRecord)](nextPowerOfTwo(num))

        for pair in readFQInterleavedPair(filename):
          pairCount += 1
          if skip > 0:
            subsampleIdx = pairCount mod skip
          if subsampleIdx == 0:
            var r1 = pair.read1
            var r2 = pair.read2
            if len(prefix) > 0:
              r1.name = prefix & separator & $(pairCount * 2 - 1)
              r2.name = prefix & separator & $(pairCount * 2)
            if printBasename:
              r1.name = getBasename(filename) & separator & pair.read1.name
              r2.name = getBasename(filename) & separator & pair.read2.name
            lastPairs.keepPair((r1, r2), num)

        for (r1, r2) in lastPairs:
          writeOut(r1)
          writeOut(r2)

      else:
        var
          seqCount = 0
          lastSequences = initDeque[FQRecord](nextPowerOfTwo(num))

        for record in readFQ(filename):
          seqCount += 1
          if skip > 0:
            subsampleIdx = seqCount mod skip
          if subsampleIdx == 0:
            var outRecord = record
            if len(prefix) > 0:
              outRecord.name = prefix & separator & $seqCount
            if printBasename:
              outRecord.name = getBasename(filename) & separator & record.name
            lastSequences.keepSeq(outRecord, num)

        for tailSeq in lastSequences:
          writeOut(tailSeq)

    return 0
