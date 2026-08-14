import math
import strformat

import ./types

proc isVariableLength(r1, r2: ReadLengthSummary): bool =
  if r1.n == 0 or r2.n == 0:
    return false
  (r1.sd > 5.0 or r2.sd > 5.0 or
   (r1.max - r1.min) > 20 or (r2.max - r2.min) > 20)

proc inferAmpliconCall*(mode: AmpliconMode, r1, r2: ReadLengthSummary,
                        merge: MergeSummary): string =
  case mode
  of am16s:
    return "16s"
  of amIts:
    return "its"
  of amAuto:
    if isVariableLength(r1, r2) or merge.overlapSd > 20.0:
      return "its"
    "16s"

proc fallbackLen(summary: ReadLengthSummary): int =
  if summary.mode > 0:
    summary.mode
  elif summary.mean > 0:
    int(round(summary.mean))
  else:
    0

proc chooseTruncLen(length: ReadLengthSummary, quality: ReadQualitySummary): int =
  if quality.suggestedTruncLen > 0:
    min(quality.suggestedTruncLen, fallbackLen(length))
  else:
    fallbackLen(length)

proc makeRecommendation*(mode: AmpliconMode, r1Len, r2Len: ReadLengthSummary,
                         r1Qual, r2Qual: ReadQualitySummary,
                         merge: MergeSummary): Recommendation =
  let
    variable = isVariableLength(r1Len, r2Len) or mode == amIts
    binned = r1Qual.binned or r2Qual.binned

  result.maxEE = @[2.0, 3.0]
  result.truncQ = if binned: 11 else: 2

  if variable:
    result.strategy = "variable_length_no_trunc"
    result.truncLenFwd = 0
    result.truncLenRev = 0
    result.note = "Variable read lengths detected; avoid fixed truncLen unless downstream merging is validated."
    return

  result.truncLenFwd = chooseTruncLen(r1Len, r1Qual)
  result.truncLenRev = chooseTruncLen(r2Len, r2Qual)

  if merge.attempted > 0 and merge.pctUnmergeable > 40.0:
    result.strategy = "concatenate_fallback"
    result.note = fmt"Estimated unmergeable pairs are high ({merge.pctUnmergeable:.1f}%)."
  else:
    result.strategy = "fixed_truncLen"
    if binned:
      result.note = "Binned quality scores detected; truncQ is emphasized over a sharp quality-curve cliff."
    else:
      result.note = "Fixed read lengths and acceptable overlap support fixed truncLen."
