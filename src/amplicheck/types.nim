import math

const
  MaxQualityReadLength* = 10000
  QualityScoreSlots* = 94

type
  AmplicheckStage* = enum
    stPrimers,
    stLength,
    stQuality,
    stMerge,
    stSweep

  AmpliconMode* = enum
    amAuto,
    am16s,
    amIts

  PairInput* = object
    sampleId*, r1*, r2*: string

  AmplicheckOptions* = object
    fwdTag*, revTag*: string
    outdir*: string
    maxReads*: int
    subsample*: float
    stages*: set[AmplicheckStage]
    amplicon*: AmpliconMode
    writeJson*, writeText*, plot*, verbose*: bool
    truncLenGrid*: seq[int]
    maxEEGrid*: seq[float]
    minOverlap*: int
    minIdentity*: float

  NumericAccumulator* = object
    n*: int
    sum*, sumSq*: float
    min*, max*: float

  ReadLengthSummary* = object
    n*: int
    mean*, sd*: float
    min*, max*, mode*: int

  ReadQualitySummary* = object
    n*: int
    totalBases*: int
    skippedTooLong*: int
    binned*: bool
    distinctValues*: int
    meanQuality*: float
    suggestedTruncLen*: int
    perPositionMean*: seq[float]
    qCounts*: seq[array[QualityScoreSlots, int]]

  PrimerSideSummary* = object
    detected*: bool
    primer*, label*, direction*: string
    targetDomain*, region*, citation*: string
    consensus*: string
    supportCount*: int
    supportFraction*, score*: float

  PrimerSummary* = object
    detected*: bool
    orientationConsistent*: bool
    fwdPrimer*, revPrimer*: string
    fwdLabel*, revLabel*: string
    r1*, r2*: PrimerSideSummary

  MergeSummary* = object
    attempted*, merged*, unmergeable*: int
    overlapMean*, overlapSd*: float
    identityMean*, identitySd*: float
    expectedMergedSizeMean*, expectedMergedSizeSd*: float
    pctUnmergeable*: float
    ampliconCall*: string

  SweepComboSummary* = object
    truncLenFwd*, truncLenRev*: int
    maxEE*: float
    scanned*, retained*, merged*: int
    retentionPct*, mergeRatePct*, score*: float

  SweepSummary* = object
    enabled*: bool
    combos*: seq[SweepComboSummary]
    best*: SweepComboSummary

  Recommendation* = object
    truncLenFwd*, truncLenRev*: int
    maxEE*: seq[float]
    truncQ*: int
    strategy*, note*: string

  AmplicheckReport* = object
    sampleId*, r1*, r2*: string
    nReadsScanned*, nReadsSampled*: int
    nReadsTotalKnown*: bool
    primersEnabled*, lengthEnabled*, qualityEnabled*: bool
    mergeEnabled*, sweepEnabled*, recommendationEnabled*: bool
    lengthR1*, lengthR2*: ReadLengthSummary
    qualityR1*, qualityR2*: ReadQualitySummary
    primers*: PrimerSummary
    merge*: MergeSummary
    sweep*: SweepSummary
    recommendation*: Recommendation

proc add*(acc: var NumericAccumulator, value: float) =
  if acc.n == 0:
    acc.min = value
    acc.max = value
  else:
    if value < acc.min:
      acc.min = value
    if value > acc.max:
      acc.max = value
  acc.n += 1
  acc.sum += value
  acc.sumSq += value * value

proc mean*(acc: NumericAccumulator): float =
  if acc.n == 0:
    return 0.0
  acc.sum / float(acc.n)

proc sd*(acc: NumericAccumulator): float =
  if acc.n < 2:
    return 0.0
  let variance = (acc.sumSq - (acc.sum * acc.sum / float(acc.n))) / float(acc.n - 1)
  sqrt(max(0.0, variance))

proc stageName*(stage: AmplicheckStage): string =
  case stage
  of stPrimers: "primers"
  of stLength: "length"
  of stQuality: "quality"
  of stMerge: "merge"
  of stSweep: "sweep"

proc ampliconName*(mode: AmpliconMode): string =
  case mode
  of amAuto: "auto"
  of am16s: "16s"
  of amIts: "its"
