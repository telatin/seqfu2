import docopt
import os
import strutils

import ./amplicheck/pairs
import ./amplicheck/report
import ./amplicheck/run
import ./amplicheck/types

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

proc fastq_amplicheck*(argv: var seq[string]): int =
  let args = docopt("""
Usage:
  amplicheck [options] <FASTQ>...

Inspect paired-end amplicon FASTQ files and write DADA2-ready QC recommendations.
Exactly two positional files are treated as one pair. More than two files are
paired by forward/reverse tag substitution.

Options:
  --fwd-tag STR             Forward read tag for batch pairing [default: _R1]
  --rev-tag STR             Reverse read tag for batch pairing [default: _R2]
  --max-reads INT           Stop after INT scanned read pairs per sample; 0 = all [default: 500000]
  --subsample FLOAT         Deterministic fraction of scanned pairs to analyze [default: 1.0]
  --only STAGES             Run only comma-separated stages: primers,length,quality,merge,sweep
  --skip STAGES             Skip comma-separated stages; "overlap" is accepted as "merge"
  --skip-primers            Shortcut for --skip primers
  --skip-overlap            Shortcut for --skip merge
  --sweep                   Run truncLen/maxEE sweep
  --truncLen-grid LIST      Comma-separated truncLen values for --sweep; 0 = no truncation
  --maxEE-grid LIST         Comma-separated maxEE values for --sweep
  --amplicon MODE           One of auto, 16s, its [default: auto]
  --outdir DIR              Output directory [default: amplicheck_out]
  --json                    Write JSON report (default)
  --no-json                 Do not write JSON report
  --text                    Write human-readable report.txt
  --plot                    Write self-contained HTML quality plots
  --threads INT             Number of sample pairs to process in parallel [default: 1]
  --min-overlap INT         Minimum overlap length for native estimator [default: 12]
  --min-id FLOAT            Minimum overlap identity for native estimator [default: 0.85]
  -v, --verbose             Print progress messages
  -h, --help                Show this help
""", version=version(), argv=argv)

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

  if bool(args["--json"]) and bool(args["--no-json"]):
    stderr.writeLine("ERROR: --json and --no-json are mutually exclusive.")
    return 1

  if not opts.writeJson and not opts.writeText and not opts.plot:
    stderr.writeLine("ERROR: at least one output format must be enabled.")
    return 1

  var err = ""
  try:
    opts.maxReads = parseInt($args["--max-reads"])
    opts.subsample = parseFloat($args["--subsample"])
    opts.minOverlap = parseInt($args["--min-overlap"])
    opts.minIdentity = parseFloat($args["--min-id"])
  except ValueError as e:
    stderr.writeLine("ERROR: invalid numeric option: ", e.msg)
    return 1

  if opts.maxReads < 0:
    stderr.writeLine("ERROR: --max-reads must be >= 0.")
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

  let threads = parseInt($args["--threads"])
  if threads < 1:
    stderr.writeLine("ERROR: --threads must be >= 1.")
    return 1
  if threads > 1:
    stderr.writeLine("ERROR: --threads > 1 is not implemented for amplicheck yet.")
    return 1

  if not parseAmpliconMode($args["--amplicon"], opts.amplicon):
    stderr.writeLine("ERROR: --amplicon must be one of auto, 16s, its.")
    return 1

  let onlyRaw = $args["--only"]
  let skipRaw = $args["--skip"]
  if onlyRaw != "nil" and skipRaw != "nil":
    stderr.writeLine("ERROR: --only and --skip are mutually exclusive.")
    return 1

  if onlyRaw != "nil":
    if not parseStageList(onlyRaw, opts.stages, err):
      stderr.writeLine("ERROR: ", err)
      return 1
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

  let files = @(args["<FASTQ>"])
  if files.len < 2:
    stderr.writeLine("ERROR: amplicheck requires at least two FASTQ files.")
    return 1
  if files.len > 2 and (opts.fwdTag.len == 0 or opts.revTag.len == 0):
    stderr.writeLine("ERROR: --fwd-tag and --rev-tag cannot be empty in batch mode.")
    return 1

  var warnings: seq[string]
  let pairs = discoverPairs(files, opts.fwdTag, opts.revTag, warnings)
  for warning in warnings:
    stderr.writeLine(warning)
  if pairs.len == 0:
    stderr.writeLine("ERROR: no paired FASTQ files found.")
    return 1

  for pair in pairs:
    if not fileExists(pair.r1):
      stderr.writeLine("ERROR: R1 file not found: ", pair.r1)
      return 1
    if not fileExists(pair.r2):
      stderr.writeLine("ERROR: R2 file not found: ", pair.r2)
      return 1

  var reports: seq[AmplicheckReport]
  try:
    for pair in pairs:
      let report = analyzePair(pair, opts)
      reports.add(report)
      if opts.verbose:
        stderr.write(report.renderVerboseSummary())
  except CatchableError as e:
    stderr.writeLine("ERROR: ", e.msg)
    return 1

  writeReports(reports, opts.outdir, opts.writeJson, opts.writeText, opts.plot)
  return 0
