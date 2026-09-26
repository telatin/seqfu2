import std/[os, strutils, tables]
import docopt
import malebolgia
import readfx
import ./adapters_utils
import ./filter_utils
import ./seqfu_utils

type
  AdapterRunOptions = object
    inputFirst, inputSecond: string
    outputFirst, outputSecond: string
    paired, splitOutput, keepUntrimmed, printStats: bool
    threads, batchSize, gzipLevel: int
    worker: AdapterWorkerOptions

proc adapterParseInt(value, option: string): int =
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(ValueError, option & " requires an integer: " & value)

proc adapterParseFloat(value, option: string): float =
  try:
    result = parseFloat(value)
  except ValueError:
    raise newException(ValueError, option & " requires a number: " & value)

proc adapterOutputPlan(paired: bool, first, second: string): FilterOutputPlan =
  result.first = first
  if second.len > 0:
    if not paired:
      raise newException(ValueError, "-O requires paired input")
    result.second = second
    result.splitPairs = true
  if result.splitPairs and result.first == result.second:
    raise newException(ValueError, "R1 and R2 output paths must differ")

proc adapterValidateOptions(options: AdapterRunOptions) =
  if options.inputFirst.len == 0:
    raise newException(ValueError, "-1 is required")
  if options.inputFirst != "-" and not fileExists(options.inputFirst):
    raise newException(IOError, "Input file not found: " & options.inputFirst)
  if options.paired:
    if options.inputSecond == options.inputFirst:
      raise newException(ValueError, "-1 and -2 must name different streams")
    if options.inputSecond != "-" and not fileExists(options.inputSecond):
      raise newException(IOError, "Input file not found: " & options.inputSecond)
  if options.worker.matchOptions.errorRate < 0.0 or
      options.worker.matchOptions.errorRate > 1.0:
    raise newException(ValueError, "--error-rate must be between 0 and 1")
  if options.worker.matchOptions.minOverlap < 1:
    raise newException(ValueError, "--overlap must be positive")
  if options.threads < 1 or options.threads > ThreadPoolSize:
    raise newException(ValueError, "--threads must be between 1 and " & $ThreadPoolSize)
  if options.batchSize < 1:
    raise newException(ValueError, "--batch-size must be positive")
  if options.gzipLevel < 0 or options.gzipLevel > 9:
    raise newException(ValueError, "--gzip-level must be between 0 and 9")
  let plan = adapterOutputPlan(options.paired, options.outputFirst,
                               options.outputSecond)
  validateFilterOutputs(plan, @[options.inputFirst, options.inputSecond])

proc adapterWriteBatches(batches: var seq[AdapterBatch],
                         outputFirst: var FastxWriter,
                         outputSecond: var FastxWriter,
                         options: var AdapterRunOptions,
                         stats: var AdapterStats) =
  runAdapterWorkers(batches, options.worker, options.threads)
  for batch in batches:
    for i in 0 ..< batch.first.len:
      inc stats.processed
      let firstMatched = not options.worker.hasFirstSpec or
        adapterSpecMatched(batch.resultsFirst[i], options.worker.firstSpec)
      let secondMatched = not batch.paired or not options.worker.hasSecondSpec or
        adapterSpecMatched(batch.resultsSecond[i], options.worker.secondSpec)
      let nonEmpty = batch.resultsFirst[i].record.sequence.len > 0 and
        (not batch.paired or batch.resultsSecond[i].record.sequence.len > 0)
      let keep = (options.keepUntrimmed or (firstMatched and secondMatched)) and nonEmpty
      if keep:
        inc stats.written
        stats.updateAdapterStats(batch.resultsFirst[i])
        outputFirst.writeAdapterResult(batch.resultsFirst[i])
        if batch.paired:
          stats.updateAdapterStats(batch.resultsSecond[i])
          if options.splitOutput:
            outputSecond.writeAdapterResult(batch.resultsSecond[i])
          else:
            outputFirst.writeAdapterResult(batch.resultsSecond[i])
      else:
        inc stats.discarded
  batches.setLen(0)

proc runAdapters(options: var AdapterRunOptions): AdapterStats =
  adapterValidateOptions(options)
  let plan = adapterOutputPlan(options.paired, options.outputFirst,
                               options.outputSecond)
  options.splitOutput = plan.splitPairs
  var outputFirst = openFilterWriter(plan.first, fxfFastq, options.gzipLevel)
  var outputSecond: FastxWriter
  try:
    if plan.splitPairs:
      outputSecond = openFilterWriter(plan.second, fxfFastq, options.gzipLevel)
  except CatchableError:
    outputFirst.close()
    raise
  defer:
    outputFirst.close()
    if plan.splitPairs:
      outputSecond.close()

  var batches: seq[AdapterBatch]
  var current = AdapterBatch(paired: options.paired)
  let batchWindow = max(1, options.threads)

  template flushIfReady() =
    if current.first.len >= options.batchSize:
      batches.add(move(current))
      current = AdapterBatch(paired: options.paired)
      if batches.len >= batchWindow:
        adapterWriteBatches(batches, outputFirst, outputSecond, options, result)

  if options.paired:
    for pair in readFQPairPtr(options.inputFirst, options.inputSecond):
      current.first.add(copyFilterRecord(pair.read1))
      current.second.add(copyFilterRecord(pair.read2))
      flushIfReady()
  else:
    for record in readFQPtr(options.inputFirst):
      if record.qualityLen == 0:
        raise newException(ValueError, "adapters and primers require FASTQ input")
      current.first.add(copyFilterRecord(record))
      flushIfReady()
  if current.first.len > 0:
    batches.add(move(current))
  adapterWriteBatches(batches, outputFirst, outputSecond, options, result)

proc adapterCommonOptions(args: Table[string, Value],
                          keepUntrimmed: bool): AdapterRunOptions =
  result.inputFirst = $args["--r1"]
  let second = $args["--r2"]
  result.inputSecond = if second == "nil": "" else: second
  result.paired = result.inputSecond.len > 0
  result.outputFirst = $args["--output"]
  let outputSecond = $args["--output-r2"]
  result.outputSecond = if outputSecond == "nil": "" else: outputSecond
  result.keepUntrimmed = keepUntrimmed
  result.printStats = bool(args["--stats"])
  result.threads = adapterParseInt($args["--threads"], "--threads")
  result.batchSize = adapterParseInt($args["--batch-size"], "--batch-size")
  result.gzipLevel = adapterParseInt($args["--gzip-level"], "--gzip-level")
  result.worker.matchOptions = AdapterMatchOptions(
    errorRate: adapterParseFloat($args["--error-rate"], "--error-rate"),
    minOverlap: adapterParseInt($args["--overlap"], "--overlap"),
    allowIndels: not bool(args["--no-indels"]))

proc printAdapterStats(command: string, stats: AdapterStats, paired: bool) =
  stderr.writeLine("[", command, "] processed: ", stats.processed,
    if paired: " pairs" else: " reads", "; written: ", stats.written,
    "; discarded: ", stats.discarded, "; 5' trimmed: ",
    stats.trimmedFivePrime, "; 3' trimmed: ", stats.trimmedThreePrime)

proc reportKnownAdapter(mate: string, detection: KnownAdapterDetection) =
  if detection.found:
    let description = detection.adapter.description.strip(chars = {'>', ' '})
    stderr.writeLine("[adapters] detected ", mate, " adapter: ",
      detection.adapter.sequence, " (", description, "; ", detection.hits,
      "/", detection.scannedReads, " sampled reads)")
  else:
    stderr.writeLine("[adapters] no known adapter detected for ", mate,
      " in ", detection.scannedReads, " sampled reads")

proc adapters*(argv: var seq[string]): int =
  let doc = """
Usage:
  adapters [options] -1 FILE -o FILE

Trim 3' or linked adapters from FASTQ reads. A plain SPEC is a 3' adapter;
FRONT...BACK is a linked adapter with required FRONT and optional BACK.
Without -a/-A, known adapters are detected automatically unless -K is used.
Explicit adapter specifications disable known-adapter detection.

Input and adapters:
  -a, --adapter SPEC         R1 adapter specification
  -A, --adapter-r2 SPEC      R2 adapter specification
  -K, --skip-known-adapters  Skip automatic known-adapter detection
  -1, --r1 FILE             R1 or single-end FASTQ
  -2, --r2 FILE             R2 FASTQ

Output:
  -o, --output FILE         R1 output, or interleaved paired output
  -O, --output-r2 FILE      Separate R2 output
  --discard-untrimmed       Discard reads/pairs without required matches
  --gzip-level INT          Gzip compression level [default: 6]

Matching:
  -e, --error-rate FLOAT    Maximum errors per aligned adapter base [default: 0.1]
  --overlap INT             Minimum adapter overlap [default: 3]
  --no-indels               Allow substitutions only

Performance and reporting:
  -t, --threads INT         Worker threads [default: 1]
  --batch-size INT          Reads or pairs per batch [default: 4096]
  --stats                   Print trimming counts to stderr
  -h, --help                Show this help
"""
  let args = docopt(doc, argv = argv, version = version())
  try:
    var options = adapterCommonOptions(args,
      keepUntrimmed = not bool(args["--discard-untrimmed"]))
    let skipKnownAdapters = bool(args["--skip-known-adapters"])
    let firstSpec = $args["--adapter"]
    let secondSpec = $args["--adapter-r2"]
    let hasFirstSpec = firstSpec != "nil"
    let hasSecondSpec = secondSpec != "nil"
    if hasFirstSpec or hasSecondSpec:
      if hasFirstSpec:
        options.worker.firstSpec = parseAdapterSpec(firstSpec)
        options.worker.hasFirstSpec = true
      if hasSecondSpec:
        if not options.paired:
          raise newException(ValueError, "-A requires paired input")
        options.worker.secondSpec = parseAdapterSpec(secondSpec)
        options.worker.hasSecondSpec = true
    elif not skipKnownAdapters:
      adapterValidateOptions(options)
      let firstDetection = detectKnownAdapter(options.inputFirst,
        options.worker.matchOptions.errorRate,
        options.worker.matchOptions.minOverlap)
      reportKnownAdapter("R1", firstDetection)
      if firstDetection.found:
        options.worker.firstSpec = parseAdapterSpec(firstDetection.adapter.sequence)
        options.worker.hasFirstSpec = true
      if options.paired:
        let secondDetection = detectKnownAdapter(options.inputSecond,
          options.worker.matchOptions.errorRate,
          options.worker.matchOptions.minOverlap)
        reportKnownAdapter("R2", secondDetection)
        if secondDetection.found:
          options.worker.secondSpec = parseAdapterSpec(secondDetection.adapter.sequence)
          options.worker.hasSecondSpec = true
    let stats = runAdapters(options)
    if options.printStats:
      printAdapterStats("adapters", stats, options.paired)
    return 0
  except CatchableError as error:
    stderr.writeLine("ERROR: adapters: ", error.msg)
    return 1

proc primers*(argv: var seq[string]): int =
  let doc = """
Usage:
  primers [options] --fwd SEQ --rev SEQ -1 FILE -o FILE

Trim PCR primers from FASTQ reads. The expected 5' primer is required by
default; an opposite-primer read-through match at 3' is trimmed when present.

Primers and input:
  -f, --fwd SEQ             Forward primer (IUPAC DNA)
  -r, --rev SEQ             Reverse primer (IUPAC DNA)
  -1, --r1 FILE             R1 or single-end FASTQ
  -2, --r2 FILE             R2 FASTQ

Output:
  -o, --output FILE         R1 output, or interleaved paired output
  -O, --output-r2 FILE      Separate R2 output
  --keep-untrimmed          Keep reads/pairs missing expected 5' primers
  --gzip-level INT          Gzip compression level [default: 6]

Matching:
  -e, --error-rate FLOAT    Maximum errors per aligned primer base [default: 0.1]
  --overlap INT             Minimum primer overlap [default: 8]
  --no-indels               Allow substitutions only

Performance and reporting:
  -t, --threads INT         Worker threads [default: 1]
  --batch-size INT          Reads or pairs per batch [default: 4096]
  --stats                   Print trimming counts to stderr
  -h, --help                Show this help
"""
  let args = docopt(doc, argv = argv, version = version())
  try:
    var options = adapterCommonOptions(args,
      keepUntrimmed = bool(args["--keep-untrimmed"]))
    let forward = $args["--fwd"]
    let reverse = $args["--rev"]
    options.worker.firstSpec = linkedPrimerSpec(forward, reverse)
    options.worker.hasFirstSpec = true
    if options.paired:
      options.worker.secondSpec = linkedPrimerSpec(reverse, forward)
      options.worker.hasSecondSpec = true
    let stats = runAdapters(options)
    if options.printStats:
      printAdapterStats("primers", stats, options.paired)
    return 0
  except CatchableError as error:
    stderr.writeLine("ERROR: primers: ", error.msg)
    return 1
