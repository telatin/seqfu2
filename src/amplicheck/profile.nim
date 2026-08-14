import math
import tables

import ../seqfu_utils
import ./types

type
  LengthAccumulator* = object
    n: int
    sum, sumSq: float
    minLen, maxLen: int
    hist: CountTable[int]

  QualityAccumulator* = object
    n: int
    totalBases: int
    skippedTooLong: int
    totalQual: NumericAccumulator
    perPosSum: seq[float]
    perPosCount: seq[int]
    qCounts: seq[array[QualityScoreSlots, int]]
    qDistinct: CountTable[int]

proc initLengthAccumulator*(): LengthAccumulator =
  result.hist = initCountTable[int]()

proc initQualityAccumulator*(): QualityAccumulator =
  result.qDistinct = initCountTable[int]()

proc addLength*(acc: var LengthAccumulator, length: int) =
  if acc.n == 0:
    acc.minLen = length
    acc.maxLen = length
  else:
    if length < acc.minLen:
      acc.minLen = length
    if length > acc.maxLen:
      acc.maxLen = length
  acc.n += 1
  acc.sum += float(length)
  acc.sumSq += float(length * length)
  acc.hist.inc(length)

proc addQuality*(acc: var QualityAccumulator, quality: string) =
  if quality.len > MaxQualityReadLength:
    acc.skippedTooLong += 1
    return

  acc.n += 1
  acc.totalBases += quality.len
  if acc.perPosSum.len < quality.len:
    let oldLen = acc.perPosSum.len
    acc.perPosSum.setLen(quality.len)
    acc.perPosCount.setLen(quality.len)
    acc.qCounts.setLen(quality.len)
    for i in oldLen ..< quality.len:
      acc.perPosSum[i] = 0.0
      acc.perPosCount[i] = 0

  for i, qchar in quality:
    let q = charToQual(qchar)
    acc.perPosSum[i] += float(q)
    acc.perPosCount[i] += 1
    acc.qDistinct.inc(q)
    if q >= 0 and q < QualityScoreSlots:
      acc.qCounts[i][q] += 1
    acc.totalQual.add(float(q))

proc summarize*(acc: LengthAccumulator): ReadLengthSummary =
  result.n = acc.n
  if acc.n == 0:
    return

  result.mean = acc.sum / float(acc.n)
  if acc.n > 1:
    let variance = (acc.sumSq - (acc.sum * acc.sum / float(acc.n))) / float(acc.n - 1)
    result.sd = sqrt(max(0.0, variance))
  result.min = acc.minLen
  result.max = acc.maxLen

  var bestCount = -1
  for length, count in acc.hist.pairs:
    if count > bestCount or (count == bestCount and length < result.mode):
      bestCount = count
      result.mode = length

proc qualityStop(means: seq[float], threshold = 25.0, minPos = 50): int =
  if means.len == 0:
    return 0
  for i, meanQ in means:
    if i >= minPos and meanQ < threshold:
      return i
  means.len

proc summarize*(acc: QualityAccumulator): ReadQualitySummary =
  result.n = acc.n
  result.totalBases = acc.totalBases
  result.skippedTooLong = acc.skippedTooLong
  if acc.n == 0:
    return

  result.meanQuality = acc.totalQual.mean
  result.distinctValues = acc.qDistinct.len
  result.binned = result.distinctValues > 0 and result.distinctValues <= 10
  result.perPositionMean = newSeq[float](acc.perPosSum.len)
  for i in 0 ..< acc.perPosSum.len:
    if acc.perPosCount[i] > 0:
      result.perPositionMean[i] = acc.perPosSum[i] / float(acc.perPosCount[i])
  result.qCounts = acc.qCounts
  result.suggestedTruncLen = qualityStop(result.perPositionMean)
