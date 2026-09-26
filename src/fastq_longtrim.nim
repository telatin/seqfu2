## fastq_longtrim.nim - Long-read FASTQ quality filtering and trimming (ONT/PacBio)
## Provides `seqfu longtrim` subcommand.

import readfx
import json
import strutils
import sequtils
import algorithm
import sets
import times
import docopt
import ./seqfu_utils
import ./filter_utils
import ./filt_utils

##############################
# Types
##############################

type
  LtFilterCode = enum
    ltPass, ltFailTooShort, ltFailTooLong,
    ltFailQuality, ltFailMeanQual, ltFailHighN,
    ltFailLowGC, ltFailHighGC, ltFailComplexity

  LtRunStats = object
    before:               LrReadStats
    after:                LrReadStats
    passed:               int64
    passedBases:          int64
    failedTooShort:       int64
    failedTooLong:        int64
    failedQuality:        int64
    failedMeanQual:       int64
    failedHighN:          int64
    failedLowGC:          int64
    failedHighGC:         int64
    failedComplexity:     int64
    filtTopRemoved:       int64
    trimmedFrontReads:    int64
    trimmedTailReads:     int64
    trimmedWindowReads:   int64
    trimmedPolyXReads:    int64
    basesTrimmedFront:    int64
    basesTrimmedTail:     int64
    basesTrimmedWindow:   int64
    basesTrimmedPolyX:    int64

##############################
# Filter logic
##############################

proc filterRead(sqLen: int; metrics: ReadQualMetrics;
                noLenFilter: bool; minLength, maxLength: int;
                noQualFilter: bool; unqualLimit, minQual, maxNPct: float;
                minGC, maxGC: float;
                lowComplexity: bool; complexityThr: float): LtFilterCode =
  if not noLenFilter:
    if sqLen < minLength: return ltFailTooShort
    if maxLength > 0 and sqLen > maxLength: return ltFailTooLong
  if not noQualFilter:
    if metrics.unqualPct > unqualLimit: return ltFailQuality
    if minQual > 0.0 and metrics.meanQual < minQual: return ltFailMeanQual
    if metrics.nPct > maxNPct: return ltFailHighN
  if minGC > 0.0 and metrics.gcPct < minGC: return ltFailLowGC
  if maxGC < 100.0 and metrics.gcPct > maxGC: return ltFailHighGC
  if lowComplexity and metrics.complexity < complexityThr: return ltFailComplexity
  return ltPass

##############################
# Compute trim+postMet without writing (for two-pass pass-1)
##############################

proc computeTrimmedMetrics(record: FQRecord;
                            trimFront, trimTail: int;
                            cutFront, cutTail: bool;
                            windowSize, windowQual: int;
                            doTrimPolyX: bool; polyXMin: int;
                            qualThreshold: int): tuple[sq: string; qu: string; postMet: ReadQualMetrics] =
  var sq = record.sequence
  var qu = record.quality

  if trimFront > 0 and sq.len > 0:
    let cut = min(trimFront, sq.len)
    sq = sq[cut .. ^1]
    qu = qu[cut .. ^1]
  if trimTail > 0 and sq.len > 0:
    let cut = min(trimTail, sq.len)
    sq.setLen(sq.len - cut)
    qu.setLen(qu.len - cut)

  if cutFront and sq.len > 0:
    let newStart = slidingCutFront(qu, 0, sq.len, windowSize, windowQual, PHRED_OFFSET)
    if newStart > 0:
      sq = sq[newStart .. ^1]
      qu = qu[newStart .. ^1]

  if cutTail and sq.len > 0:
    let newEnd = slidingCutTail(qu, 0, sq.len, windowSize, windowQual, PHRED_OFFSET)
    if newEnd < sq.len:
      sq.setLen(newEnd)
      qu.setLen(newEnd)

  if doTrimPolyX and sq.len > 0:
    trimPolyX(sq, qu, polyXMin)

  result = (sq: sq, qu: qu, postMet: computeReadMetrics(sq, qu, qualThreshold))

##############################
# Core trim+filter+emit proc
##############################

proc trimAndFilter(record: FQRecord;
                   trimFront, trimTail: int;
                   cutFront, cutTail: bool;
                   windowSize, windowQual: int;
                   doTrimPolyX: bool; polyXMin: int;
                   qualThreshold: int;
                   noLenFilter: bool; minLength, maxLength: int;
                   noQualFilter: bool; unqualLimit, minQual, maxNPct: float;
                   minGC, maxGC: float;
                   lowComplexity: bool; complexityThr: float;
                   stats: var LtRunStats;
                   writer: var FastxWriter;
                   failWriter: var FastxWriter; hasFailWriter: bool): LtFilterCode =

  # 1. Pre-trim metrics
  let preMet = computeReadMetrics(record.sequence, record.quality, qualThreshold)
  addToLrReadStats(stats.before, preMet)

  # 2. Copy and mutate
  var sq = record.sequence
  var qu = record.quality
  let origLen = sq.len

  # 3. Fixed front/tail trim
  var frontTrimmed = 0
  var tailTrimmed = 0
  if trimFront > 0 and sq.len > 0:
    let cut = min(trimFront, sq.len)
    sq = sq[cut .. ^1]
    qu = qu[cut .. ^1]
    frontTrimmed = cut
  if trimTail > 0 and sq.len > 0:
    let cut = min(trimTail, sq.len)
    sq.setLen(sq.len - cut)
    qu.setLen(qu.len - cut)
    tailTrimmed = cut

  # 4. Sliding window cut-front
  let lenAfterFixed = sq.len
  if cutFront and sq.len > 0:
    let newStart = slidingCutFront(qu, 0, sq.len, windowSize, windowQual, PHRED_OFFSET)
    if newStart > 0:
      sq = sq[newStart .. ^1]
      qu = qu[newStart .. ^1]

  # 5. Sliding window cut-tail
  if cutTail and sq.len > 0:
    let newEnd = slidingCutTail(qu, 0, sq.len, windowSize, windowQual, PHRED_OFFSET)
    if newEnd < sq.len:
      sq.setLen(newEnd)
      qu.setLen(newEnd)
  let windowTrimmed = lenAfterFixed - sq.len

  # 6. Poly-X trim
  let lenBeforePolyX = sq.len
  if doTrimPolyX and sq.len > 0:
    trimPolyX(sq, qu, polyXMin)
  let polyXTrimmed = lenBeforePolyX - sq.len

  # 7. Post-trim metrics
  let postMet = computeReadMetrics(sq, qu, qualThreshold)

  # 8. Filter decision
  let code = filterRead(sq.len, postMet,
                        noLenFilter, minLength, maxLength,
                        noQualFilter, unqualLimit, minQual, maxNPct,
                        minGC, maxGC,
                        lowComplexity, complexityThr)

  # 9. Update trim stats
  if frontTrimmed > 0:
    inc stats.trimmedFrontReads
    stats.basesTrimmedFront += int64(frontTrimmed)
  if tailTrimmed > 0:
    inc stats.trimmedTailReads
    stats.basesTrimmedTail += int64(tailTrimmed)
  if windowTrimmed > 0:
    inc stats.trimmedWindowReads
    stats.basesTrimmedWindow += int64(windowTrimmed)
  if polyXTrimmed > 0:
    inc stats.trimmedPolyXReads
    stats.basesTrimmedPolyX += int64(polyXTrimmed)

  # 10. Emit or reject
  if code == ltPass:
    inc stats.passed
    stats.passedBases += int64(sq.len)
    addToLrReadStats(stats.after, postMet)
    var outRec = record
    outRec.sequence = sq
    outRec.quality = qu
    writer.writeRecord(outRec)
  else:
    case code
    of ltFailTooShort:   inc stats.failedTooShort
    of ltFailTooLong:    inc stats.failedTooLong
    of ltFailQuality:    inc stats.failedQuality
    of ltFailMeanQual:   inc stats.failedMeanQual
    of ltFailHighN:      inc stats.failedHighN
    of ltFailLowGC:      inc stats.failedLowGC
    of ltFailHighGC:     inc stats.failedHighGC
    of ltFailComplexity: inc stats.failedComplexity
    else: discard
    if hasFailWriter:
      let reason = case code
        of ltFailTooShort:   "FAIL_LENGTH"
        of ltFailTooLong:    "FAIL_TOOLONG"
        of ltFailQuality:    "FAIL_QUALITY"
        of ltFailMeanQual:   "FAIL_MEANQUAL"
        of ltFailHighN:      "FAIL_HIGH_N"
        of ltFailLowGC:      "FAIL_LOW_GC"
        of ltFailHighGC:     "FAIL_HIGH_GC"
        of ltFailComplexity: "FAIL_COMPLEXITY"
        else:                "FAIL"
      var failRec = record
      failRec.sequence = sq
      failRec.quality = qu
      failRec.name = record.name & "|" & reason
      failWriter.writeRecord(failRec)

  return code

##############################
# JSON report
##############################

proc buildJsonReport(stats: LtRunStats; inputPath: string;
                     beforeN50, afterN50: int;
                     beforeHist, afterHist: LrLenHistogram;
                     minLength, maxLength: int;
                     noLenFilter, noQualFilter: bool;
                     minQual, unqualLimit: float;
                     qualThreshold: int;
                     maxNPct: float;
                     trimFront, trimTail: int;
                     cutFront, cutTail: bool;
                     windowSize, windowQual: int;
                     doTrimPolyX: bool; polyXMin: int;
                     minGC, maxGC: float;
                     lowComplexity: bool; complexityThr: float;
                     filtTop: float): JsonNode =

  let totalReads   = stats.before.totalReads
  let passedReads  = stats.passed
  let passedRate   = if totalReads > 0: float(passedReads) / float(totalReads) else: 0.0
  let beforeMeanLen = if stats.before.totalReads > 0:
                        float(stats.before.totalBases) / float(stats.before.totalReads)
                      else: 0.0
  let afterMeanLen  = if stats.after.totalReads > 0:
                        float(stats.after.totalBases) / float(stats.after.totalReads)
                      else: 0.0
  let beforeMeanQ  = if stats.before.totalReads > 0:
                       stats.before.qualSum / float(stats.before.totalReads)
                     else: 0.0
  let afterMeanQ   = if stats.after.totalReads > 0:
                       stats.after.qualSum / float(stats.after.totalReads)
                     else: 0.0
  let beforeGCpct  = if stats.before.totalBases > 0:
                       float(stats.before.gcBases) * 100.0 / float(stats.before.totalBases)
                     else: 0.0
  let afterGCpct   = if stats.after.totalBases > 0:
                       float(stats.after.gcBases) * 100.0 / float(stats.after.totalBases)
                     else: 0.0

  proc histToJson(hist: LrLenHistogram): JsonNode =
    result = newJObject()
    result["bin_size"] = %hist.binSize
    result["counts"] = newJArray()
    for c in hist.counts:
      result["counts"].add(%c)

  proc distToJson(arr: openArray[int64]): JsonNode =
    result = newJArray()
    for v in arr: result.add(%v)

  result = %* {
    "seqfu_version": version(),
    "command": "longtrim",
    "timestamp": $now(),
    "input": inputPath,
    "parameters": {
      "min_length":       minLength,
      "max_length":       maxLength,
      "no_length_filter": noLenFilter,
      "min_qual":         minQual,
      "unqual_limit":     unqualLimit,
      "qual_threshold":   qualThreshold,
      "max_n_pct":        maxNPct,
      "no_quality_filter": noQualFilter,
      "trim_front":       trimFront,
      "trim_tail":        trimTail,
      "cut_front":        cutFront,
      "cut_tail":         cutTail,
      "window_size":      windowSize,
      "window_qual":      windowQual,
      "trim_poly_x":      doTrimPolyX,
      "poly_x_min":       polyXMin,
      "min_gc":           minGC,
      "max_gc":           maxGC,
      "low_complexity":   lowComplexity,
      "complexity_threshold": complexityThr,
      "filt_top":         filtTop
    },
    "summary": {
      "before_filtering": {
        "total_reads":    stats.before.totalReads,
        "total_bases":    stats.before.totalBases,
        "mean_length":    beforeMeanLen,
        "n50":            beforeN50,
        "min_length":     stats.before.minLen,
        "max_length":     stats.before.maxLen,
        "mean_quality":   beforeMeanQ,
        "gc_content_pct": beforeGCpct,
        "q5_bases":       stats.before.q5Bases,
        "q7_bases":       stats.before.q7Bases,
        "q10_bases":      stats.before.q10Bases,
        "q15_bases":      stats.before.q15Bases,
        "q20_bases":      stats.before.q20Bases,
        "q30_bases":      stats.before.q30Bases,
        "q20_rate": (if stats.before.totalBases > 0:
                       float(stats.before.q20Bases)/float(stats.before.totalBases)
                     else: 0.0),
        "q30_rate": (if stats.before.totalBases > 0:
                       float(stats.before.q30Bases)/float(stats.before.totalBases)
                     else: 0.0)
      },
      "after_filtering": {
        "total_reads":    stats.after.totalReads,
        "total_bases":    stats.after.totalBases,
        "mean_length":    afterMeanLen,
        "n50":            afterN50,
        "min_length":     stats.after.minLen,
        "max_length":     stats.after.maxLen,
        "mean_quality":   afterMeanQ,
        "gc_content_pct": afterGCpct,
        "q5_bases":       stats.after.q5Bases,
        "q7_bases":       stats.after.q7Bases,
        "q10_bases":      stats.after.q10Bases,
        "q15_bases":      stats.after.q15Bases,
        "q20_bases":      stats.after.q20Bases,
        "q30_bases":      stats.after.q30Bases,
        "q20_rate": (if stats.after.totalBases > 0:
                       float(stats.after.q20Bases)/float(stats.after.totalBases)
                     else: 0.0),
        "q30_rate": (if stats.after.totalBases > 0:
                       float(stats.after.q30Bases)/float(stats.after.totalBases)
                     else: 0.0)
      },
      "filtering_result": {
        "passed_reads":        stats.passed,
        "passed_bases":        stats.passedBases,
        "passed_rate":         passedRate,
        "failed_too_short":    stats.failedTooShort,
        "failed_too_long":     stats.failedTooLong,
        "failed_low_quality":  stats.failedQuality,
        "failed_low_mean_qual": stats.failedMeanQual,
        "failed_high_n":       stats.failedHighN,
        "failed_low_gc":       stats.failedLowGC,
        "failed_high_gc":      stats.failedHighGC,
        "failed_low_complexity": stats.failedComplexity,
        "filt_top_removed":    stats.filtTopRemoved
      },
      "trimming_result": {
        "reads_trimmed_front":  stats.trimmedFrontReads,
        "reads_trimmed_tail":   stats.trimmedTailReads,
        "reads_trimmed_window": stats.trimmedWindowReads,
        "reads_trimmed_poly_x": stats.trimmedPolyXReads,
        "bases_trimmed_front":  stats.basesTrimmedFront,
        "bases_trimmed_tail":   stats.basesTrimmedTail,
        "bases_trimmed_window": stats.basesTrimmedWindow,
        "bases_trimmed_poly_x": stats.basesTrimmedPolyX
      }
    },
    "histograms": {
      "read_length_before": histToJson(beforeHist),
      "read_length_after":  histToJson(afterHist),
      "mean_quality_before": {"min_val": 0, "max_val": 60, "counts": distToJson(stats.before.qualDist)},
      "mean_quality_after":  {"min_val": 0, "max_val": 60, "counts": distToJson(stats.after.qualDist)},
      "gc_content_before":   {"min_val": 0, "max_val": 100, "counts": distToJson(stats.before.gcDist)},
      "gc_content_after":    {"min_val": 0, "max_val": 100, "counts": distToJson(stats.after.gcDist)}
    }
  }

##############################
# Main entry point
##############################

proc fastq_longtrim*(args: var seq[string]): int =
  let doc = """
Usage:
  longtrim [options] [<input>]
  longtrim --help

Input/Output:
  <input>                  Input FASTQ (.gz auto-detected) [default: stdin]
  -o, --output FILE        Output FASTQ (.gz if name ends .gz)
  --failed-out FILE        Write failing reads here (failure reason in name)

Length Filtering:
  -l, --min-length INT     Minimum read length [default: 200]
  --max-length INT         Maximum read length (0 = no limit) [default: 0]
  -L, --no-length-filter   Disable length filtering

Quality Filtering:
  -q, --min-qual FLOAT     Minimum mean quality (Phred, 0 = off) [default: 0]
  -u, --unqual-limit PCT   Max % bases below --qual-threshold [default: 40]
  --qual-threshold INT     Phred threshold for unqualified base [default: 15]
  --max-n-pct PCT          Maximum N base percentage [default: 10]
  -Q, --no-quality-filter  Disable quality filtering

Trimming:
  -f, --trim-front INT     Trim N bases from 5' end [default: 0]
  -t, --trim-tail INT      Trim N bases from 3' end [default: 0]
  -5, --cut-front          Enable 5' sliding-window quality cut
  -3, --cut-tail           Enable 3' sliding-window quality cut
  -W, --window-size INT    Sliding window size [default: 4]
  -M, --window-qual INT    Sliding window quality threshold (Phred) [default: 20]
  -x, --trim-poly-x        Enable 3' poly-X trimming
  --poly-x-min INT         Minimum poly-X run length to trim [default: 10]

GC / Complexity:
  --min-gc FLOAT           Minimum GC% [default: 0]
  --max-gc FLOAT           Maximum GC% [default: 100]
  -y, --low-complexity     Enable low-complexity filter
  -Y, --complexity PCT     Minimum complexity % [default: 30]

Two-Pass:
  --filt-top FLOAT         Keep top FLOAT fraction of reads by quality (0 = off) [default: 0]

Reports:
  -j, --json FILE          JSON report path [default: seqfu-longtrim.json]
  --no-json                Skip JSON report
  -v, --verbose            Print summary to stderr

General:
  --reads INT              Stop after N reads (0 = all) [default: 0]
  -h, --help               Show this help
"""

  let parsedArgs = docopt(doc, argv=args, version="SeqFu " & version())

  # Input path
  let inputPath = if parsedArgs["<input>"]: $parsedArgs["<input>"] else: "-"
  let outputPath = if $parsedArgs["--output"] == "nil": "" else: $parsedArgs["--output"]
  let failedOutPath = if parsedArgs["--failed-out"]: $parsedArgs["--failed-out"] else: ""
  let hasFailWriter = failedOutPath.len > 0

  # Parse numeric options
  var
    minLength    = 200
    maxLength    = 0
    trimFront    = 0
    trimTail     = 0
    windowSize   = 4
    windowQual   = 20
    qualThreshold = 15
    polyXMin     = 10
    maxReads     = 0

  var
    minQual      = 0.0
    unqualLimit  = 40.0
    maxNPct      = 10.0
    minGC        = 0.0
    maxGC        = 100.0
    complexityThr = 30.0
    filtTop      = 0.0

  try:
    minLength     = parseInt($parsedArgs["--min-length"])
    maxLength     = parseInt($parsedArgs["--max-length"])
    trimFront     = parseInt($parsedArgs["--trim-front"])
    trimTail      = parseInt($parsedArgs["--trim-tail"])
    windowSize    = parseInt($parsedArgs["--window-size"])
    windowQual    = parseInt($parsedArgs["--window-qual"])
    qualThreshold = parseInt($parsedArgs["--qual-threshold"])
    polyXMin      = parseInt($parsedArgs["--poly-x-min"])
    maxReads      = parseInt($parsedArgs["--reads"])
    minQual       = parseFloat($parsedArgs["--min-qual"])
    unqualLimit   = parseFloat($parsedArgs["--unqual-limit"])
    maxNPct       = parseFloat($parsedArgs["--max-n-pct"])
    minGC         = parseFloat($parsedArgs["--min-gc"])
    maxGC         = parseFloat($parsedArgs["--max-gc"])
    complexityThr = parseFloat($parsedArgs["--complexity"])
    filtTop       = parseFloat($parsedArgs["--filt-top"])
  except ValueError as e:
    stderr.writeLine("ERROR: Invalid parameter value: ", e.msg)
    return 1

  let noLenFilter   = parsedArgs["--no-length-filter"]
  let noQualFilter  = parsedArgs["--no-quality-filter"]
  let cutFront      = parsedArgs["--cut-front"]
  let cutTail       = parsedArgs["--cut-tail"]
  let doTrimPolyX   = parsedArgs["--trim-poly-x"]
  let lowComplexity = parsedArgs["--low-complexity"]
  let verbose       = parsedArgs["--verbose"]
  let noJson        = parsedArgs["--no-json"]
  let jsonPath      = if $parsedArgs["--json"] == "nil": "seqfu-longtrim.json"
                      else: $parsedArgs["--json"]

  # Validate filtTop
  if filtTop > 0.0:
    if filtTop > 1.0:
      stderr.writeLine("ERROR: --filt-top must be in (0, 1]")
      return 1
    if inputPath == "-":
      stderr.writeLine("ERROR: --filt-top requires a file input (not stdin)")
      return 1

  # Open output writers
  var writer = openFilterWriter(outputPath, fxfFastq, 4)
  var failWriter: FastxWriter
  if hasFailWriter:
    failWriter = openFilterWriter(failedOutPath, fxfFastq, 4)

  var stats = LtRunStats()

  if filtTop > 0.0:
    # Two-pass mode
    # Pass 1: collect (meanQual, readIdx) for reads that would pass filters
    type QualIdx = tuple[meanQual: float; idx: int]
    var candidates: seq[QualIdx]
    var readIdx = 0
    for record in readFQ(inputPath):
      if maxReads > 0 and readIdx >= maxReads:
        break
      let (sq, qu, postMet) = computeTrimmedMetrics(record,
        trimFront, trimTail, cutFront, cutTail, windowSize, windowQual,
        doTrimPolyX, polyXMin, qualThreshold)
      let code = filterRead(sq.len, postMet,
                            noLenFilter, minLength, maxLength,
                            noQualFilter, unqualLimit, minQual, maxNPct,
                            minGC, maxGC, lowComplexity, complexityThr)
      if code == ltPass:
        candidates.add((postMet.meanQual, readIdx))
      inc readIdx

    # Sort descending by meanQual
    candidates.sort(proc(a, b: QualIdx): int = cmp(b.meanQual, a.meanQual))

    let keepN = max(1, int(float(candidates.len) * filtTop))
    var keepSet = initHashSet[int]()
    for i in 0 ..< min(keepN, candidates.len):
      keepSet.incl(candidates[i].idx)
    stats.filtTopRemoved = int64(candidates.len) - int64(keepSet.len)

    # Pass 2: re-read, emit only reads in keepSet
    readIdx = 0
    for record in readFQ(inputPath):
      if maxReads > 0 and readIdx >= maxReads:
        break
      if readIdx in keepSet:
        discard trimAndFilter(record,
          trimFront, trimTail, cutFront, cutTail, windowSize, windowQual,
          doTrimPolyX, polyXMin, qualThreshold,
          noLenFilter, minLength, maxLength,
          noQualFilter, unqualLimit, minQual, maxNPct,
          minGC, maxGC, lowComplexity, complexityThr,
          stats, writer, failWriter, hasFailWriter)
      inc readIdx

  else:
    # Single-pass mode
    var readIdx = 0
    for record in readFQ(inputPath):
      if maxReads > 0 and readIdx >= maxReads:
        break
      discard trimAndFilter(record,
        trimFront, trimTail, cutFront, cutTail, windowSize, windowQual,
        doTrimPolyX, polyXMin, qualThreshold,
        noLenFilter, minLength, maxLength,
        noQualFilter, unqualLimit, minQual, maxNPct,
        minGC, maxGC, lowComplexity, complexityThr,
        stats, writer, failWriter, hasFailWriter)
      inc readIdx

  # Compute N50 and histograms
  let beforeN50 = if stats.before.lengths.len > 0: calcN50(stats.before.lengths) else: 0
  let afterN50  = if stats.after.lengths.len > 0:  calcN50(stats.after.lengths)  else: 0

  let beforeMaxLen = if stats.before.maxLen > 0: stats.before.maxLen else: 1
  let afterMaxLen  = if stats.after.maxLen  > 0: stats.after.maxLen  else: 1
  let beforeHist = buildLenHistogram(stats.before.lengths, beforeMaxLen)
  let afterHist  = buildLenHistogram(stats.after.lengths,  afterMaxLen)

  # Write JSON
  if not noJson:
    let report = buildJsonReport(stats, inputPath,
      beforeN50, afterN50, beforeHist, afterHist,
      minLength, maxLength, noLenFilter, noQualFilter,
      minQual, unqualLimit, qualThreshold, maxNPct,
      trimFront, trimTail, cutFront, cutTail, windowSize, windowQual,
      doTrimPolyX, polyXMin, minGC, maxGC, lowComplexity, complexityThr, filtTop)
    try:
      writeFile(jsonPath, report.pretty)
    except CatchableError as e:
      stderr.writeLine("WARNING: Could not write JSON report: ", e.msg)

  # Stderr summary
  let totalReads = stats.before.totalReads
  let passedReads = stats.passed
  let passedPct = if totalReads > 0:
                    formatFloat(float(passedReads) * 100.0 / float(totalReads), ffDecimal, 1)
                  else: "0.0"

  if verbose:
    stderr.writeLine("SeqFu longtrim v", version())
    stderr.writeLine("Input:         ", inputPath)
    stderr.writeLine("Reads input:   ", totalReads)
    stderr.writeLine("Reads passed:  ", passedReads, " (", passedPct, "%)")
    if stats.failedTooShort > 0:
      stderr.writeLine("  Too short:   ", stats.failedTooShort)
    if stats.failedTooLong > 0:
      stderr.writeLine("  Too long:    ", stats.failedTooLong)
    if stats.failedQuality > 0:
      stderr.writeLine("  Low quality: ", stats.failedQuality)
    if stats.failedMeanQual > 0:
      stderr.writeLine("  Low mean Q:  ", stats.failedMeanQual)
    if stats.failedHighN > 0:
      stderr.writeLine("  High N:      ", stats.failedHighN)
    if stats.failedLowGC > 0:
      stderr.writeLine("  Low GC:      ", stats.failedLowGC)
    if stats.failedHighGC > 0:
      stderr.writeLine("  High GC:     ", stats.failedHighGC)
    if stats.failedComplexity > 0:
      stderr.writeLine("  Low complexity: ", stats.failedComplexity)
    if stats.filtTopRemoved > 0:
      stderr.writeLine("  Filt-top removed: ", stats.filtTopRemoved)
    stderr.writeLine("N50: ", beforeN50, " bp -> ", afterN50, " bp")

  # Flush and close writers explicitly (defer won't run when main_helper calls quit())
  writer.close()
  if hasFailWriter:
    failWriter.close()

  return 0
