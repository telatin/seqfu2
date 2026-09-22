import std/[os, sets, strutils, tables]
import docopt
import malebolgia
import readfx
import regex except re, match, replace, Regex
import ./filter_utils
import ./seqfu_utils

type
  IdMissingMode = enum
    immDrop, immKeep, immError

  IdMatcher = object
    patterns: seq[string]
    regexes: seq[regex.Regex2]
    exactPatterns: HashSet[string]
    numberRegex: regex.Regex2
    hasNumberRegex: bool
    fixed, exact, ignoreCase, stripPair, allPatterns: bool
    numeric, hasLower, hasUpper, lowerInclusive, upperInclusive: bool
    lower, upper: int64
    missingMode: IdMissingMode

  IdBatch = object
    first, second: seq[FQRecord]
    selected: seq[bool]
    error: string
    paired: bool

  IdRunState = object
    output1, output2: FastxWriter
    plan: FilterOutputPlan
    matcher: IdMatcher
    batches: seq[IdBatch]
    current: IdBatch
    threads, batchSize: int
    pairBoth, invert: bool
    processed, selected: int64

proc idParseInt(value, option: string): int64 =
  try:
    result = parseBiggestInt(value)
  except ValueError:
    raise newException(ValueError, option & " requires a signed 64-bit integer: " & value)

proc idNormalize(name: string, matcher: IdMatcher): string =
  result = name
  if matcher.stripPair and result.len >= 2 and result[^2] == '/' and
      result[^1] in {'1', '2'}:
    result.setLen(result.len - 2)
  if matcher.ignoreCase and matcher.fixed:
    result = result.toLowerAscii()

proc idMissingNumber(matcher: IdMatcher, name: string): bool =
  case matcher.missingMode
  of immDrop: false
  of immKeep: true
  of immError:
    raise newException(ValueError, "Missing or invalid numeric component in ID: " & name)

proc idNumberMatches(name: string, matcher: IdMatcher): bool =
  var digits = ""
  if matcher.hasNumberRegex:
    var found: regex.RegexMatch2
    if not regex.find(name, matcher.numberRegex, found):
      return matcher.idMissingNumber(name)
    let bounds = found.group(0)
    if bounds.a > bounds.b:
      return matcher.idMissingNumber(name)
    digits = name[bounds]
  else:
    var start = name.len
    while start > 0 and name[start - 1] in {'0' .. '9'}:
      dec start
    if start == name.len:
      return matcher.idMissingNumber(name)
    digits = name[start .. ^1]

  var number: int64
  try:
    number = parseBiggestInt(digits)
  except ValueError:
    return matcher.idMissingNumber(name)

  if matcher.hasLower and
      (number < matcher.lower or (number == matcher.lower and not matcher.lowerInclusive)):
    return false
  if matcher.hasUpper and
      (number > matcher.upper or (number == matcher.upper and not matcher.upperInclusive)):
    return false
  true

proc idTextMatches(name: string, matcher: IdMatcher): bool =
  if matcher.patterns.len == 0:
    return true
  if matcher.fixed and matcher.exact and not matcher.allPatterns:
    return name in matcher.exactPatterns

  for i in 0 ..< matcher.patterns.len:
    let matched =
      if matcher.fixed:
        if matcher.exact: name == matcher.patterns[i]
        else: matcher.patterns[i] in name
      elif matcher.exact:
        regex.match(name, matcher.regexes[i])
      else:
        regex.contains(name, matcher.regexes[i])
    if matcher.allPatterns and not matched:
      return false
    if not matcher.allPatterns and matched:
      return true
  matcher.allPatterns

proc idMatches(name: string, matcher: IdMatcher): bool =
  let normalized = idNormalize(name, matcher)
  if not idTextMatches(normalized, matcher):
    return false
  if matcher.numeric:
    return idNumberMatches(normalized, matcher)
  true

proc idSelected(name1, name2: string, paired: bool,
                matcher: IdMatcher, pairBoth, invert: bool): bool =
  let first = idMatches(name1, matcher)
  var passed = first
  if paired:
    let second = idMatches(name2, matcher)
    if pairBoth:
      passed = first and second
    else:
      passed = first or second
  if invert: not passed else: passed

proc idProcessBatch(batch: ptr IdBatch, matcher: ptr IdMatcher,
                    pairBoth, invert: bool) =
  batch.selected = newSeq[bool](batch.first.len)
  for i in 0 ..< batch.first.len:
    try:
      let mateName = if batch.paired: batch.second[i].name else: ""
      batch.selected[i] = idSelected(batch.first[i].name, mateName,
                                     batch.paired, matcher[], pairBoth, invert)
    except ValueError as error:
      batch.error = error.msg
      return

proc idWriteRecord(writer: var FastxWriter, record: FQRecordPtr) =
  writer.format = if record.qualityLen > 0: fxfFastq else: fxfFasta
  writer.writeRecord(record)

proc idWriteRecord(writer: var FastxWriter, record: FQRecord) =
  writer.format = if record.quality.len > 0: fxfFastq else: fxfFasta
  writer.writeRecord(record)

proc idFlush(state: var IdRunState) =
  if state.batches.len == 0:
    return
  if state.threads > 1 and state.batches.len > 1:
    var master = createMaster()
    master.awaitAll:
      for i in 0 ..< state.batches.len:
        master.spawn idProcessBatch(addr state.batches[i], addr state.matcher,
                                    state.pairBoth, state.invert)
  else:
    for i in 0 ..< state.batches.len:
      idProcessBatch(addr state.batches[i], addr state.matcher,
                     state.pairBoth, state.invert)

  for batch in state.batches:
    if batch.error.len > 0:
      raise newException(ValueError, batch.error)
    for i in 0 ..< batch.first.len:
      inc state.processed
      if batch.selected[i]:
        inc state.selected
        state.output1.idWriteRecord(batch.first[i])
        if batch.paired:
          if state.plan.splitPairs:
            state.output2.idWriteRecord(batch.second[i])
          else:
            state.output1.idWriteRecord(batch.second[i])
  state.batches.setLen(0)

proc idConsume(state: var IdRunState, first: FQRecordPtr,
               second: FQRecordPtr, paired: bool) =
  if paired and (first.qualityLen == 0 or second.qualityLen == 0):
    raise newException(ValueError, "Paired input must contain FASTQ records")

  if state.threads == 1:
    inc state.processed
    let name1 = $cast[cstring](first.name)
    let name2 = if paired: $cast[cstring](second.name) else: ""
    if idSelected(name1, name2, paired, state.matcher,
                  state.pairBoth, state.invert):
      inc state.selected
      state.output1.idWriteRecord(first)
      if paired:
        if state.plan.splitPairs:
          state.output2.idWriteRecord(second)
        else:
          state.output1.idWriteRecord(second)
    return

  state.current.first.add(copyFilterRecord(first))
  if paired:
    state.current.second.add(copyFilterRecord(second))
  if state.current.first.len >= state.batchSize:
    state.batches.add(state.current)
    state.current = IdBatch(paired: paired)
    if state.batches.len >= state.threads:
      state.idFlush()

proc idFinish(state: var IdRunState) =
  if state.current.first.len > 0:
    state.batches.add(state.current)
    state.current = IdBatch()
  state.idFlush()

proc idLoadPatterns(path: string, stripMarker: bool): seq[string] =
  if not fileExists(path):
    raise newException(IOError, "Pattern file not found: " & path)
  for line in lines(path):
    var pattern = line.strip()
    if pattern.len == 0 or pattern[0] == '#':
      continue
    if stripMarker and pattern[0] in {'>', '@'}:
      pattern = pattern[1 .. ^1]
    if pattern.len > 0:
      result.add(pattern)

proc idConfigureBounds(args: Table[string, Value], matcher: var IdMatcher) =
  let rangeText = $args["--number-range"]
  let equalText = $args["--number-eq"]
  let ltText = $args["--number-lt"]
  let leText = $args["--number-le"]
  let gtText = $args["--number-gt"]
  let geText = $args["--number-ge"]
  matcher.numeric = rangeText != "nil" or equalText != "nil" or
                    ltText != "nil" or leText != "nil" or
                    gtText != "nil" or geText != "nil"

  if equalText != "nil":
    if rangeText != "nil" or ltText != "nil" or leText != "nil" or
        gtText != "nil" or geText != "nil":
      raise newException(ValueError, "--number-eq cannot be combined with other numeric bounds")
    let value = idParseInt(equalText, "--number-eq")
    matcher.hasLower = true
    matcher.hasUpper = true
    matcher.lowerInclusive = true
    matcher.upperInclusive = true
    matcher.lower = value
    matcher.upper = value
  elif rangeText != "nil":
    if ltText != "nil" or leText != "nil" or gtText != "nil" or geText != "nil":
      raise newException(ValueError, "--number-range cannot be combined with other numeric bounds")
    let parts = rangeText.split(':')
    if parts.len != 2:
      raise newException(ValueError, "--number-range expects MIN:MAX")
    matcher.lower = idParseInt(parts[0], "--number-range")
    matcher.upper = idParseInt(parts[1], "--number-range")
    matcher.hasLower = true
    matcher.hasUpper = true
    matcher.lowerInclusive = true
    matcher.upperInclusive = true
  else:
    if ltText != "nil" and leText != "nil":
      raise newException(ValueError, "Specify only one upper numeric bound")
    if gtText != "nil" and geText != "nil":
      raise newException(ValueError, "Specify only one lower numeric bound")
    if ltText != "nil" or leText != "nil":
      matcher.hasUpper = true
      matcher.upperInclusive = leText != "nil"
      matcher.upper = idParseInt(if leText != "nil": leText else: ltText,
                                 "upper numeric bound")
    if gtText != "nil" or geText != "nil":
      matcher.hasLower = true
      matcher.lowerInclusive = geText != "nil"
      matcher.lower = idParseInt(if geText != "nil": geText else: gtText,
                                 "lower numeric bound")

  if matcher.hasLower and matcher.hasUpper and
      (matcher.lower > matcher.upper or
       (matcher.lower == matcher.upper and
        (not matcher.lowerInclusive or not matcher.upperInclusive))):
    raise newException(ValueError, "Numeric bounds select an empty interval")

proc filter_byid(argv: var seq[string]): int =
  let doc = """
Usage:
  by-id [options] [-e PATTERN]... [<item>...]

Select FASTA/FASTQ records by identifier. With a positional pattern, the
remaining items are input files. Use -e for an unambiguous pattern when
combining numeric selectors or pattern files with positional inputs.

Matching:
  -e, --pattern PATTERN      Add a pattern; may be repeated
  -f, --patterns-file FILE   Read one pattern per line
  --logic MODE               Combine patterns: any|all [default: any]
  -F, --fixed-string         Treat patterns as literal strings
  -x, --exact                Match complete identifiers
  -i, --ignore-case          Case-insensitive matching
  --strip-pair               Ignore terminal /1 or /2 when matching
  --strip-marker             Ignore leading > or @ in pattern-file entries
  -v, --invert-match         Invert the final selection

Numeric suffix:
  --number-range MIN:MAX     Inclusive numeric interval
  --number-lt INT            Numeric suffix < INT
  --number-le INT            Numeric suffix <= INT
  --number-gt INT            Numeric suffix > INT
  --number-ge INT            Numeric suffix >= INT
  --number-eq INT            Numeric suffix = INT
  --number-regex REGEX       Extract number from first capture group
  --missing-number MODE      drop|keep|error [default: drop]

Input:
  <item>...                  Pattern followed by input files, or files with -e/-f/numeric
  -1, --r1 FILE             Paired-end R1 FASTQ
  -2, --r2 FILE             Paired-end R2 FASTQ
  --interleaved             Treat one input as interleaved FASTQ

Paired selection:
  --pair-mode MODE           Match either or both mates: any|both [default: any]

Output:
  -o, --output FILE          Write to FILE (gzip if .gz)
  -O, --output-r2 FILE       Write selected R2 reads to FILE
  --interleaved-output       Keep paired output interleaved even when -o implies R2
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
    var matcher = IdMatcher()
    let logic = $args["--logic"]
    if logic notin ["any", "all"]:
      raise newException(ValueError, "--logic must be any or all")
    matcher.allPatterns = logic == "all"
    matcher.fixed = bool(args["--fixed-string"])
    matcher.exact = bool(args["--exact"])
    matcher.ignoreCase = bool(args["--ignore-case"])
    matcher.stripPair = bool(args["--strip-pair"])
    idConfigureBounds(args, matcher)

    let missing = $args["--missing-number"]
    case missing
    of "drop": matcher.missingMode = immDrop
    of "keep": matcher.missingMode = immKeep
    of "error": matcher.missingMode = immError
    else: raise newException(ValueError, "--missing-number must be drop, keep, or error")

    let numberPattern = $args["--number-regex"]
    if numberPattern != "nil":
      if not matcher.numeric:
        raise newException(ValueError, "--number-regex requires a numeric bound")
      matcher.numberRegex = regex.re2(numberPattern)
      if regex.Regex(matcher.numberRegex).groupsCount < 1:
        raise newException(ValueError, "--number-regex requires a capture group")
      matcher.hasNumberRegex = true

    let pairMode = $args["--pair-mode"]
    if pairMode notin ["any", "both"]:
      raise newException(ValueError, "--pair-mode must be any or both")

    let threadsValue = idParseInt($args["--threads"], "--threads")
    let batchSizeValue = idParseInt($args["--batch-size"], "--batch-size")
    let gzipLevelValue = idParseInt($args["--gzip-level"], "--gzip-level")
    if threadsValue < 1 or threadsValue > ThreadPoolSize:
      raise newException(ValueError, "--threads must be between 1 and " & $ThreadPoolSize)
    if batchSizeValue < 1 or batchSizeValue > high(int):
      raise newException(ValueError, "--batch-size must be between 1 and " & $high(int))
    if gzipLevelValue < 0 or gzipLevelValue > 9:
      raise newException(ValueError, "--gzip-level must be between 0 and 9")
    let threads = int(threadsValue)
    let batchSize = int(batchSizeValue)
    let gzipLevel = int(gzipLevelValue)

    for pattern in args["--pattern"]:
      matcher.patterns.add($pattern)
    let patternsFile = $args["--patterns-file"]
    if patternsFile != "nil":
      matcher.patterns.add(idLoadPatterns(patternsFile, bool(args["--strip-marker"])))

    var items: seq[string]
    for item in args["<item>"]:
      items.add($item)
    let hasOptionPatterns = matcher.patterns.len > 0
    if items.len > 0:
      var firstIsPattern = not hasOptionPatterns and not matcher.numeric
      if matcher.numeric and items[0] != "-" and not fileExists(items[0]):
        firstIsPattern = true
      if hasOptionPatterns and items.len > 1 and not fileExists(items[0]) and
          fileExists(items[1]):
        firstIsPattern = true
      if firstIsPattern:
        matcher.patterns.insert(items[0], 0)
        items.delete(0)
    if matcher.patterns.len == 0 and not matcher.numeric:
      raise newException(ValueError, "A pattern or numeric bound is required")
    if items.len == 0:
      items.add("-")

    if matcher.ignoreCase and matcher.fixed:
      for pattern in matcher.patterns.mitems:
        pattern = pattern.toLowerAscii()
    if matcher.fixed and matcher.exact and not matcher.allPatterns:
      matcher.exactPatterns = toHashSet(matcher.patterns)
    elif not matcher.fixed:
      for pattern in matcher.patterns:
        matcher.regexes.add(regex.re2((if matcher.ignoreCase: "(?i)" else: "") & pattern))

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
    if outputR2.len > 0 and outputR2 != "-" and
        plan.first != "-" and
        (absolutePath(plan.first) == absolutePath(outputR2) or
         (fileExists(plan.first) and fileExists(outputR2) and
          sameFile(plan.first, outputR2))):
      raise newException(ValueError, "R1 and R2 output paths must differ")

    var state = IdRunState(plan: plan, matcher: matcher,
                           current: IdBatch(paired: paired), threads: threads,
                           batchSize: batchSize, pairBoth: pairMode == "both",
                           invert: bool(args["--invert-match"]))
    state.output1 = openFilterWriter(plan.first, fxfFastq, gzipLevel)
    try:
      if plan.splitPairs:
        state.output2 = openFilterWriter(plan.second, fxfFastq, gzipLevel)
    except CatchableError:
      state.output1.close()
      raise
    defer:
      state.output1.close()
      if plan.splitPairs:
        state.output2.close()

    if args["--verbose"]:
      stderr.writeLine("[by-id] input: ", inputs.join(", "))
      stderr.writeLine("[by-id] output: ", if plan.first.len == 0: "stdout" else: plan.first,
                       if plan.splitPairs: ", " & plan.second else: " (interleaved for pairs)")

    if twoFiles:
      for pair in readFQPairPtr(r1, r2):
        state.idConsume(pair.read1, pair.read2, true)
    elif interleaved:
      for pair in readFQInterleavedPairPtr(items[0]):
        state.idConsume(pair.read1, pair.read2, true)
    else:
      for path in items:
        for record in readFQPtr(path):
          state.idConsume(record, FQRecordPtr(), false)

    state.idFinish()
    if args["--stats"]:
      stderr.writeLine("[by-id] processed: ", state.processed,
                       if paired: " pairs; selected: " else: " reads; selected: ",
                       state.selected)
    return 0
  except CatchableError as error:
    stderr.writeLine("ERROR: by-id: ", error.msg)
    return 1
