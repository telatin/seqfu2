## SeqFu Trim - fastp-like quality trimming and filtering tool
## High-performance quality trimming with paired-end support and multithreading

import docopt
import strutils
import sequtils
import klib
import readfq
import json
import os
import tables
import malebolgia
import "./seqfu_utils"

###################
# Type Definitions
###################

type
  TrimOptions = object
    ## Fixed position trimming
    trimFrontBases: int      # --trim-front N
    trimTailBases: int       # --trim-tail N

    ## Sliding window trimming
    cutFront: bool
    cutFrontWindow: int
    cutFrontQual: int

    cutTail: bool
    cutTailWindow: int
    cutTailQual: int

    cutRight: bool           # Has precedence over cutTail
    cutRightWindow: int
    cutRightQual: int

    qualOffset: int          # Quality offset (default 33)

  FilterOptions = object
    ## Quality filtering (enabled by default)
    qualityFilter: bool
    unqualifiedPercent: float    # Max % of low-quality bases
    qualifiedQual: int           # Threshold for "qualified" base

    ## Average quality
    avgQualFilter: bool
    avgQualThreshold: int

    ## N base filter
    nBaseLimit: int

    ## Length filter
    lengthFilter: bool
    minLength: int
    maxLength: int

    ## Low complexity
    complexityFilter: bool
    complexityThreshold: float

  FilterResult = enum
    frPass, frFailQuality, frFailAvgQual, frFailNBase,
    frFailLength, frFailTooLong, frFailComplexity

  ProcessingStats = object
    totalReads: int
    totalPairs: int
    passedReads: int
    passedPairs: int
    failedQuality: int
    failedAvgQual: int
    failedNBase: int
    failedLength: int
    failedTooLong: int
    failedComplexity: int
    totalBasesTrimmed: int
    readsTrimmed: int

#########################
# Core Trimming Functions
#########################

proc calculateCutFront(quality: string, startPos, endPos: int,
                       windowSize, qualThreshold, offset: int): int =
  ## Find first position from 5' where window has avg quality >= threshold
  ## Returns new start position
  ## Uses efficient O(1) rolling window update

  let targetQualSum = windowSize * (qualThreshold + offset)

  if (endPos - startPos) < windowSize:
    return endPos  # Trim entire read

  # Initialize first window sum (ASCII values)
  var qualSum = 0
  for i in startPos ..< (startPos + windowSize):
    qualSum += quality[i].ord

  # Check first window
  if qualSum >= targetQualSum:
    return startPos

  # Roll window with O(1) update
  for pos in (startPos + 1) .. (endPos - windowSize):
    qualSum += quality[pos + windowSize - 1].ord  # Add new base
    qualSum -= quality[pos - 1].ord                # Remove old base

    if qualSum >= targetQualSum:
      return pos  # Found good window

  return endPos  # No good window found


proc calculateCutTail(quality: string, startPos, endPos: int,
                      windowSize, qualThreshold, offset: int): int =
  ## Mirror of cutFront, operates right to left
  ## Returns new end position
  ## Uses efficient O(1) rolling window update

  let targetQualSum = windowSize * (qualThreshold + offset)

  if (endPos - startPos) < windowSize:
    return startPos

  # Initialize last window
  var qualSum = 0
  for i in (endPos - windowSize) ..< endPos:
    qualSum += quality[i].ord

  if qualSum >= targetQualSum:
    return endPos

  # Roll window from right to left
  for pos in countdown(endPos - windowSize - 1, startPos):
    qualSum += quality[pos].ord
    qualSum -= quality[pos + windowSize].ord

    if qualSum >= targetQualSum:
      return pos + 1

  return startPos


proc calculateCutRight(sequence, quality: string, startPos, endPos: int,
                       windowSize, qualThreshold, offset: int): int =
  ## Find first bad window from 5' and truncate there
  ## Returns new end position
  ## Uses efficient O(1) rolling window update

  let targetQualSum = windowSize * (qualThreshold + offset)

  if (endPos - startPos) < windowSize:
    return startPos

  var qualSum = 0
  for i in startPos ..< (startPos + windowSize):
    qualSum += quality[i].ord

  for pos in startPos .. (endPos - windowSize):
    if pos > startPos:
      qualSum += quality[pos + windowSize - 1].ord
      qualSum -= quality[pos - 1].ord

    if qualSum < targetQualSum:
      # Found bad window, find first truly bad base
      for cutPos in pos ..< (pos + windowSize):
        if (quality[cutPos].ord - offset) < qualThreshold:
          return cutPos
      return pos

  return endPos


proc trimAndCut(record: FQRecord, opts: TrimOptions): tuple[record: FQRecord, trimmed: bool] =
  ## Single-pass trimming applying all operations in fastp order
  ## Returns modified record and whether any trimming occurred

  let readLen = record.sequence.len
  var startPos = opts.trimFrontBases        # 1. Global front trim
  var endPos = readLen - opts.trimTailBases # 2. Global tail trim

  if endPos <= startPos:
    # Trimmed to nothing
    result.record = record
    result.record.sequence = ""
    result.record.quality = ""
    result.trimmed = true
    return

  # 3. Cut front (5' sliding window)
  if opts.cutFront:
    startPos = calculateCutFront(record.quality, startPos, endPos,
                                 opts.cutFrontWindow, opts.cutFrontQual, opts.qualOffset)

  # 4. Cut right OR cut tail (mutually exclusive, right has precedence)
  if opts.cutRight:
    endPos = calculateCutRight(record.sequence, record.quality, startPos, endPos,
                               opts.cutRightWindow, opts.cutRightQual, opts.qualOffset)
  elif opts.cutTail:
    endPos = calculateCutTail(record.quality, startPos, endPos,
                              opts.cutTailWindow, opts.cutTailQual, opts.qualOffset)

  # 5. Single modification
  let newLen = endPos - startPos
  if newLen <= 0:
    result.record = record
    result.record.sequence = ""
    result.record.quality = ""
    result.trimmed = true
    return

  result.record.name = record.name
  result.record.comment = record.comment
  result.record.sequence = record.sequence[startPos ..< endPos]
  result.record.quality = record.quality[startPos ..< endPos]
  result.trimmed = (startPos > 0 or endPos < readLen)


###########################
# Filtering Functions
###########################

proc passFilter(record: FQRecord, opts: FilterOptions): FilterResult =
  ## Single-pass filtering with short-circuit evaluation
  ## Returns filter result indicating pass or specific failure reason

  let rlen = record.sequence.len
  if rlen == 0:
    return frFailLength

  # Single pass data collection
  var lowQualBases = 0
  var nBases = 0
  var totalQual = 0

  for i in 0 ..< rlen:
    let base = record.sequence[i]
    let qual = record.quality[i].ord - 33

    if qual < opts.qualifiedQual:
      lowQualBases += 1

    if base == 'N':
      nBases += 1

    totalQual += qual

  # Sequential checks with short-circuit

  # Check 1: Unqualified base percentage
  if opts.qualityFilter:
    if (lowQualBases.float * 100.0 / float(rlen)) > opts.unqualifiedPercent:
      return frFailQuality

  # Check 2: Average quality
  if opts.avgQualFilter:
    let avgQual = float(totalQual) / float(rlen)
    if avgQual < float(opts.avgQualThreshold):
      return frFailAvgQual

  # Check 3: N base limit
  if nBases > opts.nBaseLimit:
    return frFailNBase

  # Check 4: Length filter
  if opts.lengthFilter:
    if rlen < opts.minLength:
      return frFailLength
    if opts.maxLength > 0 and rlen > opts.maxLength:
      return frFailTooLong

  # Check 5: Low complexity
  if opts.complexityFilter:
    var diff = 0
    for i in 0 ..< (rlen - 1):
      if record.sequence[i] != record.sequence[i + 1]:
        diff += 1
    let complexity = float(diff) / float(rlen - 1)
    if complexity < opts.complexityThreshold:
      return frFailComplexity

  return frPass


###########################
# Processing Functions
###########################

proc processSingleRead(read: FQRecord, trimOpts: TrimOptions,
                       filterOpts: FilterOptions): tuple[record: FQRecord,
                                                          passed: bool,
                                                          result: FilterResult,
                                                          trimmed: bool] =
  ## Process a single read through trimming and filtering
  let (trimmedRead, wasTrimmed) = trimAndCut(read, trimOpts)
  let filterResult = passFilter(trimmedRead, filterOpts)

  return (record: trimmedRead,
          passed: filterResult == frPass,
          result: filterResult,
          trimmed: wasTrimmed)


proc processPairedReads(r1, r2: FQRecord, trimOpts: TrimOptions,
                        filterOpts: FilterOptions): tuple[r1, r2: FQRecord,
                                                           passed: bool,
                                                           result1, result2: FilterResult,
                                                           trimmed1, trimmed2: bool] =
  ## Process paired reads - both must pass all filters
  let result1 = processSingleRead(r1, trimOpts, filterOpts)
  let result2 = processSingleRead(r2, trimOpts, filterOpts)

  # Both must pass
  let bothPass = result1.passed and result2.passed

  return (r1: result1.record,
          r2: result2.record,
          passed: bothPass,
          result1: result1.result,
          result2: result2.result,
          trimmed1: result1.trimmed,
          trimmed2: result2.trimmed)


###########################
# Statistics Functions
###########################

proc updateStats(stats: var ProcessingStats, filterRes: FilterResult, trimmed: bool) =
  ## Update statistics based on filter result
  case filterRes:
    of frPass: discard
    of frFailQuality: stats.failedQuality += 1
    of frFailAvgQual: stats.failedAvgQual += 1
    of frFailNBase: stats.failedNBase += 1
    of frFailLength: stats.failedLength += 1
    of frFailTooLong: stats.failedTooLong += 1
    of frFailComplexity: stats.failedComplexity += 1


proc printStats(stats: ProcessingStats, isPaired: bool, verbose: bool) =
  ## Print statistics to stderr
  if not verbose:
    return

  stderr.writeLine("\nResults:")
  if isPaired:
    stderr.writeLine("  Total pairs:             ", $stats.totalPairs)
    stderr.writeLine("  Passed pairs:            ", $stats.passedPairs,
                    " (", formatFloat(stats.passedPairs.float * 100.0 / stats.totalPairs.float, ffDecimal, 1), "%)")
    let failedPairs = stats.totalPairs - stats.passedPairs
    stderr.writeLine("  Failed pairs:            ", $failedPairs,
                    " (", formatFloat(failedPairs.float * 100.0 / stats.totalPairs.float, ffDecimal, 1), "%)")
  else:
    stderr.writeLine("  Total reads:             ", $stats.totalReads)
    stderr.writeLine("  Passed reads:            ", $stats.passedReads,
                    " (", formatFloat(stats.passedReads.float * 100.0 / stats.totalReads.float, ffDecimal, 1), "%)")
    let failedReads = stats.totalReads - stats.passedReads
    stderr.writeLine("  Failed reads:            ", $failedReads,
                    " (", formatFloat(failedReads.float * 100.0 / stats.totalReads.float, ffDecimal, 1), "%)")

  # Failure breakdown
  if stats.failedQuality > 0:
    stderr.writeLine("    Quality:               ", $stats.failedQuality)
  if stats.failedAvgQual > 0:
    stderr.writeLine("    Average quality:       ", $stats.failedAvgQual)
  if stats.failedNBase > 0:
    stderr.writeLine("    N bases:               ", $stats.failedNBase)
  if stats.failedLength > 0:
    stderr.writeLine("    Length:                ", $stats.failedLength)
  if stats.failedTooLong > 0:
    stderr.writeLine("    Too long:              ", $stats.failedTooLong)
  if stats.failedComplexity > 0:
    stderr.writeLine("    Complexity:            ", $stats.failedComplexity)

  if stats.readsTrimmed > 0:
    let pctTrimmed = if isPaired: stats.readsTrimmed.float * 100.0 / (stats.passedPairs.float * 2.0)
                     else: stats.readsTrimmed.float * 100.0 / stats.passedReads.float
    stderr.writeLine("\n  Reads trimmed:           ", $stats.readsTrimmed,
                    " (", formatFloat(pctTrimmed, ffDecimal, 1), "% of passed)")
    stderr.writeLine("  Total bases trimmed:     ", $stats.totalBasesTrimmed)


proc exportStatsJson(stats: ProcessingStats, isPaired: bool, filename: string,
                     inputR1: string, inputR2: string, outputR1: string, outputR2: string) =
  ## Export statistics to JSON file
  var j = %* {
    "version": version(),
    "mode": if isPaired: "paired-end" else: "single-end",
    "input": {
      "r1": inputR1
    },
    "output": {
      "r1": outputR1
    },
    "results": {
      "total_reads": stats.totalReads,
      "total_pairs": stats.totalPairs,
      "passed_reads": stats.passedReads,
      "passed_pairs": stats.passedPairs,
      "failed_reads": stats.totalReads - stats.passedReads,
      "failed_pairs": stats.totalPairs - stats.passedPairs,
      "failure_breakdown": {
        "quality": stats.failedQuality,
        "avg_quality": stats.failedAvgQual,
        "n_bases": stats.failedNBase,
        "length": stats.failedLength,
        "too_long": stats.failedTooLong,
        "complexity": stats.failedComplexity
      },
      "reads_trimmed": stats.readsTrimmed,
      "bases_trimmed": stats.totalBasesTrimmed
    }
  }

  if isPaired:
    j["input"]["r2"] = %inputR2
    j["output"]["r2"] = %outputR2

  try:
    writeFile(filename, j.pretty)
  except:
    stderr.writeLine("Warning: Could not write stats JSON to ", filename)


###########################
# Batch Processing for Threading
###########################

type
  WorkerBatch = object
    reads1: seq[FQRecord]
    reads2: seq[FQRecord]  # Empty for single-end
    results1: seq[FQRecord]
    results2: seq[FQRecord]
    stats: ProcessingStats
    isPaired: bool

proc processBatch(batch: ptr WorkerBatch, trimOpts: TrimOptions, filterOpts: FilterOptions) =
  ## Process a batch of reads - worker function for threading
  batch.results1 = newSeq[FQRecord]()
  if batch.isPaired:
    batch.results2 = newSeq[FQRecord]()

  if batch.isPaired:
    # Paired-end batch processing
    for i in 0 ..< batch.reads1.len:
      batch.stats.totalPairs += 1

      let (pr1, pr2, passed, res1, res2, trim1, trim2) =
        processPairedReads(batch.reads1[i], batch.reads2[i], trimOpts, filterOpts)

      if passed:
        batch.results1.add(pr1)
        batch.results2.add(pr2)
        batch.stats.passedPairs += 1

        if trim1:
          batch.stats.readsTrimmed += 1
          batch.stats.totalBasesTrimmed += batch.reads1[i].sequence.len - pr1.sequence.len
        if trim2:
          batch.stats.readsTrimmed += 1
          batch.stats.totalBasesTrimmed += batch.reads2[i].sequence.len - pr2.sequence.len
      else:
        # Update failure stats
        updateStats(batch.stats, res1, trim1)
        if res2 != frPass:
          updateStats(batch.stats, res2, trim2)
  else:
    # Single-end batch processing
    for read in batch.reads1:
      batch.stats.totalReads += 1

      let (trimmedRead, passed, filterRes, wasTrimmed) =
        processSingleRead(read, trimOpts, filterOpts)

      if passed:
        batch.results1.add(trimmedRead)
        batch.stats.passedReads += 1

        if wasTrimmed:
          batch.stats.readsTrimmed += 1
          batch.stats.totalBasesTrimmed += read.sequence.len - trimmedRead.sequence.len
      else:
        updateStats(batch.stats, filterRes, wasTrimmed)


proc processWithThreads(inputR1: string, inputR2: string, outputR1: File, outputR2: File,
                        trimOpts: TrimOptions, filterOpts: FilterOptions,
                        threads: int, batchSize: int, isPaired: bool, verbose: bool): ProcessingStats =
  ## Main processing function using Malebolgia for multithreading
  var batches: seq[WorkerBatch]
  var currentBatch = WorkerBatch(isPaired: isPaired)

  # Read and batch the input files
  if isPaired:
    # Read both files synchronously into batches
    var reads1 = newSeq[FQRecord]()
    var reads2 = newSeq[FQRecord]()

    for read in readfq(inputR1):
      reads1.add(read)
    for read in readfq(inputR2):
      reads2.add(read)

    # Check equal length
    if reads1.len != reads2.len:
      stderr.writeLine("ERROR: R1 and R2 have different numbers of reads")
      stderr.writeLine("  R1: ", reads1.len, " reads")
      stderr.writeLine("  R2: ", reads2.len, " reads")
      quit(1)

    # Create batches
    for i in 0 ..< reads1.len:
      currentBatch.reads1.add(reads1[i])
      currentBatch.reads2.add(reads2[i])

      if currentBatch.reads1.len >= batchSize:
        batches.add(currentBatch)
        currentBatch = WorkerBatch(isPaired: isPaired)

    if currentBatch.reads1.len > 0:
      batches.add(currentBatch)
  else:
    # Single-end batching
    for read in readfq(inputR1):
      currentBatch.reads1.add(read)

      if currentBatch.reads1.len >= batchSize:
        batches.add(currentBatch)
        currentBatch = WorkerBatch(isPaired: isPaired)

    if currentBatch.reads1.len > 0:
      batches.add(currentBatch)

  # Process batches in parallel with Malebolgia
  if threads > 1 and batches.len > 1:
    var m = createMaster()
    m.awaitAll:
      for i in 0 ..< batches.len:
        m.spawn processBatch(addr batches[i], trimOpts, filterOpts)
  else:
    # Single-threaded fallback
    for i in 0 ..< batches.len:
      processBatch(addr batches[i], trimOpts, filterOpts)

  # Write results in order and aggregate stats
  var totalStats = ProcessingStats()
  for batch in batches:
    for read in batch.results1:
      print_seq(read, outputR1)

    if isPaired:
      for read in batch.results2:
        print_seq(read, outputR2)

    # Aggregate stats
    totalStats.totalReads += batch.stats.totalReads
    totalStats.totalPairs += batch.stats.totalPairs
    totalStats.passedReads += batch.stats.passedReads
    totalStats.passedPairs += batch.stats.passedPairs
    totalStats.failedQuality += batch.stats.failedQuality
    totalStats.failedAvgQual += batch.stats.failedAvgQual
    totalStats.failedNBase += batch.stats.failedNBase
    totalStats.failedLength += batch.stats.failedLength
    totalStats.failedTooLong += batch.stats.failedTooLong
    totalStats.failedComplexity += batch.stats.failedComplexity
    totalStats.totalBasesTrimmed += batch.stats.totalBasesTrimmed
    totalStats.readsTrimmed += batch.stats.readsTrimmed

  return totalStats


###########################
# Main Processing
###########################

proc processFiles(inputR1: string, inputR2: string, outputR1: File, outputR2: File,
                  trimOpts: TrimOptions, filterOpts: FilterOptions,
                  isPaired: bool, verbose: bool): ProcessingStats =
  ## Main processing function for single-threaded execution
  var stats = ProcessingStats()

  if isPaired:
    # Paired-end processing - need to read both files synchronously
    # We'll collect reads into sequences for synchronized iteration
    var reads1 = newSeq[FQRecord]()
    var reads2 = newSeq[FQRecord]()

    # Read all R1 reads
    for read in readfq(inputR1):
      reads1.add(read)

    # Read all R2 reads
    for read in readfq(inputR2):
      reads2.add(read)

    # Check equal length
    if reads1.len != reads2.len:
      stderr.writeLine("ERROR: R1 and R2 have different numbers of reads")
      stderr.writeLine("  R1: ", reads1.len, " reads")
      stderr.writeLine("  R2: ", reads2.len, " reads")
      quit(1)

    # Process paired reads
    for i in 0 ..< reads1.len:
      stats.totalPairs += 1

      let (pr1, pr2, passed, res1, res2, trim1, trim2) = processPairedReads(reads1[i], reads2[i], trimOpts, filterOpts)

      if passed:
        print_seq(pr1, outputR1)
        print_seq(pr2, outputR2)
        stats.passedPairs += 1

        if trim1:
          stats.readsTrimmed += 1
          stats.totalBasesTrimmed += reads1[i].sequence.len - pr1.sequence.len
        if trim2:
          stats.readsTrimmed += 1
          stats.totalBasesTrimmed += reads2[i].sequence.len - pr2.sequence.len
      else:
        # Update failure stats (use worse of the two)
        updateStats(stats, res1, trim1)
        if res2 != frPass:
          updateStats(stats, res2, trim2)

  else:
    # Single-end processing
    for read in readfq(inputR1):
      stats.totalReads += 1

      let (trimmedRead, passed, filterRes, wasTrimmed) = processSingleRead(read, trimOpts, filterOpts)

      if passed:
        print_seq(trimmedRead, outputR1)
        stats.passedReads += 1

        if wasTrimmed:
          stats.readsTrimmed += 1
          stats.totalBasesTrimmed += read.sequence.len - trimmedRead.sequence.len
      else:
        updateStats(stats, filterRes, wasTrimmed)

  return stats


###########################
# Helper Functions
###########################

proc getInt(val: string, default: int): int =
  ## Parse integer from docopt value, return default if nil
  if val == "nil":
    return default
  try:
    return parseInt(val)
  except:
    return default

proc getFloat(val: string, default: float): float =
  ## Parse float from docopt value, return default if nil
  if val == "nil":
    return default
  try:
    return parseFloat(val)
  except:
    return default

###########################
# Main Entry Point
###########################

proc fastx_trim*(args: var seq[string]): int =
  let doc = """
Usage: trim [options] [<input>] [-1 <R1> [-2 <R2>]]

Input Options:
  <input>                  Single-end FASTQ (or stdin with -)
  -1 --r1 FILE             R1 file for paired-end
  -2 --r2 FILE             R2 file for paired-end (auto-detect if not specified)
  --for-tag TAG            Pattern for R1 files [default: auto]
  --rev-tag TAG            Pattern for R2 files [default: auto]

Output Options:
  -o --output FILE/BASE    Output file (SE) or basename (PE) [required for PE]
  --r1-suffix SUFFIX       R1 output suffix [default: _R1.fastq]
  --r2-suffix SUFFIX       R2 output suffix [default: _R2.fastq]
  -z --compress            Compress output with gzip

Fixed Position Trimming:
  --trim-front N           Trim N bases from 5' end [default: 0]
  --trim-tail N            Trim N bases from 3' end [default: 0]

Sliding Window Trimming:
  -5 --cut-front           Enable 5' sliding window trimming
  --cut-front-window N     Window size for cut-front [default: 4]
  --cut-front-qual N       Quality threshold for cut-front [default: 20]

  -3 --cut-tail            Enable 3' sliding window trimming [default: enabled]
  --cut-tail-window N      Window size for cut-tail [default: 4]
  --cut-tail-qual N        Quality threshold for cut-tail [default: 20]

  -r --cut-right           Enable right-side sliding window (precedence over cut-tail)
  --cut-right-window N     Window size for cut-right [default: 4]
  --cut-right-qual N       Quality threshold for cut-right [default: 20]

Quality Filtering (enabled by default):
  -Q --disable-quality     Disable quality filtering
  --qualified-qual N       Base is qualified if quality >= N [default: 15]
  --unqualified-percent N  Max % of unqualified bases [default: 40.0]
  --avg-qual N             Minimum average quality (0=disabled) [default: 0]

Other Filtering:
  -n --n-base-limit N      Max number of N bases [default: 5]
  -l --min-length N        Minimum read length [default: 15]
  --max-length N           Maximum read length (0=unlimited) [default: 0]
  --complexity             Enable low complexity filter
  --complexity-threshold F Min complexity ratio [default: 0.3]

Performance:
  -t --threads N           Number of threads [default: 1]
  --batch-size N           Reads per batch for threading [default: 10000]

Other:
  --offset N               Quality offset [default: 33]
  --preset PRESET          Apply preset configuration (strict|lenient)
  -v --verbose             Verbose statistics to stderr
  --stats-json FILE        Write detailed stats to JSON file
  -h --help                Show this help

Presets:
  strict                   Aggressive filtering (--cut-right -l 50 --avg-qual 25)
  lenient                  Light filtering (--cut-tail -l 30 -Q)

Description:
  Quality trimming and filtering for FASTQ files with fastp-like efficiency.
  Supports both single-end and paired-end reads.

  By default, enables 3' tail trimming and quality filtering.
  For paired-end mode, both reads must pass all filters to be retained.

Examples:
  # Single-end basic trimming (defaults)
  seqfu trim input.fq -o output.fq

  # Paired-end with auto-detection
  seqfu trim -1 sample_R1.fq -o trimmed

  # Aggressive filtering with custom params
  seqfu trim -1 R1.fq -2 R2.fq -o out --cut-right --avg-qual 25 -l 50

  # Minimal processing (disable defaults)
  seqfu trim input.fq -o output.fq -Q --trim-front 5 --trim-tail 5
"""

  let parsedArgs = docopt(doc, argv=args, version="SeqFu " & version())

  # Determine mode and input files
  var inputR1, inputR2: string
  var isPaired = false

  if parsedArgs["--r1"]:
    # Paired-end mode
    isPaired = true
    inputR1 = $parsedArgs["--r1"]

    if parsedArgs["--r2"]:
      inputR2 = $parsedArgs["--r2"]
    else:
      # Auto-detect R2
      let forTag = $parsedArgs["--for-tag"]
      let revTag = $parsedArgs["--rev-tag"]
      inputR2 = guessR2(inputR1, forTag, revTag, false)
      if inputR2 == "":
        stderr.writeLine("ERROR: Could not auto-detect R2 file for: ", inputR1)
        stderr.writeLine("Please specify -2 explicitly")
        return 1
  elif parsedArgs["<input>"]:
    # Single-end mode
    inputR1 = $parsedArgs["<input>"]
  else:
    # Read from stdin
    inputR1 = "-"

  # Output files
  var outputR1, outputR2: File
  let outputBase = $parsedArgs["--output"]
  let r1Suffix = $parsedArgs["--r1-suffix"]
  let r2Suffix = $parsedArgs["--r2-suffix"]
  let compress = parsedArgs["--compress"]

  if isPaired:
    if outputBase == "nil" or outputBase == "-":
      stderr.writeLine("ERROR: Output basename required for paired-end mode (-o)")
      return 1

    let out1Name = outputBase & r1Suffix
    let out2Name = outputBase & r2Suffix

    try:
      outputR1 = open(out1Name, fmWrite)
      outputR2 = open(out2Name, fmWrite)
    except:
      stderr.writeLine("ERROR: Cannot open output files")
      return 1
  else:
    if outputBase == "nil" or outputBase == "-":
      outputR1 = stdout
    else:
      try:
        outputR1 = open(outputBase, fmWrite)
      except:
        stderr.writeLine("ERROR: Cannot open output file: ", outputBase)
        return 1

  # Parse trimming options
  var trimOpts = TrimOptions()
  trimOpts.trimFrontBases = getInt($parsedArgs["--trim-front"], 0)
  trimOpts.trimTailBases = getInt($parsedArgs["--trim-tail"], 0)
  trimOpts.qualOffset = getInt($parsedArgs["--offset"], 33)

  # Sliding window options
  trimOpts.cutFront = parsedArgs["--cut-front"]
  trimOpts.cutFrontWindow = getInt($parsedArgs["--cut-front-window"], 4)
  trimOpts.cutFrontQual = getInt($parsedArgs["--cut-front-qual"], 20)

  trimOpts.cutRight = parsedArgs["--cut-right"]
  trimOpts.cutRightWindow = getInt($parsedArgs["--cut-right-window"], 4)
  trimOpts.cutRightQual = getInt($parsedArgs["--cut-right-qual"], 20)

  # Default: cut-tail enabled
  trimOpts.cutTail = parsedArgs["--cut-tail"] or (not parsedArgs["--cut-right"] and not parsedArgs["--cut-front"])
  trimOpts.cutTailWindow = getInt($parsedArgs["--cut-tail-window"], 4)
  trimOpts.cutTailQual = getInt($parsedArgs["--cut-tail-qual"], 20)

  # Parse filter options
  var filterOpts = FilterOptions()
  filterOpts.qualityFilter = not parsedArgs["--disable-quality"]
  filterOpts.qualifiedQual = getInt($parsedArgs["--qualified-qual"], 15)
  filterOpts.unqualifiedPercent = getFloat($parsedArgs["--unqualified-percent"], 40.0)

  let avgQual = getInt($parsedArgs["--avg-qual"], 0)
  filterOpts.avgQualFilter = avgQual > 0
  filterOpts.avgQualThreshold = avgQual

  filterOpts.nBaseLimit = getInt($parsedArgs["--n-base-limit"], 5)

  filterOpts.lengthFilter = true
  filterOpts.minLength = getInt($parsedArgs["--min-length"], 15)
  filterOpts.maxLength = getInt($parsedArgs["--max-length"], 0)

  filterOpts.complexityFilter = parsedArgs["--complexity"]
  filterOpts.complexityThreshold = getFloat($parsedArgs["--complexity-threshold"], 0.3)

  # Apply presets
  if parsedArgs["--preset"]:
    let preset = $parsedArgs["--preset"]
    case preset:
      of "strict":
        trimOpts.cutRight = true
        trimOpts.cutTail = false
        filterOpts.minLength = 50
        filterOpts.avgQualFilter = true
        filterOpts.avgQualThreshold = 25
      of "lenient":
        trimOpts.cutTail = true
        trimOpts.cutRight = false
        filterOpts.minLength = 30
        filterOpts.qualityFilter = false
      else:
        stderr.writeLine("ERROR: Unknown preset: ", preset)
        return 1

  let verbose = parsedArgs["--verbose"]
  let threads = getInt($parsedArgs["--threads"], 1)
  let batchSize = getInt($parsedArgs["--batch-size"], 10000)

  # Print header if verbose
  if verbose:
    stderr.writeLine("SeqFu trim v", version())
    stderr.writeLine("\nMode: ", if isPaired: "Paired-end" else: "Single-end")
    stderr.writeLine("Input:")
    stderr.writeLine("  R1: ", inputR1)
    if isPaired:
      stderr.writeLine("  R2: ", inputR2, if parsedArgs["--r2"]: "" else: " (auto-detected)")
    if threads > 1:
      stderr.writeLine("\nThreads: ", threads, " (batch size: ", batchSize, ")")
    stderr.writeLine("\nProcessing...")

  # Process files (with or without threading)
  let stats = if threads > 1:
                processWithThreads(inputR1, inputR2, outputR1, outputR2,
                                   trimOpts, filterOpts, threads, batchSize, isPaired, verbose)
              else:
                processFiles(inputR1, inputR2, outputR1, outputR2,
                             trimOpts, filterOpts, isPaired, verbose)

  # Close output files
  if outputBase != "nil" and outputBase != "-":
    outputR1.close()
    if isPaired:
      outputR2.close()

  # Print statistics
  printStats(stats, isPaired, verbose)

  # Export JSON if requested
  if parsedArgs["--stats-json"]:
    let jsonFile = $parsedArgs["--stats-json"]
    let out1Name = if isPaired: outputBase & r1Suffix else: outputBase
    let out2Name = if isPaired: outputBase & r2Suffix else: ""
    exportStatsJson(stats, isPaired, jsonFile, inputR1, inputR2, out1Name, out2Name)

  return 0
