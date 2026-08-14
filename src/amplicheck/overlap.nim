import math

import ../seqfu_utils
import ./types

type
  OverlapHit* = object
    success*: bool
    overlap*, mergedSize*: int
    identity*: float

  MergeAccumulator* = object
    attempted, merged, unmergeable: int
    overlaps, identities, mergedSizes: NumericAccumulator

  SweepComboAccumulator = object
    truncLenFwd, truncLenRev: int
    maxEE: float
    scanned, retained, merged: int

  SweepAccumulator* = object
    combos: seq[SweepComboAccumulator]
    minOverlap: int
    minIdentity: float

proc estimateOverlap*(r1seq, r2seq: string, minOverlap: int,
                      minIdentity: float): OverlapHit =
  if r1seq.len == 0 or r2seq.len == 0:
    return

  let rc2 = revcompl(r2seq)
  let maxOverlap = min(r1seq.len, rc2.len)
  if maxOverlap < minOverlap:
    return

  var bestIdentity = 0.0
  var bestOverlap = -1

  for overlap in countdown(maxOverlap, minOverlap):
    let r1Start = r1seq.len - overlap
    var matches = 0
    for i in 0 ..< overlap:
      if r1seq[r1Start + i] == rc2[i]:
        matches += 1
    let identity = float(matches) / float(overlap)
    if identity > bestIdentity:
      bestIdentity = identity
      bestOverlap = overlap
      if identity >= 0.97:
        break

  if bestOverlap >= minOverlap and bestIdentity >= minIdentity:
    result.success = true
    result.overlap = bestOverlap
    result.identity = bestIdentity * 100.0
    result.mergedSize = r1seq.len + r2seq.len - bestOverlap

proc add*(acc: var MergeAccumulator, hit: OverlapHit) =
  acc.attempted += 1
  if hit.success:
    acc.merged += 1
    acc.overlaps.add(float(hit.overlap))
    acc.identities.add(hit.identity)
    acc.mergedSizes.add(float(hit.mergedSize))
  else:
    acc.unmergeable += 1

proc summarize*(acc: MergeAccumulator, ampliconCall: string): MergeSummary =
  result.attempted = acc.attempted
  result.merged = acc.merged
  result.unmergeable = acc.unmergeable
  if acc.attempted > 0:
    result.pctUnmergeable = 100.0 * float(acc.unmergeable) / float(acc.attempted)
  result.overlapMean = acc.overlaps.mean
  result.overlapSd = acc.overlaps.sd
  result.identityMean = acc.identities.mean
  result.identitySd = acc.identities.sd
  result.expectedMergedSizeMean = acc.mergedSizes.mean
  result.expectedMergedSizeSd = acc.mergedSizes.sd
  result.ampliconCall = ampliconCall

proc expectedErrors(quality: string, truncLen: int): float =
  let usable = if truncLen <= 0: quality.len else: truncLen
  if usable > quality.len:
    return Inf
  for i in 0 ..< usable:
    let q = charToQual(quality[i])
    result += pow(10.0, -float(q) / 10.0)

proc truncSeq(sequence: string, truncLen: int): string =
  let usable = if truncLen <= 0: sequence.len else: truncLen
  if usable > sequence.len:
    return ""
  sequence[0 ..< usable]

proc initSweepAccumulator*(truncLenGrid: seq[int], maxEEGrid: seq[float],
                           minOverlap: int, minIdentity: float): SweepAccumulator =
  result.minOverlap = minOverlap
  result.minIdentity = minIdentity
  for truncFwd in truncLenGrid:
    for truncRev in truncLenGrid:
      for maxEE in maxEEGrid:
        result.combos.add(SweepComboAccumulator(
          truncLenFwd: truncFwd,
          truncLenRev: truncRev,
          maxEE: maxEE
        ))

proc add*(acc: var SweepAccumulator, r1seq, r1qual, r2seq, r2qual: string) =
  for i in 0 ..< acc.combos.len:
    acc.combos[i].scanned += 1
    let
      ee1 = expectedErrors(r1qual, acc.combos[i].truncLenFwd)
      ee2 = expectedErrors(r2qual, acc.combos[i].truncLenRev)
    if ee1 > acc.combos[i].maxEE or ee2 > acc.combos[i].maxEE:
      continue

    let
      t1 = truncSeq(r1seq, acc.combos[i].truncLenFwd)
      t2 = truncSeq(r2seq, acc.combos[i].truncLenRev)
    if t1.len == 0 or t2.len == 0:
      continue

    acc.combos[i].retained += 1
    if estimateOverlap(t1, t2, acc.minOverlap, acc.minIdentity).success:
      acc.combos[i].merged += 1

proc summarize*(acc: SweepAccumulator): SweepSummary =
  result.enabled = acc.combos.len > 0
  var bestScore = -1.0
  for combo in acc.combos:
    var item = SweepComboSummary(
      truncLenFwd: combo.truncLenFwd,
      truncLenRev: combo.truncLenRev,
      maxEE: combo.maxEE,
      scanned: combo.scanned,
      retained: combo.retained,
      merged: combo.merged
    )
    if combo.scanned > 0:
      item.retentionPct = 100.0 * float(combo.retained) / float(combo.scanned)
    if combo.retained > 0:
      item.mergeRatePct = 100.0 * float(combo.merged) / float(combo.retained)
    item.score = item.retentionPct * item.mergeRatePct / 100.0
    result.combos.add(item)
    if item.score > bestScore:
      bestScore = item.score
      result.best = item
