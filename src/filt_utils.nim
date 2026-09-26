## filt_utils.nim - Shared utility procs for long-read and short-read trimming/QC
## Exports sliding-window trimmers, poly-X trimmer, per-read metrics, and aggregate stats.

import math
import algorithm
import strutils

#############################
# Sliding-window trim procs
#############################

proc slidingCutFront*(quality: string; startPos, endPos,
                      windowSize, qualThreshold, offset: int): int =
  ## Find first position from 5' where window has avg quality >= threshold.
  ## Returns new startPos. Works in ASCII space.
  let targetQualSum = windowSize * (qualThreshold + offset)

  if (endPos - startPos) < windowSize:
    return endPos

  var qualSum = 0
  for i in startPos ..< (startPos + windowSize):
    qualSum += quality[i].ord

  if qualSum >= targetQualSum:
    return startPos

  for pos in (startPos + 1) .. (endPos - windowSize):
    qualSum += quality[pos + windowSize - 1].ord
    qualSum -= quality[pos - 1].ord

    if qualSum >= targetQualSum:
      return pos

  return endPos


proc slidingCutTail*(quality: string; startPos, endPos,
                     windowSize, qualThreshold, offset: int): int =
  ## Mirror of slidingCutFront, operates right to left.
  ## Returns new endPos.
  let targetQualSum = windowSize * (qualThreshold + offset)

  if (endPos - startPos) < windowSize:
    return startPos

  var qualSum = 0
  for i in (endPos - windowSize) ..< endPos:
    qualSum += quality[i].ord

  if qualSum >= targetQualSum:
    return endPos

  for pos in countdown(endPos - windowSize - 1, startPos):
    qualSum += quality[pos].ord
    qualSum -= quality[pos + windowSize].ord

    if qualSum >= targetQualSum:
      return pos + windowSize

  return startPos


proc slidingCutRight*(sequence, quality: string; startPos, endPos,
                      windowSize, qualThreshold, offset: int): int =
  ## Scan from 5'; truncate at first failing window (fastp cut-right).
  ## Returns new endPos.
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
      for cutPos in pos ..< (pos + windowSize):
        if (quality[cutPos].ord - offset) < qualThreshold:
          return cutPos
      return pos

  return endPos


#############################
# Poly-X trimming
#############################

proc trimPolyX*(sq, qu: var string; minRunLen: int) =
  ## Trim 3' poly-X tail in-place.
  ## Tries each of A/C/G/T as dominant base independently.
  ## Keeps the trim that removes the most.
  let n = sq.len
  if n == 0:
    return

  var bestCutPos = n  # default: no trim

  for dominant in ['A', 'C', 'G', 'T']:
    let allowedMismatches = min(5, n div 8)
    var cutPos = n
    var mismatches = 0

    var i = n - 1
    while i >= 0:
      if sq[i] == dominant:
        cutPos = i
      else:
        mismatches += 1
        if mismatches > allowedMismatches:
          break
      i -= 1

    if (n - cutPos) >= minRunLen and cutPos < bestCutPos:
      bestCutPos = cutPos

  if bestCutPos < n:
    sq.setLen(bestCutPos)
    qu.setLen(bestCutPos)


#############################
# Per-read quality metrics
#############################

const PHRED_OFFSET* = 33

type
  ReadQualMetrics* = object
    seqLen*:      int
    gcCount*:     int
    nCount*:      int
    qualSum*:     int        ## sum of Phred scores
    unqualCount*: int        ## bases below qualThreshold
    q5Bases*:     int
    q7Bases*:     int
    q10Bases*:    int
    q15Bases*:    int
    q20Bases*:    int
    q30Bases*:    int
    meanQual*:    float
    gcPct*:       float
    nPct*:        float
    unqualPct*:   float
    complexity*:  float      ## transition score 0.0–100.0


proc computeReadMetrics*(sq, qu: string; qualThreshold: int): ReadQualMetrics =
  ## Single-pass computation of per-read quality metrics.
  ## FASTA (empty qu) accepted: quality fields will be 0.
  let n = sq.len
  result.seqLen = n
  if n == 0:
    return

  var transitions = 0
  let hasQual = qu.len == n

  for i in 0 ..< n:
    let base = sq[i]
    # GC count
    if base == 'G' or base == 'C' or base == 'g' or base == 'c':
      result.gcCount += 1
    elif base == 'N' or base == 'n':
      result.nCount += 1

    # Transitions (complexity)
    if i > 0 and sq[i] != sq[i - 1]:
      transitions += 1

    # Quality
    if hasQual:
      let q = qu[i].ord - PHRED_OFFSET
      result.qualSum += q
      if q < qualThreshold:
        result.unqualCount += 1
      if q >= 5:  result.q5Bases  += 1
      if q >= 7:  result.q7Bases  += 1
      if q >= 10: result.q10Bases += 1
      if q >= 15: result.q15Bases += 1
      if q >= 20: result.q20Bases += 1
      if q >= 30: result.q30Bases += 1

  # Compute rates
  result.meanQual = if hasQual and n > 0: float(result.qualSum) / float(n) else: 0.0
  result.gcPct    = float(result.gcCount) * 100.0 / float(n)
  result.nPct     = float(result.nCount)  * 100.0 / float(n)
  result.unqualPct = float(result.unqualCount) * 100.0 / float(n)
  result.complexity = if n <= 1: 100.0
                      else: float(transitions) * 100.0 / float(n - 1)


#############################
# Aggregate long-read stats
#############################

type
  LrLenHistogram* = object
    binSize*: int
    counts*:  seq[int64]

  LrReadStats* = object
    totalReads*:  int64
    totalBases*:  int64
    minLen*:      int
    maxLen*:      int
    qualSum*:     float      ## running sum of per-read mean qualities
    q5Bases*:     int64
    q7Bases*:     int64
    q10Bases*:    int64
    q15Bases*:    int64
    q20Bases*:    int64
    q30Bases*:    int64
    gcBases*:     int64
    qualDist*:    array[0..60, int64]   ## index = clamp(round(meanQual), 0, 60)
    gcDist*:      array[0..100, int64]  ## index = clamp(round(gcPct), 0, 100)
    lengths*:     seq[int]              ## raw lengths for N50 + histogram


proc addToLrReadStats*(stats: var LrReadStats; metrics: ReadQualMetrics) =
  ## Add one read's metrics into aggregate stats.
  inc stats.totalReads
  stats.totalBases += int64(metrics.seqLen)

  if stats.totalReads == 1:
    stats.minLen = metrics.seqLen
    stats.maxLen = metrics.seqLen
  else:
    if metrics.seqLen < stats.minLen: stats.minLen = metrics.seqLen
    if metrics.seqLen > stats.maxLen: stats.maxLen = metrics.seqLen

  stats.qualSum  += metrics.meanQual
  stats.q5Bases  += int64(metrics.q5Bases)
  stats.q7Bases  += int64(metrics.q7Bases)
  stats.q10Bases += int64(metrics.q10Bases)
  stats.q15Bases += int64(metrics.q15Bases)
  stats.q20Bases += int64(metrics.q20Bases)
  stats.q30Bases += int64(metrics.q30Bases)
  stats.gcBases  += int64(metrics.gcCount)

  let qBin  = clamp(int(round(metrics.meanQual)), 0, 60)
  let gcBin = clamp(int(round(metrics.gcPct)),    0, 100)
  stats.qualDist[qBin] += 1
  stats.gcDist[gcBin]  += 1

  stats.lengths.add(metrics.seqLen)


proc calcN50*(lengths: var seq[int]): int =
  ## Sort descending in-place; return N50.
  lengths.sort(SortOrder.Descending)
  var total: int64 = 0
  for l in lengths: total += int64(l)
  let target = total div 2
  var acc: int64 = 0
  for l in lengths:
    acc += int64(l)
    if acc >= target:
      return l
  return 0


proc lenHistBinSize*(maxLen: int): int =
  ## Return adaptive bin size based on maximum length.
  if maxLen <= 10_000:   return 100
  elif maxLen <= 100_000: return 1_000
  else:                  return 10_000


proc buildLenHistogram*(lengths: seq[int]; maxLen: int): LrLenHistogram =
  ## Build adaptive-bin histogram from a length list.
  result.binSize = lenHistBinSize(maxLen)
  let numBins = maxLen div result.binSize + 1
  result.counts = newSeq[int64](numBins)
  for l in lengths:
    let bin = l div result.binSize
    if bin < result.counts.len:
      result.counts[bin] += 1
