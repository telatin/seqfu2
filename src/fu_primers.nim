import docopt
import readfq as rf
import iterutils
import os, strutils
import malebolgia
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programName = "fu-primers"
const programVersion = if NimblePkgVersion == "undef": "X.9"
                       else: NimblePkgVersion

type
  trimmingResults = object
    input,     output,     trimmed: int

type
  primerOptions = object
    primers: seq[string]
    primerLens: seq[int]
    margin: int
    minMatches, maxMismatches: int
    matchThs: float

type
  primerWorkerOptions = object
    opts: primerOptions
    minLen: int
    paired: bool

type
  primerJob = object
    records: seq[rf.FQRecord]
    output: string
    stats: trimmingResults

proc version(): string =
  return programName  & " " & programVersion

proc appendTrimmedRecord(buffer: var string, read: rf.FQRecord) =
  if read.quality.len > 0:
    buffer.add('@')
  else:
    buffer.add('>')
  buffer.add(read.name)
  if read.comment.len > 0:
    buffer.add(' ')
    buffer.add(read.comment)
  buffer.add('\n')
  buffer.add(read.sequence)
  buffer.add('\n')
  if read.quality.len > 0:
    buffer.add("+\n")
    buffer.add(read.quality)
    buffer.add('\n')

proc applyPrimerMatch(
    matchPos, primerLen, seqLen, margin: int,
    trimFrom: var int,
    trimEnd: var int
  ): bool =
  ## Returns true if the match is internal and the read must be discarded.
  if (matchPos > margin) and (matchPos + primerLen < seqLen - margin):
    return true
  if matchPos <= margin:
    let candidate = matchPos + primerLen
    if trimFrom < candidate:
      trimFrom = candidate
  elif matchPos + primerLen >= seqLen - margin:
    if trimEnd > matchPos:
      trimEnd = matchPos
  return false

proc processRead(read: rf.FQRecord, opts: primerOptions): rf.FQRecord =
  result.name = read.name
  result.comment = read.comment

  let
    slen = read.sequence.len
  var
    trimFrom = 0
    trimEnd = slen

  for i, primer in opts.primers:
    let
      plen = opts.primerLens[i]
      primerMatches = findPrimerMatches(read.sequence, primer, opts.matchThs, opts.maxMismatches, opts.minMatches)

    for m in primerMatches[0]:
      if applyPrimerMatch(m, plen, slen, opts.margin, trimFrom, trimEnd):
        result.sequence = ""
        result.quality = ""
        return
    for m in primerMatches[1]:
      if applyPrimerMatch(m, plen, slen, opts.margin, trimFrom, trimEnd):
        result.sequence = ""
        result.quality = ""
        return

  if trimEnd <= trimFrom or trimEnd - trimFrom < 2:
    result.sequence = ""
    result.quality = ""
    return

  result.sequence = read.sequence[trimFrom ..< trimEnd]

  if read.quality.len > 0:
    result.quality = read.quality[trimFrom ..< trimEnd]

proc processSequencePairsArray(pool: seq[rf.FQRecord], opts: primerOptions, minlen: int): (trimmingResults, string) =
  result[0].input = pool.len
  var
    i = 0
  while i + 1 < pool.len:
    let
      trim1 = processRead(pool[i], opts)
      trim2 = processRead(pool[i + 1], opts)

    if trim1.sequence.len >= minlen and trim2.sequence.len >= minlen:
      result[0].output += 2
      if trim1.sequence.len < pool[i].sequence.len:
        result[0].trimmed += 1
      if trim2.sequence.len < pool[i + 1].sequence.len:
        result[0].trimmed += 1
      appendTrimmedRecord(result[1], trim1)
      appendTrimmedRecord(result[1], trim2)
    i += 2

proc processSequenceSingleArray(pool: seq[rf.FQRecord], opts: primerOptions, minlen: int): (trimmingResults, string) =
  result[0].input = pool.len
  for record in pool:
    let trimmed = processRead(record, opts)
    if trimmed.sequence.len >= minlen:
      result[0].output += 1
      if trimmed.sequence.len < record.sequence.len:
        result[0].trimmed += 1
      appendTrimmedRecord(result[1], trimmed)

proc processPrimerJob(job: ptr primerJob, workerOpts: ptr primerWorkerOptions) {.gcsafe.} =
  if workerOpts[].paired:
    let batchResult = processSequencePairsArray(job[].records, workerOpts[].opts, workerOpts[].minLen)
    job[].stats = batchResult[0]
    job[].output = batchResult[1]
  else:
    let batchResult = processSequenceSingleArray(job[].records, workerOpts[].opts, workerOpts[].minLen)
    job[].stats = batchResult[0]
    job[].output = batchResult[1]

proc inferSecondPairFilename(
    fileR1: string,
    patternR1: string,
    patternR2: string,
    fileR2: var string
  ): bool =
  if patternR1 == "auto" and patternR2 == "auto":
    if "_R1_" in fileR1:
      fileR2 = fileR1.replace("_R1_", "_R2_")
      return true
    if "_R1." in fileR1:
      fileR2 = fileR1.replace("_R1.", "_R2.")
      return true
    if "_1." in fileR1:
      fileR2 = fileR1.replace("_1.", "_2.")
      return true
    if "_1_" in fileR1:
      fileR2 = fileR1.replace("_1_", "_2_")
      return true
    return false

  if fileR1.contains(patternR1):
    fileR2 = fileR1.replace(patternR1, patternR2)
    return true
  return false

proc main(args: var seq[string]): int =
  let args = docopt("""
  Usage: fu-primers [options] -1 <FOR> [-2 <REV>]

  Options:
    -1 --first-pair <FOR>     First sequence in pair
    -2 --second-pair <REV>    Second sequence in pair (can be guessed)
    -f --primer-for FOR       Sequence of the forward primer [default: CCTACGGGNGGCWGCAG]
    -r --primer-rev REV       Sequence of the reverse primer [default: GGACTACHVGGGTATCTAATCC]
    -m --min-len INT          Minimum sequence length after trimming [default: 50]
    --primer-thrs FLOAT       Minimum amount of matches over total length [default: 0.8]
    --primer-mismatches INT   Maximum number of mismatches allowed [default: 2]
    --primer-min-matches INT  Minimum number of matches required [default: 8]
    --primer-pos-margin INT   Number of bases from the extremity of the sequence allowed [default: 2]
    -t --threads INT          Number of worker threads [default: $1]
    -p --pool-size INT        Number of reads per worker batch [default: 100]
    --pattern-R1 <tag-1>      Tag in first pairs filenames [default: auto]
    --pattern-R2 <tag-2>      Tag in second pairs filenames [default: auto]
    -v --verbose              Verbose output
    -h --help                 Show this help
    """.multiReplace(("$1", $ThreadPoolSize)), version=version(), argv=args)

  var
    file_R2: string
    file_R1 = $args["--first-pair"]
    inputIsPaired = true

  if file_R1 == "nil" or file_R1.len == 0:
    stderr.writeLine("ERROR: Missing required parameter -1 (--first-pair)")
    return 1
  if not fileExists(file_R1):
    stderr.writeLine("ERROR: File R1 not found: ", file_R1)
    return 1

  let
    p1for = $args["--primer-for"]
    p2for = $args["--primer-rev"]
    p1rev = p1for.revcompl()
    p2rev = p2for.revcompl()
    verbose = bool(args["--verbose"])

  var
    minLen, margin, minMatches, maxMismatches, threads, poolSize: int
    matchThs: float
  try:
    minLen = parseInt($args["--min-len"])
    margin = parseInt($args["--primer-pos-margin"])
    minMatches = parseInt($args["--primer-min-matches"])
    maxMismatches = parseInt($args["--primer-mismatches"])
    threads = parseInt($args["--threads"])
    poolSize = parseInt($args["--pool-size"])
    matchThs = parseFloat($args["--primer-thrs"])
  except ValueError:
    stderr.writeLine("ERROR: invalid numeric argument. Check --help for accepted values.")
    return 1

  if minLen < 0:
    stderr.writeLine("ERROR: --min-len must be >= 0")
    return 1
  if margin < 0:
    stderr.writeLine("ERROR: --primer-pos-margin must be >= 0")
    return 1
  if minMatches < 1:
    stderr.writeLine("ERROR: --primer-min-matches must be >= 1")
    return 1
  if maxMismatches < 0:
    stderr.writeLine("ERROR: --primer-mismatches must be >= 0")
    return 1
  if matchThs <= 0.0 or matchThs > 1.0:
    stderr.writeLine("ERROR: --primer-thrs must be in (0, 1]")
    return 1
  if threads < 1:
    stderr.writeLine("ERROR: --threads must be >= 1")
    return 1
  if poolSize < 1:
    stderr.writeLine("ERROR: --pool-size must be >= 1")
    return 1

  # Try inferring second filename
  if args["--second-pair"]:
    file_R2 = $args["--second-pair"]
    if not fileExists(file_R2):
      stderr.writeLine("ERROR: File R2 not found: ", file_R2)
      return 1
    inputIsPaired = true
  elif inferSecondPairFilename(file_R1, $args["--pattern-R1"], $args["--pattern-R2"], file_R2):
    if fileExists(file_R2):
      inputIsPaired = true
    else:
      if verbose:
        stderr.writeLine("INFO: Mate file inferred but not found (<", file_R2, ">), processing as single-end.")
      inputIsPaired = false
  else:
    if verbose:
      stderr.writeLine("INFO: Processing as single-end (R2 not inferred from filename).")
    inputIsPaired = false

  if verbose:
    stderr.writeLine("# Primer Forward: ", p1for, ":", p1rev)
    stderr.writeLine("# Primer Reverse: ", p2for, ":", p2rev)
    stderr.writeLine("# Mode: ", if inputIsPaired: "Paired-end" else: "Single-end")
    stderr.writeLine("# Threads: ", threads, "; Batch size: ", poolSize)
    if inputIsPaired:
      stderr.writeLine("# R1: ", file_R1)
      stderr.writeLine("# R2: ", file_R2)
    else:
      stderr.writeLine("# Input: ", file_R1)

  let primerLens = @[p1for.len, p2for.len]
  let
    programParameters = primerOptions(
      primers: @[p1for, p2for],
      primerLens: primerLens,
      margin: margin,
      minMatches: minMatches,
      maxMismatches: maxMismatches,
      matchThs: matchThs
    )
  let
    workerParameters = primerWorkerOptions(
      opts: programParameters,
      minLen: minLen,
      paired: inputIsPaired
    )

  var
    processed = 0
    kept = 0
    trimmed = 0
    jobs = newSeqOfCap[primerJob](max(1, min(threads, ThreadPoolSize)))
    readPoolCap = if inputIsPaired: poolSize * 2 else: poolSize
    readPool = newSeqOfCap[rf.FQRecord](readPoolCap)
    canParallel = threads > 1
    parallelChunk = max(1, min(threads, ThreadPoolSize))

  proc flushJobs() =
    if jobs.len == 0:
      return

    if canParallel and jobs.len > 1:
      var m = createMaster()
      m.awaitAll:
        for i in 0 ..< jobs.len:
          m.spawn processPrimerJob(addr jobs[i], unsafeAddr workerParameters)
    else:
      for i in 0 ..< jobs.len:
        processPrimerJob(addr jobs[i], unsafeAddr workerParameters)

    for job in jobs:
      if job.output.len > 0:
        stdout.write(job.output)
      processed += job.stats.input
      kept += job.stats.output
      trimmed += job.stats.trimmed

    jobs.setLen(0)

  proc enqueuePool() =
    if readPool.len == 0:
      return
    jobs.add(primerJob(records: readPool))
    readPool = newSeqOfCap[rf.FQRecord](readPoolCap)
    if jobs.len >= parallelChunk:
      flushJobs()

  try:
    if inputIsPaired:
      initClosure(getR1, rf.readFQ(file_R1))
      initClosure(getR2, rf.readFQ(file_R2))
      for (r1, r2) in zip(getR1, getR2):
        readPool.add(r1)
        readPool.add(r2)
        if readPool.len >= readPoolCap:
          enqueuePool()
    else:
      for r1 in rf.readFQ(file_R1):
        readPool.add(r1)
        if readPool.len >= readPoolCap:
          enqueuePool()
  except Exception as e:
    stderr.writeLine("ERROR: unable to read input FASTQ: ", e.msg)
    return 1

  enqueuePool()
  flushJobs()

  let discarded = processed - kept
  if verbose:
    stderr.writeLine("Seqs: ", processed, "; Trimmed: ", trimmed, "; Discarded: ", discarded)
  return 0

when isMainModule:
  main_helper(main)
