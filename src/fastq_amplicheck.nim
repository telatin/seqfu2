import docopt
import malebolgia
import os
import strutils

import ./amplicheck/pairs
import ./amplicheck/report
import ./amplicheck/run
import ./amplicheck/types

type
  AmplicheckJob = object
    input: AmplicheckInput
    report: AmplicheckReport
    verboseLog: string
    errorMsg: string

proc processAmplicheckJob(job: ptr AmplicheckJob,
                          opts: AmplicheckOptions,
                          bufferVerbose: bool) {.gcsafe.} =
  {.cast(gcsafe).}:
    try:
      job[].report = analyzeInput(job[].input, opts, job[].verboseLog,
                                  bufferVerbose)
    except CatchableError as e:
      job[].errorMsg = e.msg

proc parseStageName(raw: string, stage: var AmplicheckStage): bool =
  case raw.strip().toLowerAscii()
  of "primers", "primer":
    stage = stPrimers
  of "length", "lengths":
    stage = stLength
  of "quality", "qual":
    stage = stQuality
  of "merge", "overlap":
    stage = stMerge
  of "sweep":
    stage = stSweep
  else:
    return false
  true

proc parseStageList(raw: string, stages: var set[AmplicheckStage],
                    err: var string): bool =
  stages = {}
  for item in raw.split(','):
    if item.strip().len == 0:
      continue
    var stage: AmplicheckStage
    if not parseStageName(item, stage):
      err = "invalid stage: " & item
      return false
    stages.incl(stage)
  true

proc parseAmpliconMode(raw: string, mode: var AmpliconMode): bool =
  case raw.toLowerAscii()
  of "auto":
    mode = amAuto
  of "16s", "16S":
    mode = am16s
  of "its", "ITS":
    mode = amIts
  else:
    return false
  true

proc parseIntGrid(raw: string, values: var seq[int], err: var string): bool =
  values = @[]
  if raw == "nil" or raw.strip().len == 0:
    return true
  for item in raw.split(','):
    try:
      let value = parseInt(item.strip())
      if value < 0:
        err = "truncLen-grid values must be >= 0"
        return false
      values.add(value)
    except ValueError:
      err = "invalid truncLen-grid value: " & item
      return false
  true

proc parseFloatGrid(raw: string, values: var seq[float], err: var string): bool =
  values = @[]
  if raw == "nil" or raw.strip().len == 0:
    return true
  for item in raw.split(','):
    try:
      let value = parseFloat(item.strip())
      if value <= 0.0:
        err = "maxEE-grid values must be > 0"
        return false
      values.add(value)
    except ValueError:
      err = "invalid maxEE-grid value: " & item
      return false
  true

proc parsePrimerList(raw, optionName: string, values: var seq[string],
                     err: var string): bool =
  values = @[]
  if raw == "nil":
    return true
  for item in raw.split(','):
    let primer = item.strip().toUpperAscii()
    if primer.len == 0:
      err = optionName & " contains an empty primer"
      return false
    for base in primer:
      if base notin {'A', 'C', 'G', 'T', 'U', 'R', 'Y', 'S', 'W', 'K', 'M',
                     'B', 'D', 'H', 'V', 'N'}:
        err = optionName & " contains an invalid IUPAC base: " & $base
        return false
    if primer notin values:
      values.add(primer)
  true

proc fastq_amplicheck*(argv: var seq[string]): int =
  var
    singleEndRequested = false
    docoptArgv: seq[string]
  for arg in argv:
    if arg == "--single-end":
      singleEndRequested = true
    else:
      docoptArgv.add(arg)

  let args = docopt("""
Usage:
  amplicheck [options] <FASTQ>...

Inspect amplicon FASTQ files and write DADA2-ready QC recommendations. One
positional file is treated as single-end. Exactly two files are treated as one
pair; larger inputs are paired by forward/reverse tag substitution unless
--single-end is used.

Input and pairing:
  --single-end              Treat every positional FASTQ as a separate sample
  --fwd-tag STR             Forward read tag for batch pairing [default: _R1]
  --rev-tag STR             Reverse read tag for batch pairing [default: _R2]

Sampling and analysis:
  --max-reads INT           Stop after INT scanned reads or pairs per sample; 0 = all [default: 500000]
  --subsample FLOAT         Deterministic fraction of scanned reads or pairs to analyze [default: 1.0]
  --amplicon MODE           One of auto, 16s, its [default: auto]

Analysis stages:
  --only STAGES             Run only comma-separated stages: primers,length,quality,merge,sweep
  --skip STAGES             Skip comma-separated stages; "overlap" is accepted as "merge"
  --skip-primers            Shortcut for --skip primers
  --skip-overlap            Shortcut for --skip merge

Primer detection:
  --fwd-primers LIST        Comma-separated forward primer sequences
  --rev-primers LIST        Comma-separated reverse primer sequences

Paired-end sweep:
  --sweep                   Run truncLen/maxEE sweep
  --truncLen-grid LIST      Comma-separated truncLen values for --sweep; 0 = no truncation
  --maxEE-grid LIST         Comma-separated maxEE values for --sweep

Output:
  --outdir DIR              Output directory [default: amplicheck_out]
  --json                    Write JSON report (default)
  --no-json                 Do not write JSON report
  --text                    Write human-readable report.txt
  --plot                    Write self-contained HTML quality plots

Execution:
  --threads INT             Number of samples to process in parallel [default: 1]

Paired-end overlap:
  --min-overlap INT         Minimum overlap length for native estimator [default: 12]
  --min-id FLOAT            Minimum overlap identity for native estimator [default: 0.85]

Recommendations:
  --min-recommend-reads INT  Minimum sampled reads required for recommendations [default: 5000]

Other options:
  -v, --verbose             Print progress messages
  -h, --help                Show this help
""", version=version(), argv=docoptArgv)

  var opts = AmplicheckOptions(
    fwdTag: $args["--fwd-tag"],
    revTag: $args["--rev-tag"],
    outdir: $args["--outdir"],
    stages: {stPrimers, stLength, stQuality, stMerge},
    writeJson: not bool(args["--no-json"]),
    writeText: bool(args["--text"]),
    plot: bool(args["--plot"]),
    verbose: bool(args["--verbose"])
  )
  let files = @(args["<FASTQ>"])
  if files.len == 0:
    stderr.writeLine("ERROR: amplicheck requires at least one FASTQ file.")
    return 1
  let singleEnd = singleEndRequested or files.len == 1
  if singleEnd:
    opts.stages.excl(stMerge)

  if bool(args["--json"]) and bool(args["--no-json"]):
    stderr.writeLine("ERROR: --json and --no-json are mutually exclusive.")
    return 1

  if not opts.writeJson and not opts.writeText and not opts.plot:
    stderr.writeLine("ERROR: at least one output format must be enabled.")
    return 1

  var err = ""
  try:
    opts.maxReads = parseInt($args["--max-reads"])
    opts.minRecommendReads = parseInt($args["--min-recommend-reads"])
    opts.subsample = parseFloat($args["--subsample"])
    opts.minOverlap = parseInt($args["--min-overlap"])
    opts.minIdentity = parseFloat($args["--min-id"])
  except ValueError as e:
    stderr.writeLine("ERROR: invalid numeric option: ", e.msg)
    return 1

  if opts.maxReads < 0:
    stderr.writeLine("ERROR: --max-reads must be >= 0.")
    return 1
  if opts.minRecommendReads < 1:
    stderr.writeLine("ERROR: --min-recommend-reads must be >= 1.")
    return 1
  if opts.subsample <= 0.0 or opts.subsample > 1.0:
    stderr.writeLine("ERROR: --subsample must satisfy 0 < value <= 1.")
    return 1
  if opts.minOverlap < 1:
    stderr.writeLine("ERROR: --min-overlap must be >= 1.")
    return 1
  if opts.minIdentity <= 0.0 or opts.minIdentity > 1.0:
    stderr.writeLine("ERROR: --min-id must satisfy 0 < value <= 1.")
    return 1

  var threads: int
  try:
    threads = parseInt($args["--threads"])
  except ValueError:
    stderr.writeLine("ERROR: --threads must be an integer >= 1.")
    return 1
  if threads < 1:
    stderr.writeLine("ERROR: --threads must be >= 1.")
    return 1

  if not parseAmpliconMode($args["--amplicon"], opts.amplicon):
    stderr.writeLine("ERROR: --amplicon must be one of auto, 16s, its.")
    return 1

  if not parsePrimerList($args["--fwd-primers"], "--fwd-primers",
                         opts.customFwdPrimers, err):
    stderr.writeLine("ERROR: ", err)
    return 1
  if not parsePrimerList($args["--rev-primers"], "--rev-primers",
                         opts.customRevPrimers, err):
    stderr.writeLine("ERROR: ", err)
    return 1

  let onlyRaw = $args["--only"]
  let skipRaw = $args["--skip"]
  var pairOnlyStageRequested = false
  if onlyRaw != "nil" and skipRaw != "nil":
    stderr.writeLine("ERROR: --only and --skip are mutually exclusive.")
    return 1

  if onlyRaw != "nil":
    if not parseStageList(onlyRaw, opts.stages, err):
      stderr.writeLine("ERROR: ", err)
      return 1
    pairOnlyStageRequested = stMerge in opts.stages or stSweep in opts.stages
  elif skipRaw != "nil":
    var skipped: set[AmplicheckStage]
    if not parseStageList(skipRaw, skipped, err):
      stderr.writeLine("ERROR: ", err)
      return 1
    opts.stages = opts.stages - skipped

  if bool(args["--skip-primers"]):
    opts.stages.excl(stPrimers)
  if bool(args["--skip-overlap"]):
    opts.stages.excl(stMerge)
  if bool(args["--sweep"]):
    opts.stages.incl(stSweep)
    pairOnlyStageRequested = true

  if singleEnd and pairOnlyStageRequested:
    stderr.writeLine("ERROR: merge and sweep stages require paired-end input.")
    return 1

  if singleEnd and opts.verbose:
    stderr.writeLine("amplicheck: single-end mode: pair-only merge and sweep stages are disabled")

  if opts.plot and not (stQuality in opts.stages):
    stderr.writeLine("ERROR: --plot requires the quality stage.")
    return 1

  if not parseIntGrid($args["--truncLen-grid"], opts.truncLenGrid, err):
    stderr.writeLine("ERROR: ", err)
    return 1
  if not parseFloatGrid($args["--maxEE-grid"], opts.maxEEGrid, err):
    stderr.writeLine("ERROR: ", err)
    return 1
  if stSweep in opts.stages and (opts.truncLenGrid.len == 0 or opts.maxEEGrid.len == 0):
    stderr.writeLine("ERROR: --sweep requires both --truncLen-grid and --maxEE-grid.")
    return 1

  if not singleEnd and files.len > 2 and (opts.fwdTag.len == 0 or opts.revTag.len == 0):
    stderr.writeLine("ERROR: --fwd-tag and --rev-tag cannot be empty in batch mode.")
    return 1

  var warnings: seq[string]
  let inputs =
    if singleEnd: discoverSingles(files, opts.fwdTag)
    else: discoverPairs(files, opts.fwdTag, opts.revTag, warnings)
  for warning in warnings:
    stderr.writeLine(warning)
  if inputs.len == 0:
    stderr.writeLine("ERROR: no FASTQ inputs found.")
    return 1

  for input in inputs:
    if not fileExists(input.r1):
      stderr.writeLine("ERROR: input file not found: ", input.r1)
      return 1
    if input.layout == rlPairedEnd and not fileExists(input.r2):
      stderr.writeLine("ERROR: R2 file not found: ", input.r2)
      return 1

  var jobs = newSeq[AmplicheckJob](inputs.len)
  for i, input in inputs:
    jobs[i].input = input

  try:
    if threads > 1 and jobs.len > 1:
      let parallelChunk = min(jobs.len, min(threads, ThreadPoolSize))
      if opts.verbose:
        stderr.writeLine("amplicheck: processing ", jobs.len,
                         " samples with ", parallelChunk, " threads")
      var
        master = createMaster()
        start = 0
      while start < jobs.len:
        let stopAt = min(start + parallelChunk, jobs.len)
        if opts.verbose:
          for i in start ..< stopAt:
            stderr.writeLine("amplicheck: starting ", jobs[i].input.sampleId)
        master.awaitAll:
          for i in start ..< stopAt:
            master.spawn processAmplicheckJob(addr jobs[i], opts, true)
        for i in start ..< stopAt:
          if opts.verbose and jobs[i].verboseLog.len > 0:
            stderr.write(jobs[i].verboseLog)
          if jobs[i].errorMsg.len > 0:
            stderr.writeLine("ERROR: sample ", jobs[i].input.sampleId,
                             ": ", jobs[i].errorMsg)
            return 1
          if opts.verbose:
            stderr.write(jobs[i].report.renderVerboseSummary())
        start = stopAt
    else:
      for i in 0 ..< jobs.len:
        if opts.verbose:
          stderr.writeLine("amplicheck: starting ", jobs[i].input.sampleId)
        processAmplicheckJob(addr jobs[i], opts, false)
        if jobs[i].errorMsg.len > 0:
          stderr.writeLine("ERROR: sample ", jobs[i].input.sampleId,
                           ": ", jobs[i].errorMsg)
          return 1
        if opts.verbose:
          stderr.write(jobs[i].report.renderVerboseSummary())
  except CatchableError as e:
    stderr.writeLine("ERROR: ", e.msg)
    return 1

  var reports = newSeqOfCap[AmplicheckReport](jobs.len)
  for job in jobs:
    reports.add(job.report)

  writeReports(reports, opts.outdir, opts.writeJson, opts.writeText, opts.plot)
  return 0
