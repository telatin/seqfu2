import strformat
import strutils

import klib

import ./overlap
import ./primers
import ./profile
import ./recommend
import ./types

type
  PeriodicSampler = object
    fraction: float
    acc: float

proc keep(sampler: var PeriodicSampler): bool =
  if sampler.fraction >= 1.0:
    return true
  sampler.acc += sampler.fraction
  if sampler.acc + 1e-12 >= 1.0:
    sampler.acc -= 1.0
    return true
  false

proc progressInterval(maxReads: int): int =
  if maxReads == 0:
    return 100000
  if maxReads <= 20:
    return max(1, maxReads div 2)
  if maxReads <= 1000:
    return max(10, maxReads div 10)
  min(100000, max(1000, maxReads div 10))

proc stageList(stages: set[AmplicheckStage]): string =
  var names: seq[string]
  for stage in [stPrimers, stLength, stQuality, stMerge, stSweep]:
    if stage in stages:
      names.add(stage.stageName)
  if names.len == 0:
    return "none"
  names.join(",")

proc analyzePair*(pair: PairInput, opts: AmplicheckOptions): AmplicheckReport =
  result.sampleId = pair.sampleId
  result.r1 = pair.r1
  result.r2 = pair.r2
  result.primersEnabled = stPrimers in opts.stages
  result.lengthEnabled = stLength in opts.stages
  result.qualityEnabled = stQuality in opts.stages
  result.mergeEnabled = stMerge in opts.stages
  result.sweepEnabled = stSweep in opts.stages

  var
    lenR1 = initLengthAccumulator()
    lenR2 = initLengthAccumulator()
    qualR1 = initQualityAccumulator()
    qualR2 = initQualityAccumulator()
    primerAcc: PrimerAccumulator
    mergeAcc: MergeAccumulator
    sweepAcc = initSweepAccumulator(opts.truncLenGrid, opts.maxEEGrid,
                                    opts.minOverlap, opts.minIdentity)
    sampler = PeriodicSampler(fraction: opts.subsample)
    r1 = xopen[GzFile](pair.r1)
    r2 = xopen[GzFile](pair.r2)
    read1, read2, extra: FastxRecord
    hitMaxReads = false
    progressEvery = progressInterval(opts.maxReads)

  if result.primersEnabled:
    primerAcc = initPrimerAccumulator()

  if opts.verbose:
    let maxReadsText =
      if opts.maxReads == 0: "all"
      else: $opts.maxReads
    stderr.writeLine(fmt"amplicheck: sample {pair.sampleId}: start r1={pair.r1} r2={pair.r2} max_reads={maxReadsText} subsample={opts.subsample} stages={stageList(opts.stages)}")

  defer:
    r1.close()
    r2.close()

  while r1.readFastx(read1):
    if not r2.readFastx(read2):
      raise newException(ValueError, fmt"R2 ended before R1 in sample {pair.sampleId}")

    result.nReadsScanned += 1
    if sampler.keep():
      result.nReadsSampled += 1

      if result.lengthEnabled:
        lenR1.addLength(read1.seq.len)
        lenR2.addLength(read2.seq.len)

      if result.qualityEnabled:
        qualR1.addQuality(read1.qual)
        qualR2.addQuality(read2.qual)

      if result.primersEnabled:
        primerAcc.addPrimerPair(read1.seq, read2.seq)

      if result.mergeEnabled:
        mergeAcc.add(estimateOverlap(read1.seq, read2.seq,
                                     opts.minOverlap, opts.minIdentity))

      if result.sweepEnabled:
        sweepAcc.add(read1.seq, read1.qual, read2.seq, read2.qual)

    if opts.verbose and result.nReadsScanned mod progressEvery == 0:
      stderr.writeLine(fmt"amplicheck: sample {pair.sampleId}: progress scanned={result.nReadsScanned} sampled={result.nReadsSampled}")

    if opts.maxReads > 0 and result.nReadsScanned >= opts.maxReads:
      hitMaxReads = true
      break

  if not hitMaxReads and r2.readFastx(extra):
    raise newException(ValueError, fmt"R2 has more reads than R1 in sample {pair.sampleId}")

  result.nReadsTotalKnown = not hitMaxReads

  if opts.verbose:
    let stopReason =
      if hitMaxReads: "stopped at max_reads"
      else: "full file scanned"
    stderr.writeLine(fmt"amplicheck: sample {pair.sampleId}: parsed scanned={result.nReadsScanned} sampled={result.nReadsSampled} ({stopReason})")

  if result.lengthEnabled:
    result.lengthR1 = lenR1.summarize()
    result.lengthR2 = lenR2.summarize()

  if result.qualityEnabled:
    result.qualityR1 = qualR1.summarize()
    result.qualityR2 = qualR2.summarize()

  if result.primersEnabled:
    result.primers = primerAcc.summarize()

  var mergePrelim: MergeSummary
  if result.mergeEnabled:
    mergePrelim = mergeAcc.summarize("")
  let ampliconCall = inferAmpliconCall(opts.amplicon,
                                       result.lengthR1,
                                       result.lengthR2,
                                       mergePrelim)

  if result.mergeEnabled:
    result.merge = mergeAcc.summarize(ampliconCall)

  if result.sweepEnabled:
    result.sweep = sweepAcc.summarize()

  result.recommendationEnabled = result.lengthEnabled and result.qualityEnabled
  if result.recommendationEnabled:
    let mergeForRec =
      if result.mergeEnabled: result.merge
      else: MergeSummary(ampliconCall: ampliconCall)
    result.recommendation = makeRecommendation(opts.amplicon,
                                               result.lengthR1,
                                               result.lengthR2,
                                               result.qualityR1,
                                               result.qualityR2,
                                               mergeForRec)
