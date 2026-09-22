import std/[algorithm, os, sets, strutils]
import docopt
import gzfast
import malebolgia
import readfx
import regex except re, match, replace, Regex
import ./filter_utils
import ./seqfu_utils

type
  SeqMode = enum
    smIupac, smLiteral, smRegex

  SeqStrand = enum
    ssForward, ssReverse, ssBoth

  SeqPattern = object
    name, value, reverse: string
    masks, reverseMasks: seq[uint8]
    expression: regex.Regex2

  SeqHit = object
    pattern, mate, start, stop, mismatches: int
    wraps: bool
    strand: SeqStrand

  SeqMatcher = object
    patterns: seq[SeqPattern]
    mode: SeqMode
    strand: SeqStrand
    minOccurrences, maxOccurrences, maxMismatches: int
    hasMax, circular, caseSensitive, allPatterns, pairBoth, invert, hits: bool

  SeqBatch = object
    first, second: seq[FQRecord]
    selected: seq[bool]
    hits: seq[seq[SeqHit]]
    paired: bool
    source1, source2: string

  SeqHitWriter = object
    plain: File
    compressed: GzFastWriter
    gzip: bool

  SeqRunState = object
    output1, output2: FastxWriter
    hitWriter: SeqHitWriter
    plan: FilterOutputPlan
    matcher: SeqMatcher
    batches: seq[SeqBatch]
    current: SeqBatch
    threads, batchSize: int
    processed, selected: int64

proc seqParseInt(value, option: string): int =
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(ValueError, option & " requires an integer: " & value)

proc seqMask(base: char): uint8 {.inline.} =
  case base.toUpperAscii()
  of 'A': 1
  of 'C': 2
  of 'G': 4
  of 'T': 8
  of 'R': 5
  of 'Y': 10
  of 'S': 6
  of 'W': 9
  of 'K': 12
  of 'M': 3
  of 'B': 14
  of 'D': 13
  of 'H': 11
  of 'V': 7
  of 'N': 15
  else: 0

proc seqComplement(base: char): char {.inline.} =
  let upper = case base.toUpperAscii()
    of 'A': 'T'
    of 'C': 'G'
    of 'G': 'C'
    of 'T': 'A'
    of 'R': 'Y'
    of 'Y': 'R'
    of 'S': 'S'
    of 'W': 'W'
    of 'K': 'M'
    of 'M': 'K'
    of 'B': 'V'
    of 'D': 'H'
    of 'H': 'D'
    of 'V': 'B'
    of 'N': 'N'
    else: base
  if base.isLowerAscii(): upper.toLowerAscii() else: upper

proc seqPreparePattern(name, value: string, matcher: SeqMatcher): SeqPattern =
  if value.len == 0:
    raise newException(ValueError, "Empty sequence pattern: " & name)
  result.name = name
  result.value = value
  if matcher.mode == smRegex:
    result.expression = regex.re2((if matcher.caseSensitive: "" else: "(?i)") & value)
    return
  if matcher.mode == smIupac:
    result.masks = newSeq[uint8](value.len)
    for i, base in value:
      result.masks[i] = seqMask(base)
      if result.masks[i] == 0:
        raise newException(ValueError, "Invalid IUPAC DNA pattern: " & value)
  if matcher.strand != ssForward:
    result.reverse = newString(value.len)
    for i, base in value:
      if matcher.mode == smLiteral and base.toUpperAscii() notin {'A', 'C', 'G', 'T'}:
        raise newException(ValueError, "Reverse-strand literal patterns require A/C/G/T")
      result.reverse[value.len - i - 1] = seqComplement(base)
    if matcher.mode == smIupac:
      result.reverseMasks = newSeq[uint8](value.len)
      for i, base in result.reverse:
        result.reverseMasks[i] = seqMask(base)

proc seqMismatchCount(sequence: string, start: int, pattern: SeqPattern,
                      matcher: SeqMatcher, reverse: bool): int {.inline.} =
  let query = if reverse: pattern.reverse else: pattern.value
  let masks = if reverse: pattern.reverseMasks else: pattern.masks
  let length = sequence.len
  for j in 0 ..< query.len:
    var position = start + j
    if position >= length:
      position -= length
    let observed = sequence[position]
    if matcher.mode == smIupac:
      let base = seqMask(observed)
      if base notin [1'u8, 2'u8, 4'u8, 8'u8]:
        return matcher.maxMismatches + 1
      if (base and masks[j]) == 0 or
          (matcher.caseSensitive and observed.isLowerAscii() != query[j].isLowerAscii()):
        inc result
    elif matcher.caseSensitive:
      if observed != query[j]:
        inc result
    elif observed.toUpperAscii() != query[j].toUpperAscii():
      inc result
    if result > matcher.maxMismatches:
      return

proc seqMatchesBound(count: int, matcher: SeqMatcher): bool {.inline.} =
  count >= matcher.minOccurrences and
    (not matcher.hasMax or count <= matcher.maxOccurrences)

proc seqFindSites(sequence: string, pattern: SeqPattern, patternIndex,
                  mate: int, matcher: SeqMatcher, hits: var seq[SeqHit]): bool =
  if not matcher.hits and matcher.minOccurrences == 0 and not matcher.hasMax:
    return true
  var count = 0
  if matcher.mode == smRegex:
    var start = 0
    var found: regex.RegexMatch2
    while start <= sequence.len and
        regex.find(sequence, pattern.expression, found, start):
      let bounds = found.boundaries
      if bounds.a <= bounds.b:
        inc count
        if matcher.hits:
          hits.add(SeqHit(pattern: patternIndex, mate: mate,
                          start: bounds.a, stop: bounds.b + 1,
                          strand: ssForward))
        if not matcher.hits and matcher.hasMax and count > matcher.maxOccurrences:
          return false
        if not matcher.hits and not matcher.hasMax and count >= matcher.minOccurrences:
          return true
      start = bounds.a + 1
  elif sequence.len >= pattern.value.len and sequence.len > 0:
    let maxStart = if matcher.circular: sequence.len - 1
                   else: sequence.len - pattern.value.len
    for start in 0 .. maxStart:
      var forward = matcher.maxMismatches + 1
      var reverse = matcher.maxMismatches + 1
      if matcher.strand != ssReverse:
        forward = seqMismatchCount(sequence, start, pattern, matcher, false)
      if matcher.strand != ssForward:
        reverse = seqMismatchCount(sequence, start, pattern, matcher, true)
      if forward <= matcher.maxMismatches or reverse <= matcher.maxMismatches:
        inc count
        if matcher.hits:
          let wraps = start + pattern.value.len > sequence.len
          hits.add(SeqHit(pattern: patternIndex, mate: mate, start: start,
                          stop: if wraps: start + pattern.value.len - sequence.len
                                else: start + pattern.value.len,
                          mismatches: min(forward, reverse), wraps: wraps,
                          strand: if forward <= matcher.maxMismatches and
                                     reverse <= matcher.maxMismatches: ssBoth
                                  elif forward <= matcher.maxMismatches: ssForward
                                  else: ssReverse))
        if not matcher.hits and matcher.hasMax and count > matcher.maxOccurrences:
          return false
        if not matcher.hits and not matcher.hasMax and count >= matcher.minOccurrences:
          return true
  result = seqMatchesBound(count, matcher)

proc seqSelect(first, second: string, paired: bool, matcher: SeqMatcher,
               hits: var seq[SeqHit]): bool =
  var passed = matcher.allPatterns
  for index, pattern in matcher.patterns:
    let firstPass = seqFindSites(first, pattern, index, 1, matcher, hits)
    var patternPass = firstPass
    if paired:
      if matcher.hits or (matcher.pairBoth and firstPass) or
          (not matcher.pairBoth and not firstPass):
        let secondPass = seqFindSites(second, pattern, index, 2, matcher, hits)
        patternPass = if matcher.pairBoth: firstPass and secondPass
                      else: firstPass or secondPass
    if matcher.allPatterns:
      passed = passed and patternPass
      if not passed and not matcher.hits:
        break
    else:
      passed = passed or patternPass
      if passed and not matcher.hits:
        break
  if matcher.invert: not passed else: passed

proc seqProcessBatch(batch: ptr SeqBatch, matcher: ptr SeqMatcher) =
  batch.selected = newSeq[bool](batch.first.len)
  if matcher.hits:
    batch.hits = newSeq[seq[SeqHit]](batch.first.len)
  for i in 0 ..< batch.first.len:
    var hits: seq[SeqHit]
    let second = if batch.paired: batch.second[i].sequence else: ""
    batch.selected[i] = seqSelect(batch.first[i].sequence, second,
                                  batch.paired, matcher[], hits)
    if matcher.hits:
      batch.hits[i] = move(hits)

proc seqOpenHitWriter(path: string, level: int): SeqHitWriter =
  result.gzip = path.toLowerAscii().endsWith(".gz")
  if result.gzip:
    var config = defaultGzFastWriteConfig()
    config.level = level
    result.compressed = openGzFastWriter(path, config)
  elif not open(result.plain, path, fmWrite):
    raise newException(IOError, "Cannot open hit report: " & path)

proc seqWriteHitLine(writer: var SeqHitWriter, line: string) =
  if writer.gzip:
    gzfast.writeLine(writer.compressed, line)
  else:
    writer.plain.writeLine(line)

proc seqCloseHitWriter(writer: var SeqHitWriter) =
  if writer.gzip:
    if writer.compressed != nil:
      gzfast.close(writer.compressed)
  elif writer.plain != nil:
    writer.plain.close()

proc seqWriteHits(state: var SeqRunState, batch: SeqBatch, index: int) =
  let ordered = sorted(batch.hits[index], proc(a, b: SeqHit): int =
    result = cmp(a.mate, b.mate)
    if result == 0: result = cmp(a.pattern, b.pattern)
    if result == 0: result = cmp(a.start, b.start))
  for hit in ordered:
    let record = if hit.mate == 1: batch.first[index] else: batch.second[index]
    let source = if hit.mate == 1: batch.source1 else: batch.source2
    let strand = case hit.strand
      of ssForward: "+"
      of ssReverse: "-"
      of ssBoth: "both"
    state.hitWriter.seqWriteHitLine(source & "\t" & record.name & "\t" &
      $hit.mate & "\t" & state.matcher.patterns[hit.pattern].name & "\t" &
      strand & "\t" & $hit.start & "\t" & $hit.stop & "\t" &
      $hit.mismatches & "\t" & $hit.wraps)

proc seqFlush(state: var SeqRunState) =
  if state.batches.len == 0:
    return
  if state.threads > 1 and state.batches.len > 1:
    var master = createMaster()
    master.awaitAll:
      for i in 0 ..< state.batches.len:
        master.spawn seqProcessBatch(addr state.batches[i], addr state.matcher)
  else:
    for i in 0 ..< state.batches.len:
      seqProcessBatch(addr state.batches[i], addr state.matcher)

  for batch in state.batches:
    for i in 0 ..< batch.first.len:
      inc state.processed
      if batch.selected[i]:
        inc state.selected
        state.output1.writeFilterRecord(batch.first[i])
        if batch.paired:
          if state.plan.splitPairs:
            state.output2.writeFilterRecord(batch.second[i])
          else:
            state.output1.writeFilterRecord(batch.second[i])
        if state.matcher.hits:
          state.seqWriteHits(batch, i)
  state.batches.setLen(0)

proc seqConsume(state: var SeqRunState, first, second: FQRecordPtr,
                paired: bool) =
  if paired and (first.qualityLen == 0 or second.qualityLen == 0):
    raise newException(ValueError, "Paired input must contain FASTQ records")
  if state.threads == 1:
    inc state.processed
    var hits: seq[SeqHit]
    let firstSequence = filterPtrString(first.sequence, first.sequenceLen)
    let secondSequence = if paired: filterPtrString(second.sequence, second.sequenceLen)
                         else: ""
    if seqSelect(firstSequence, secondSequence, paired, state.matcher, hits):
      inc state.selected
      state.output1.writeFilterRecord(first)
      if paired:
        if state.plan.splitPairs:
          state.output2.writeFilterRecord(second)
        else:
          state.output1.writeFilterRecord(second)
      if state.matcher.hits:
        var batch = SeqBatch(first: @[copyFilterRecord(first)],
                             source1: state.current.source1,
                             source2: state.current.source2,
                             hits: @[hits])
        if paired:
          batch.second.add(copyFilterRecord(second))
        state.seqWriteHits(batch, 0)
    return

  state.current.first.add(copyFilterRecord(first))
  if paired:
    state.current.second.add(copyFilterRecord(second))
  if state.current.first.len >= state.batchSize:
    state.batches.add(state.current)
    state.current = SeqBatch(paired: paired, source1: state.current.source1,
                             source2: state.current.source2)
    if state.batches.len >= state.threads:
      state.seqFlush()

proc seqFinish(state: var SeqRunState) =
  if state.current.first.len > 0:
    state.batches.add(state.current)
    state.current = SeqBatch(paired: state.current.paired,
                             source1: state.current.source1,
                             source2: state.current.source2)
  state.seqFlush()

proc seqLoadPatterns(path: string): seq[(string, string)] =
  if not fileExists(path):
    raise newException(IOError, "Pattern file not found: " & path)
  for line in lines(path):
    let entry = line.strip()
    if entry.len == 0 or entry[0] == '#':
      continue
    let tab = entry.find('\t')
    if tab >= 0:
      let name = entry[0 ..< tab].strip()
      let value = entry[tab + 1 .. ^1].strip()
      if name.len == 0 or value.len == 0:
        raise newException(ValueError, "Pattern file expects name<TAB>pattern: " & path)
      result.add((name, value))
    else:
      result.add(("", entry))

proc seqSamePath(first, second: string): bool =
  if first.len == 0 or second.len == 0 or first == "-" or second == "-":
    return false
  absolutePath(first) == absolutePath(second) or
    (fileExists(first) and fileExists(second) and sameFile(first, second))

proc filter_byseq(argv: var seq[string]): int =
  let doc = """
Usage:
  by-seq [options] [-e PATTERN]... [<item>...]

Select FASTA/FASTQ records by sequence. Without -e/-f, the first positional
item is the pattern; remaining items are input files. Default: IUPAC DNA,
forward strand, at least one site per pattern and mate.

Patterns:
  -e, --pattern PATTERN       Add a pattern; may be repeated
  -f, --patterns-file FILE    Read patterns or name<TAB>pattern lines
  --logic MODE               Combine patterns: any|all [default: any]
  --regex                    Use pure-Nim regular expressions
  --literal                  Use literal strings instead of IUPAC DNA
  --case-sensitive           Match letter case

Biological matching:
  --strand MODE              Search forward|reverse|both [default: forward]
  -m, --max-mismatches INT   Maximum substitutions per site (default: 0)
  --circular                 Allow matches across the sequence origin
  --occurrences INT          Require exactly INT sites per pattern and mate
  --min-occurrences INT      Minimum sites per pattern and mate
  --max-occurrences INT      Maximum sites per pattern and mate
  -v, --invert-match         Invert final selection

Input:
  <item>...                  Pattern then files, or files with -e/-f
  -1, --r1 FILE             Paired-end R1 FASTQ
  -2, --r2 FILE             Paired-end R2 FASTQ
  --interleaved             Treat one input as interleaved FASTQ

Paired selection:
  --pair-mode MODE           Match each pattern in any|both mates [default: any]

Output:
  -o, --output FILE          Write to FILE (gzip if .gz)
  -O, --output-r2 FILE       Write selected R2 reads to FILE
  --interleaved-output       Keep paired output interleaved
  --hits FILE                Write sites for selected records as TSV
  --gzip-level INT           Gzip compression level [default: 6]

Performance:
  -t, --threads INT          Worker threads [default: 1]
  --batch-size INT           Records or pairs per batch [default: 4096]

Other:
  --stats                    Print processed and selected counts to stderr
  --verbose                  Print input and output routing to stderr
  -h, --help                 Show this help
"""
  let args = docopt(doc, argv = argv, version = version())
  try:
    var matcher = SeqMatcher()
    let logic = $args["--logic"]
    if logic notin ["any", "all"]:
      raise newException(ValueError, "--logic must be any or all")
    matcher.allPatterns = logic == "all"
    let pairMode = $args["--pair-mode"]
    if pairMode notin ["any", "both"]:
      raise newException(ValueError, "--pair-mode must be any or both")
    matcher.pairBoth = pairMode == "both"
    matcher.invert = bool(args["--invert-match"])
    matcher.circular = bool(args["--circular"])
    matcher.caseSensitive = bool(args["--case-sensitive"])
    if bool(args["--regex"]) and bool(args["--literal"]):
      raise newException(ValueError, "--regex and --literal are mutually exclusive")
    matcher.mode = if bool(args["--regex"]): smRegex
                   elif bool(args["--literal"]): smLiteral
                   else: smIupac
    let strand = $args["--strand"]
    case strand
    of "forward": matcher.strand = ssForward
    of "reverse": matcher.strand = ssReverse
    of "both": matcher.strand = ssBoth
    else: raise newException(ValueError, "--strand must be forward, reverse, or both")
    let mismatchText = $args["--max-mismatches"]
    matcher.maxMismatches = if mismatchText == "nil": 0
                            else: seqParseInt(mismatchText, "--max-mismatches")
    if matcher.maxMismatches < 0:
      raise newException(ValueError, "--max-mismatches must be nonnegative")
    if matcher.mode == smRegex and
        (mismatchText != "nil" or matcher.circular or matcher.strand != ssForward):
      raise newException(ValueError, "Regex mode is forward-only, linear, and exact")

    let exactText = $args["--occurrences"]
    let minText = $args["--min-occurrences"]
    let maxText = $args["--max-occurrences"]
    if exactText != "nil" and (minText != "nil" or maxText != "nil"):
      raise newException(ValueError, "--occurrences cannot be combined with min/max bounds")
    matcher.minOccurrences = if exactText != "nil": seqParseInt(exactText, "--occurrences")
                             elif minText != "nil": seqParseInt(minText, "--min-occurrences")
                             else: 1
    if exactText != "nil" or maxText != "nil":
      matcher.hasMax = true
      matcher.maxOccurrences = if exactText != "nil": matcher.minOccurrences
                               else: seqParseInt(maxText, "--max-occurrences")
    if matcher.minOccurrences < 0 or
        (matcher.hasMax and (matcher.maxOccurrences < 0 or
                             matcher.minOccurrences > matcher.maxOccurrences)):
      raise newException(ValueError, "Occurrence bounds must be nonnegative and min <= max")

    let threads = seqParseInt($args["--threads"], "--threads")
    let batchSize = seqParseInt($args["--batch-size"], "--batch-size")
    let gzipLevel = seqParseInt($args["--gzip-level"], "--gzip-level")
    if threads < 1 or threads > ThreadPoolSize:
      raise newException(ValueError, "--threads must be between 1 and " & $ThreadPoolSize)
    if batchSize < 1:
      raise newException(ValueError, "--batch-size must be positive")
    if gzipLevel < 0 or gzipLevel > 9:
      raise newException(ValueError, "--gzip-level must be between 0 and 9")

    var rawPatterns: seq[(string, string)]
    for value in args["--pattern"]:
      rawPatterns.add(("", $value))
    let patternsFile = $args["--patterns-file"]
    if patternsFile != "nil":
      rawPatterns.add(seqLoadPatterns(patternsFile))
    var items: seq[string]
    for item in args["<item>"]:
      items.add($item)
    if rawPatterns.len == 0 and items.len > 0:
      rawPatterns.add(("", items[0]))
      items.delete(0)
    if rawPatterns.len == 0:
      raise newException(ValueError, "At least one sequence pattern is required")
    if items.len == 0:
      items.add("-")
    var names = initHashSet[string]()
    for i, entry in rawPatterns:
      let name = if entry[0].len > 0: entry[0] else: "pattern_" & $(i + 1)
      if name in names:
        raise newException(ValueError, "Duplicate pattern name: " & name)
      names.incl(name)
      if matcher.mode != smRegex and matcher.maxMismatches > entry[1].len:
        raise newException(ValueError, "--max-mismatches exceeds pattern length: " & name)
      matcher.patterns.add(seqPreparePattern(name, entry[1], matcher))

    let r1 = $args["--r1"]
    let r2 = $args["--r2"]
    let twoFiles = r1 != "nil" or r2 != "nil"
    let interleaved = bool(args["--interleaved"])
    if twoFiles and (r1 == "nil" or r2 == "nil" or interleaved):
      raise newException(ValueError, "-1 and -2 are required together, without --interleaved")
    if twoFiles and (items.len != 1 or items[0] != "-"):
      raise newException(ValueError, "Paired input cannot be combined with positional input files")
    if twoFiles and r1 == r2:
      raise newException(ValueError, "-1 and -2 must name different streams")
    if interleaved and items.len != 1:
      raise newException(ValueError, "--interleaved requires exactly one input stream")
    let inputs = if twoFiles: @[r1, r2] else: items
    for path in inputs:
      if path != "-" and not fileExists(path):
        raise newException(IOError, "Input file not found: " & path)

    let outputArg = $args["--output"]
    let outputR2Arg = $args["--output-r2"]
    let outputPath = if outputArg == "nil": "" else: outputArg
    let outputR2 = if outputR2Arg == "nil": "" else: outputR2Arg
    let paired = twoFiles or interleaved
    if not paired and bool(args["--interleaved-output"]):
      raise newException(ValueError, "--interleaved-output requires paired input")
    let plan = filterOutputPlan(paired, outputPath, outputR2,
                                bool(args["--interleaved-output"]))
    var protectedInputs = inputs
    if patternsFile != "nil":
      protectedInputs.add(patternsFile)
    validateFilterOutputs(plan, protectedInputs)
    if seqSamePath(plan.first, plan.second):
      raise newException(ValueError, "R1 and R2 output paths must differ")

    let hitsArg = $args["--hits"]
    let hitPath = if hitsArg == "nil": "" else: hitsArg
    matcher.hits = hitPath.len > 0
    if matcher.hits:
      if hitPath == "-":
        raise newException(ValueError, "--hits requires a file path")
      validateFilterOutputs(FilterOutputPlan(first: hitPath), protectedInputs)
      if seqSamePath(hitPath, plan.first) or seqSamePath(hitPath, plan.second):
        raise newException(ValueError, "Hit report path must differ from sequence outputs")

    var state = SeqRunState(plan: plan, matcher: matcher, threads: threads,
                            batchSize: batchSize,
                            current: SeqBatch(paired: paired))
    state.output1 = openFilterWriter(plan.first, fxfFastq, gzipLevel)
    try:
      if plan.splitPairs:
        state.output2 = openFilterWriter(plan.second, fxfFastq, gzipLevel)
      if matcher.hits:
        state.hitWriter = seqOpenHitWriter(hitPath, gzipLevel)
        state.hitWriter.seqWriteHitLine(
          "input\trecord\tmate\tpattern\tstrand\tstart\tend\tmismatches\twraps")
    except CatchableError:
      state.output1.close()
      if plan.splitPairs:
        state.output2.close()
      if matcher.hits:
        state.hitWriter.seqCloseHitWriter()
      raise
    defer:
      state.output1.close()
      if plan.splitPairs:
        state.output2.close()
      if matcher.hits:
        state.hitWriter.seqCloseHitWriter()

    if args["--verbose"]:
      stderr.writeLine("[by-seq] input: ", inputs.join(", "))
      stderr.writeLine("[by-seq] output: ", if plan.first.len == 0: "stdout" else: plan.first,
                       if plan.splitPairs: ", " & plan.second
                       elif paired: " (interleaved)"
                       else: "")

    if twoFiles:
      state.current.source1 = r1
      state.current.source2 = r2
      for pair in readFQPairPtr(r1, r2):
        state.seqConsume(pair.read1, pair.read2, true)
    elif interleaved:
      state.current.source1 = items[0]
      state.current.source2 = items[0]
      for pair in readFQInterleavedPairPtr(items[0]):
        state.seqConsume(pair.read1, pair.read2, true)
    else:
      for path in items:
        state.current.source1 = path
        state.current.source2 = ""
        for record in readFQPtr(path):
          state.seqConsume(record, FQRecordPtr(), false)
        state.seqFinish()
    state.seqFinish()
    if args["--stats"]:
      stderr.writeLine("[by-seq] processed: ", state.processed,
                       if paired: " pairs; selected: " else: " reads; selected: ",
                       state.selected)
    return 0
  except CatchableError as error:
    stderr.writeLine("ERROR: by-seq: ", error.msg)
    return 1
