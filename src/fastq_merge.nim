import math
import os
import strutils

import malebolgia

import ./seqfu_legacy_fastx
import ./seqfu_utils

type
  QualityStrategy = enum
    qsFirst,      # Use quality from R1 in the overlap
    qsLowest,     # Use lowest quality score in the overlap
    qsRecalculate # Recalculate posterior Phred score in the overlap

  SearchMode = enum
    smSeeded,
    smExhaustive

  MergeOptions = object
    minOverlap: int
    minIdentity: float
    minIdentityScaled: int
    acceptedIdentity: float
    acceptedIdentityScaled: int
    qualityMethod: QualityStrategy
    searchMode: SearchMode
    keepUnmerged: bool
    minResultLength: int
    maxResultLength: int

  OverlapScore = object
    valid: bool
    effectiveLen: int
    mismatches: int
    identityScaled: int
    identity: float

  OverlapCandidate = object
    pos: int
    overlapLen: int
    effectiveLen: int
    mismatches: int
    identityScaled: int
    identity: float

  MergeResult = object
    success: bool
    lengthDiscarded: bool
    record: FastxRecord
    overlapLength: int
    effectiveOverlap: int
    identity: float
    message: string

  PairInput = object
    pairNum: int
    r1, r2: FastxRecord

  MergeJob = object
    pairs: seq[PairInput]
    output: string
    warnings: string
    processedCount: int
    mergedCount: int
    failedCount: int
    lengthDiscardedCount: int

const
  MaxFastqQual = 93
  MinErrorProbability = 1.0e-12
  IdentityScale = 1_000_000
  DefaultSeedLength = 12

type
  QualityCharLookup = array[0 .. 255, array[0 .. 255, char]]

proc parsePositiveInt(value, optName: string): int =
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(ValueError, optName & " must be an integer >= 1.")
  if result < 1:
    raise newException(ValueError, optName & " must be >= 1.")

proc parseNonNegativeInt(value, optName: string): int =
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(ValueError, optName & " must be an integer >= 0.")
  if result < 0:
    raise newException(ValueError, optName & " must be >= 0.")

proc parseProbability(value, optName: string): float =
  try:
    result = parseFloat(value)
  except ValueError:
    raise newException(ValueError, optName & " must be a number between 0 and 1.")
  if result < 0.0 or result > 1.0:
    raise newException(ValueError, optName & " must be between 0 and 1.")

proc scaledProbability(p: float): int {.inline.} =
  int(round(p * float(IdentityScale)))

proc normalizedReadName(name: string): string =
  let fields = name.splitWhitespace()
  if fields.len == 0:
    return ""
  result = fields[0]
  if result.len > 2 and (result.endsWith("/1") or result.endsWith("/2")):
    result.setLen(result.len - 2)

proc qualityToErrorProb(q: int): float =
  pow(10.0, -float(q) / 10.0)

proc errorProbToQuality(p: float): int =
  let bounded = max(p, MinErrorProbability)
  result = int(round(-10.0 * log10(bounded)))
  result = max(0, min(MaxFastqQual, result))

proc clampQuality(q: int): int {.inline.} =
  max(0, min(MaxFastqQual, q))

proc posteriorMatchQuality(q1, q2: int): int =
  let
    px = qualityToErrorProb(q1)
    py = qualityToErrorProb(q2)
    denom = 1.0 - px - py + (4.0 * px * py / 3.0)
  if denom <= 0.0:
    return max(q1, q2)
  errorProbToQuality((px * py / 3.0) / denom)

proc posteriorMismatchQuality(chosenQ, otherQ: int): int =
  let
    px = qualityToErrorProb(chosenQ)
    py = qualityToErrorProb(otherQ)
    denom = px + py - (4.0 * px * py / 3.0)
  if denom <= 0.0:
    return chosenQ
  errorProbToQuality((px * (1.0 - py / 3.0)) / denom)

proc initLowestQualityLookup(): QualityCharLookup =
  for c1 in 0 .. 255:
    let q1 = clampQuality(c1 - 33)
    for c2 in 0 .. 255:
      let q2 = clampQuality(c2 - 33)
      result[c1][c2] = qualToChar(min(q1, q2))

proc initMatchQualityLookup(): QualityCharLookup =
  for c1 in 0 .. 255:
    let q1 = clampQuality(c1 - 33)
    for c2 in 0 .. 255:
      let q2 = clampQuality(c2 - 33)
      result[c1][c2] = qualToChar(posteriorMatchQuality(q1, q2))

proc initMismatchQualityLookup(): QualityCharLookup =
  for c1 in 0 .. 255:
    let q1 = clampQuality(c1 - 33)
    for c2 in 0 .. 255:
      let q2 = clampQuality(c2 - 33)
      if q1 >= q2:
        result[c1][c2] = qualToChar(posteriorMismatchQuality(q1, q2))
      else:
        result[c1][c2] = qualToChar(posteriorMismatchQuality(q2, q1))

let
  lowestQualityLookup = initLowestQualityLookup()
  matchQualityLookup = initMatchQualityLookup()
  mismatchQualityLookup = initMismatchQualityLookup()

proc overlapQuality(q1, q2: char, basesMatch: bool,
                    strategy: QualityStrategy): char {.inline.} =
  case strategy
  of qsFirst:
    result = q1
  of qsLowest:
    result = lowestQualityLookup[q1.ord][q2.ord]
  of qsRecalculate:
    if basesMatch:
      result = matchQualityLookup[q1.ord][q2.ord]
    else:
      result = mismatchQualityLookup[q1.ord][q2.ord]

proc compareOverlap(r1seq, r2seq: string, pos, overlapLen, minOverlap: int,
                    minIdentityScaled: int): OverlapScore =
  let
    start1 = max(0, pos)
    start2 = max(0, -pos)
  result.effectiveLen = overlapLen

  for i in 0 ..< overlapLen:
    let
      b1 = r1seq[start1 + i]
      b2 = r2seq[start2 + i]

    if b1 == 'N' or b2 == 'N':
      dec result.effectiveLen
    elif b1 != b2:
      inc result.mismatches

    let maxPossibleEffective = result.effectiveLen + (overlapLen - i - 1)
    if maxPossibleEffective < minOverlap:
      return
    if (maxPossibleEffective - result.mismatches) * IdentityScale <
        maxPossibleEffective * minIdentityScaled:
      return

  if result.effectiveLen >= minOverlap:
    let matches = result.effectiveLen - result.mismatches
    result.identityScaled = (matches * IdentityScale) div result.effectiveLen
    if matches * IdentityScale >= result.effectiveLen * minIdentityScaled:
      result.valid = true
      result.identity = float(matches) / float(result.effectiveLen)

proc scoreOverlapPosition(r1Upper, r2Upper: string, pos, minPos, maxPos: int,
                          opts: MergeOptions, seen: var seq[bool],
                          best, accepted: var OverlapCandidate) =
  if pos < minPos or pos > maxPos:
    return
  let seenIndex = pos - minPos
  if seen[seenIndex]:
    return
  seen[seenIndex] = true

  let
    start1 = max(0, pos)
    start2 = max(0, -pos)
    overlapLen = min(r1Upper.len - start1, r2Upper.len - start2)
  if overlapLen < opts.minOverlap:
    return

  let score = compareOverlap(r1Upper, r2Upper, pos, overlapLen, opts.minOverlap,
                             opts.minIdentityScaled)
  if not score.valid:
    return

  let hit = OverlapCandidate(
    pos: pos,
    overlapLen: overlapLen,
    effectiveLen: score.effectiveLen,
    mismatches: score.mismatches,
    identityScaled: score.identityScaled,
    identity: score.identity
  )

  if hit.identityScaled >= opts.acceptedIdentityScaled:
    if accepted.pos == high(int) or
        hit.effectiveLen > accepted.effectiveLen or
        (hit.effectiveLen == accepted.effectiveLen and
         hit.identityScaled > accepted.identityScaled):
      accepted = hit
    return

  if best.pos == high(int) or
      hit.identityScaled > best.identityScaled or
      (hit.identityScaled == best.identityScaled and
       hit.effectiveLen > best.effectiveLen):
    best = hit

proc addUniqueSeedStart(starts: var seq[int], start, seedLen, seqLen: int) =
  if start < 0 or start + seedLen > seqLen:
    return
  for previous in starts:
    if previous == start:
      return
  starts.add(start)

proc findBestOverlap(r1seq, r2seq: string, opts: MergeOptions): OverlapCandidate =
  ## Find the best offset where reverse-complemented R2 aligns to R1.
  ## `pos` is the 0-based R1 coordinate where R2 starts; negative positions
  ## represent staggered/dovetailed pairs.
  result.pos = high(int)
  if r1seq.len == 0 or r2seq.len == 0:
    return

  let
    r1Upper = r1seq.toUpperAscii()
    r2Upper = r2seq.toUpperAscii()
    minPos = -r2seq.len + opts.minOverlap
    maxPos = r1seq.len - opts.minOverlap

  if minPos > maxPos:
    return

  var accepted: OverlapCandidate
  accepted.pos = high(int)
  var seen = newSeq[bool](maxPos - minPos + 1)

  if opts.searchMode == smSeeded:
    let seedLen = min(DefaultSeedLength, opts.minOverlap)
    var seedStarts: seq[int]

    addUniqueSeedStart(seedStarts, 0, seedLen, r2Upper.len)
    addUniqueSeedStart(seedStarts, (r2Upper.len - seedLen) div 4,
                       seedLen, r2Upper.len)
    addUniqueSeedStart(seedStarts, (r2Upper.len - seedLen) div 2,
                       seedLen, r2Upper.len)
    addUniqueSeedStart(seedStarts, ((r2Upper.len - seedLen) * 3) div 4,
                       seedLen, r2Upper.len)
    addUniqueSeedStart(seedStarts, r2Upper.len - seedLen, seedLen, r2Upper.len)

    for seedStart in seedStarts:
      let seed = r2Upper[seedStart ..< seedStart + seedLen]
      if seed.find('N') >= 0:
        continue

      var searchFrom = 0
      while searchFrom <= r1Upper.len - seedLen:
        let r1Hit = r1Upper.find(seed, searchFrom)
        if r1Hit < 0:
          break
        scoreOverlapPosition(r1Upper, r2Upper, r1Hit - seedStart, minPos,
                             maxPos, opts, seen, result, accepted)
        searchFrom = r1Hit + 1

    if accepted.pos != high(int):
      return accepted

  for pos in minPos .. maxPos:
    scoreOverlapPosition(r1Upper, r2Upper, pos, minPos, maxPos, opts, seen,
                         result, accepted)

  if accepted.pos != high(int):
    return accepted

proc mergedLength(r1Len, r2Len, pos: int): int =
  ## Staggered/contained alignments are trimmed to the shared insert, matching
  ## the adapter-removal behavior expected from dovetailed paired reads.
  if pos < 0 or pos + r2Len < r1Len:
    result = min(r1Len, pos + r2Len)
  else:
    result = max(r1Len, pos + r2Len)

proc mergeAtPosition(r1, rc2: FastxRecord, overlap: OverlapCandidate,
                     opts: MergeOptions): FastxRecord =
  let outLen = mergedLength(r1.seq.len, rc2.seq.len, overlap.pos)
  if outLen <= 0:
    return

  result = (
    seq: newStringOfCap(outLen),
    qual: newStringOfCap(outLen),
    name: r1.name,
    comment: r1.comment & ";overlap=" & $overlap.overlapLen &
             ";effective_overlap=" & $overlap.effectiveLen &
             ";identity=" & $overlap.identity,
    status: outLen,
    lastChar: 0
  )

  for i in 0 ..< outLen:
    let r2Index = i - overlap.pos
    if r2Index < 0:
      result.seq.add(r1.seq[i])
      result.qual.add(r1.qual[i])
    elif i >= r1.seq.len:
      result.seq.add(rc2.seq[r2Index])
      result.qual.add(rc2.qual[r2Index])
    else:
      let
        b1 = r1.seq[i]
        b2 = rc2.seq[r2Index]
        u1 = b1.toUpperAscii()
        u2 = b2.toUpperAscii()
        q1 = r1.qual[i]
        q2 = rc2.qual[r2Index]

      if u2 == 'N':
        result.seq.add(b1)
        result.qual.add(r1.qual[i])
      elif u1 == 'N':
        result.seq.add(b2)
        result.qual.add(rc2.qual[r2Index])
      elif u1 == u2:
        result.seq.add(b1)
        result.qual.add(overlapQuality(r1.qual[i], rc2.qual[r2Index],
                                       true, opts.qualityMethod))
      elif q1 >= q2:
        result.seq.add(b1)
        result.qual.add(overlapQuality(r1.qual[i], rc2.qual[r2Index],
                                       false, opts.qualityMethod))
      else:
        result.seq.add(b2)
        result.qual.add(overlapQuality(r1.qual[i], rc2.qual[r2Index],
                                       false, opts.qualityMethod))

proc appendFastqRecord(output: var string, record: FastxRecord) =
  output.add('@')
  output.add(record.name)
  if record.comment.len > 0:
    output.add(' ')
    output.add(record.comment)
  output.add('\n')
  output.add(record.seq)
  output.add("\n+\n")
  output.add(record.qual)
  output.add('\n')

proc mergeReads(r1, r2: FastxRecord, opts: MergeOptions): MergeResult =
  result.success = false

  if r1.seq.len == 0 or r2.seq.len == 0:
    result.message = "Empty sequence found"
    if opts.keepUnmerged:
      result.record = r1
    return

  if r1.qual.len != r1.seq.len or r2.qual.len != r2.seq.len:
    result.message = "Quality length mismatch"
    if opts.keepUnmerged:
      result.record = r1
    return

  let rc2 = revcompl(r2)
  let overlap = findBestOverlap(r1.seq, rc2.seq, opts)

  if overlap.pos == high(int):
    result.message = "Failed to merge: no valid overlap"
    if opts.keepUnmerged:
      result.record = r1
    return

  let merged = mergeAtPosition(r1, rc2, overlap, opts)
  if opts.minResultLength > 0 and merged.seq.len < opts.minResultLength:
    result.message = "Merged sequence too short"
    result.lengthDiscarded = true
    return

  if opts.maxResultLength > 0 and merged.seq.len > opts.maxResultLength:
    result.message = "Merged sequence too long"
    result.lengthDiscarded = true
    return

  result.success = true
  result.record = merged
  result.overlapLength = overlap.overlapLen
  result.effectiveOverlap = overlap.effectiveLen
  result.identity = overlap.identity

proc processMergeJob(job: ptr MergeJob, opts: MergeOptions) =
  for pair in job[].pairs:
    inc job[].processedCount

    let
      name1 = normalizedReadName(pair.r1.name)
      name2 = normalizedReadName(pair.r2.name)

    if name1 != name2:
      job[].warnings.add("WARNING: Read names don't match at pair " &
                         $pair.pairNum & "\n")
      job[].warnings.add("R1: " & name1 & "\n")
      job[].warnings.add("R2: " & name2 & "\n")
      continue

    let mergeResult = mergeReads(pair.r1, pair.r2, opts)

    if mergeResult.success:
      job[].output.appendFastqRecord(mergeResult.record)
      inc job[].mergedCount
    elif mergeResult.lengthDiscarded:
      inc job[].lengthDiscardedCount
    else:
      if opts.keepUnmerged and mergeResult.record.seq.len > 0:
        job[].output.appendFastqRecord(mergeResult.record)
      inc job[].failedCount

proc flushJobs(jobs: var seq[MergeJob], opts: MergeOptions, threads: int,
               processedCount, mergedCount, failedCount,
               lengthDiscardedCount: var int) =
  if jobs.len == 0:
    return

  if threads > 1 and jobs.len > 1:
    var m = createMaster()
    m.awaitAll:
      for i in 0 ..< jobs.len:
        m.spawn processMergeJob(addr jobs[i], opts)
  else:
    for i in 0 ..< jobs.len:
      processMergeJob(addr jobs[i], opts)

  for job in jobs:
    if job.warnings.len > 0:
      stderr.write(job.warnings)
    if job.output.len > 0:
      stdout.write(job.output)
    processedCount += job.processedCount
    mergedCount += job.mergedCount
    failedCount += job.failedCount
    lengthDiscardedCount += job.lengthDiscardedCount

  jobs.setLen(0)

proc fastq_merge*(argv: var seq[string]): int =
  let doc = """
Usage:
  merge [options] -1 FILE_R1 [-2 FILE_R2]
  merge [options] FILE_R1

Options:
  -1, --R1 FILE              First paired-end file
  -2, --R2 FILE              Second paired-end file (can be auto-inferred)

Merging options:
  -i, --min-id FLOAT         Minimum overlap identity [default: 0.90]
  -m, --min-overlap INT      Minimum overlap length [default: 20]
  --accept-id FLOAT          Accept overlap immediately above identity [default: 0.97]
  --search STR               Overlap search mode [default: seeded]
                             (seeded/exhaustive)
  --keep-unmerged            Output R1 when merging fails [default: false]

Output filter:
  --min-length INT           Minimum merged read length, 0 disables [default: 50]
  --max-length INT           Maximum merged read length, 0 disables [default: 0]
  
Quality options:
  --qual-method STR          Quality handling strategy [default: recalculate]
                             (first/lowest/recalculate)

Threading options:
  -t, --threads INT          Worker threads [default: $1]
  --batch-size INT           Read pairs per worker batch [default: 1024]

Other options:
  -v, --verbose              Print verbose messages
  -h, --help                 Show this help

  WARNING: Experimental interface
""".multiReplace(("$1", $ThreadPoolSize))

  let args = docopt(doc, version=version(), argv=argv)

  var opts: MergeOptions
  var threads: int
  var batchSize: int

  try:
    let
      minLenValue = $args["--min-length"]
      maxLenValue = $args["--max-length"]

    opts = MergeOptions(
      minOverlap: parsePositiveInt($args["--min-overlap"], "--min-overlap"),
      minIdentity: parseProbability($args["--min-id"], "--min-id"),
      acceptedIdentity: parseProbability($args["--accept-id"], "--accept-id"),
      keepUnmerged: args["--keep-unmerged"],
      minResultLength: parseNonNegativeInt(minLenValue, "--min-len"),
      maxResultLength: parseNonNegativeInt(maxLenValue, "--max-len")
    )
    threads = parsePositiveInt($args["--threads"], "--threads")
    batchSize = parsePositiveInt($args["--batch-size"], "--batch-size")
  except ValueError as e:
    stderr.writeLine("ERROR: ", e.msg)
    return 1

  if opts.acceptedIdentity < opts.minIdentity:
    stderr.writeLine("ERROR: --accept-id must be >= --min-id.")
    return 1

  opts.minIdentityScaled = scaledProbability(opts.minIdentity)
  opts.acceptedIdentityScaled = scaledProbability(opts.acceptedIdentity)

  if opts.maxResultLength > 0 and opts.minResultLength > opts.maxResultLength:
    stderr.writeLine("ERROR: --min-len must be <= --max-len when --max-len > 0.")
    return 1

  case $args["--qual-method"]
  of "first":
    opts.qualityMethod = qsFirst
  of "lowest":
    opts.qualityMethod = qsLowest
  of "recalculate":
    opts.qualityMethod = qsRecalculate
  else:
    stderr.writeLine("ERROR: Invalid quality method: ", $args["--qual-method"])
    stderr.writeLine("ERROR: Valid values are first, lowest, recalculate.")
    return 1

  case $args["--search"]
  of "seeded":
    opts.searchMode = smSeeded
  of "exhaustive":
    opts.searchMode = smExhaustive
  else:
    stderr.writeLine("ERROR: Invalid search mode: ", $args["--search"])
    stderr.writeLine("ERROR: Valid values are seeded, exhaustive.")
    return 1

  let file_R1 =
    if $args["--R1"] != "nil":
      $args["--R1"]
    else:
      $args["FILE_R1"]

  let file_R2 =
    if $args["--R2"] != "nil":
      $args["--R2"]
    else:
      guessR2(file_R1, "auto", "auto", true)

  if file_R1.len == 0 or file_R1 == "nil":
    stderr.writeLine("ERROR: Missing R1 file.")
    return 1

  if not fileExists(file_R1):
    stderr.writeLine("ERROR: Unable to find R1 file: ", file_R1)
    return 1

  if file_R2 == "":
    stderr.writeLine("ERROR: Unable to guess R2 filename")
    return 1

  if not fileExists(file_R2):
    stderr.writeLine("ERROR: Unable to find R2 file: ", file_R2)
    return 1

  var
    r1 = xopen[GzFile](file_R1)
    r2 = xopen[GzFile](file_R2)
  defer:
    discard r1.close()
    discard r2.close()

  var
    read1, read2: FastxRecord
    pairNum = 0
    processedCount = 0
    mergedCount = 0
    failedCount = 0
    lengthDiscardedCount = 0
    jobs = newSeqOfCap[MergeJob](max(1, min(threads, ThreadPoolSize)))
    currentJob = MergeJob(pairs: newSeqOfCap[PairInput](batchSize))

  let jobWindow = max(1, min(threads, ThreadPoolSize))

  proc enqueueCurrentJob() =
    if currentJob.pairs.len == 0:
      return
    jobs.add(currentJob)
    currentJob = MergeJob(pairs: newSeqOfCap[PairInput](batchSize))
    if jobs.len >= jobWindow:
      flushJobs(jobs, opts, threads, processedCount, mergedCount, failedCount,
                lengthDiscardedCount)

  while r1.readFastx(read1):
    inc pairNum
    if not r2.readFastx(read2):
      stderr.writeLine("ERROR: R2 file ended before R1 at pair ", pairNum)
      return 1

    currentJob.pairs.add(PairInput(pairNum: pairNum, r1: read1, r2: read2))
    if currentJob.pairs.len >= batchSize:
      enqueueCurrentJob()

  if r2.readFastx(read2):
    stderr.writeLine("ERROR: R1 file ended before R2 after pair ", pairNum)
    return 1

  enqueueCurrentJob()
  flushJobs(jobs, opts, threads, processedCount, mergedCount, failedCount,
            lengthDiscardedCount)

  if args["--verbose"]:
    stderr.writeLine("Processed ", processedCount, " pairs")
    stderr.writeLine("Successfully merged: ", mergedCount)
    stderr.writeLine("Failed to merge: ", failedCount)
    stderr.writeLine("Discarded by read length: ", lengthDiscardedCount)

  return 0
