import strformat
import strutils

import ../seqfu_legacy_fastx

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

proc analyzeInput*(input: AmplicheckInput, opts: AmplicheckOptions,
                   verboseLog: var string,
                   bufferVerbose: bool): AmplicheckReport =
  result.sampleId = input.sampleId
  result.r1 = input.r1
  result.r2 = input.r2
  result.layout = input.layout
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
    r1 = xopen[GzFile](input.r1)
    read1, read2, extra: FastxRecord
    hitMaxReads = false
    progressEvery = progressInterval(opts.maxReads)

  if result.primersEnabled:
    primerAcc = initPrimerAccumulator()

  template writeVerboseLine(message: string) =
    if bufferVerbose:
      verboseLog.add(message & "\n")
    else:
      stderr.writeLine(message)

  if opts.verbose:
    let maxReadsText =
      if opts.maxReads == 0: "all"
      else: $opts.maxReads
    let inputText =
      if input.layout == rlPairedEnd: fmt"r1={input.r1} r2={input.r2}"
      else: fmt"read={input.r1}"
    writeVerboseLine(fmt"amplicheck: sample {input.sampleId}: start {inputText} max_reads={maxReadsText} subsample={opts.subsample} stages={stageList(opts.stages)}")

  defer:
    r1.close()

  template processReads(paired: bool) =
    result.nReadsScanned += 1
    if sampler.keep():
      result.nReadsSampled += 1

      if result.lengthEnabled:
        lenR1.addLength(read1.seq.len)
        if paired:
          lenR2.addLength(read2.seq.len)

      if result.qualityEnabled:
        qualR1.addQuality(read1.qual)
        if paired:
          qualR2.addQuality(read2.qual)

      if result.primersEnabled:
        if paired:
          primerAcc.addPrimerPair(read1.seq, read2.seq)
        else:
          primerAcc.addPrimerRead(read1.seq)

      if paired and result.mergeEnabled:
        mergeAcc.add(estimateOverlap(read1.seq, read2.seq,
                                     opts.minOverlap, opts.minIdentity))

      if paired and result.sweepEnabled:
        sweepAcc.add(read1.seq, read1.qual, read2.seq, read2.qual)

    if opts.verbose and result.nReadsScanned mod progressEvery == 0:
      writeVerboseLine(fmt"amplicheck: sample {input.sampleId}: progress scanned={result.nReadsScanned} sampled={result.nReadsSampled}")

  if input.layout == rlPairedEnd:
    var r2 = xopen[GzFile](input.r2)
    defer:
      r2.close()
    while r1.readFastx(read1):
      if not r2.readFastx(read2):
        raise newException(ValueError, fmt"R2 ended before R1 in sample {input.sampleId}")
      processReads(true)

      if opts.maxReads > 0 and result.nReadsScanned >= opts.maxReads:
        hitMaxReads = true
        break

    if not hitMaxReads and r2.readFastx(extra):
      raise newException(ValueError, fmt"R2 has more reads than R1 in sample {input.sampleId}")
  else:
    while r1.readFastx(read1):
      processReads(false)

      if opts.maxReads > 0 and result.nReadsScanned >= opts.maxReads:
        hitMaxReads = true
        break

  result.nReadsTotalKnown = not hitMaxReads

  if opts.verbose:
    let stopReason =
      if hitMaxReads: "stopped at max_reads"
      else: "full file scanned"
    writeVerboseLine(fmt"amplicheck: sample {input.sampleId}: parsed scanned={result.nReadsScanned} sampled={result.nReadsSampled} ({stopReason})")

  if result.lengthEnabled:
    result.lengthR1 = lenR1.summarize()
    if input.layout == rlPairedEnd:
      result.lengthR2 = lenR2.summarize()

  if result.qualityEnabled:
    result.qualityR1 = qualR1.summarize()
    if input.layout == rlPairedEnd:
      result.qualityR2 = qualR2.summarize()

  if result.primersEnabled:
    result.primers =
      if input.layout == rlPairedEnd: primerAcc.summarize()
      else: primerAcc.summarizeSingle()

  var mergePrelim: MergeSummary
  if result.mergeEnabled:
    mergePrelim = mergeAcc.summarize("")
  let ampliconCall =
    if input.layout == rlPairedEnd:
      inferAmpliconCall(opts.amplicon, result.lengthR1,
                        result.lengthR2, mergePrelim)
    else:
      opts.amplicon.ampliconName

  if result.mergeEnabled:
    result.merge = mergeAcc.summarize(ampliconCall)

  if result.sweepEnabled:
    result.sweep = sweepAcc.summarize()

  result.recommendationEnabled = result.lengthEnabled and result.qualityEnabled
  if result.recommendationEnabled:
    if input.layout == rlSingleEnd:
      result.recommendation = makeSingleRecommendation(opts.amplicon,
                                                        result.lengthR1,
                                                        result.qualityR1)
    else:
      let mergeForRec =
        if result.mergeEnabled: result.merge
        else: MergeSummary(ampliconCall: ampliconCall)
      result.recommendation = makeRecommendation(opts.amplicon,
                                                  result.lengthR1,
                                                  result.lengthR2,
                                                  result.qualityR1,
                                                  result.qualityR2,
                                                  mergeForRec)
