import std/[math, os, sets, strutils, tables]
import docopt
import kexpr
import malebolgia
import readfx
import regex except re, match, replace, Regex
import ./filter_utils
import ./seqfu_utils

type
  CommentValueKind = enum
    cvString, cvInteger, cvFloat

  CommentValue = object
    raw: string
    kind: CommentValueKind
    integer: int64
    real: float64
    invalid: bool

  CommentWhereOp = enum
    cwEqual, cwNotEqual, cwLess, cwLessEqual, cwGreater, cwGreaterEqual,
    cwRegex, cwNotRegex, cwExists, cwMissing

  CommentWhere = object
    source, key, operand: string
    op: CommentWhereOp
    operandValue: CommentValue
    compiled: regex.Regex2

  CommentMatcher = object
    patterns: seq[string]
    regexes: seq[regex.Regex2]
    exactPatterns: HashSet[string]
    wheres: seq[CommentWhere]
    forcedTypes: Table[string, CommentValueKind]
    expression: string
    exprVariables: HashSet[string]
    textAll, whereAll, fixed, exact, ignoreCase: bool
    hasComment, noComment, hasExpression: bool
    attributeSeparator, decimalSeparator, thousandsSeparator: char
    duplicateMode, invalidMode: string

  CommentBatch = object
    first, second: seq[FQRecord]
    selected: seq[bool]
    error: string
    paired: bool

  CommentRunState = object
    output1, output2: FastxWriter
    plan: FilterOutputPlan
    matcher: CommentMatcher
    batches: seq[CommentBatch]
    current: CommentBatch
    threads, batchSize: int
    pairBoth, invert: bool
    processed, selected: int64

proc commentParseInt(value, option: string): int64 =
  try:
    result = parseBiggestInt(value)
  except ValueError:
    raise newException(ValueError, option & " requires a signed 64-bit integer: " & value)

proc commentKeyStart(c: char): bool {.inline.} =
  c in {'a'..'z', 'A'..'Z', '_'}

proc commentKeyChar(c: char): bool {.inline.} =
  commentKeyStart(c) or c in {'0'..'9', '-', '.'}

proc commentValidKey(key: string): bool =
  if key.len == 0 or not commentKeyStart(key[0]):
    return false
  for c in key:
    if not commentKeyChar(c):
      return false
  true

proc commentFinite(value: float64): bool {.inline.} =
  classify(value) notin {fcNan, fcInf, fcNegInf}

proc commentNumber(raw: string, decimal, thousands: char): CommentValue =
  result = CommentValue(raw: raw, kind: cvString)
  if raw.len == 0:
    return
  result.invalid = raw[0] in {'0'..'9', '+', '-', decimal, thousands} or
                   (raw.len <= 8 and raw[0] in {'n', 'N', 'i', 'I'} and
                    raw.toLowerAscii() in ["nan", "inf", "infinity"])
  var i = 0
  var normalized = newStringOfCap(raw.len)
  if raw[i] in {'+', '-'}:
    normalized.add(raw[i])
    inc i
  var intDigits = 0
  var groupDigits = 0
  var grouped = false
  while i < raw.len and (raw[i] in {'0'..'9'} or raw[i] == thousands):
    if raw[i] == thousands:
      if groupDigits == 0 or (if grouped: groupDigits != 3 else: groupDigits > 3):
        return
      grouped = true
      groupDigits = 0
    else:
      normalized.add(raw[i])
      inc intDigits
      inc groupDigits
    inc i
  if grouped and groupDigits != 3:
    return
  var fractional = false
  if i < raw.len and raw[i] == decimal:
    fractional = true
    normalized.add('.')
    inc i
    let fractionStart = i
    while i < raw.len and raw[i] in {'0'..'9'}:
      normalized.add(raw[i])
      inc i
    if i == fractionStart:
      return
  if intDigits == 0 and not fractional:
    return
  var exponent = false
  if i < raw.len and raw[i] in {'e', 'E'}:
    exponent = true
    normalized.add('e')
    inc i
    if i < raw.len and raw[i] in {'+', '-'}:
      normalized.add(raw[i])
      inc i
    let exponentStart = i
    while i < raw.len and raw[i] in {'0'..'9'}:
      normalized.add(raw[i])
      inc i
    if i == exponentStart:
      return
  if i != raw.len:
    return
  try:
    if fractional or exponent:
      result.real = parseFloat(normalized)
      if not commentFinite(result.real):
        result.invalid = true
      else:
        result.kind = cvFloat
        result.invalid = false
    else:
      result.integer = parseBiggestInt(normalized)
      result.kind = cvInteger
      result.invalid = false
  except ValueError:
    result.invalid = true

proc commentTypedValue(raw, key: string, matcher: CommentMatcher): CommentValue =
  result = commentNumber(raw, matcher.decimalSeparator, matcher.thousandsSeparator)
  if key in matcher.forcedTypes:
    case matcher.forcedTypes[key]
    of cvString:
      result.kind = cvString
      result.invalid = false
    of cvInteger:
      if result.kind != cvInteger:
        result.invalid = true
    of cvFloat:
      if result.kind == cvInteger:
        result.real = float64(result.integer)
        result.kind = cvFloat
      elif result.kind != cvFloat:
        result.invalid = true

proc commentAttributes(comment: string, matcher: CommentMatcher): Table[string, CommentValue] =
  result = initTable[string, CommentValue]()
  var i = 0
  while i < comment.len:
    if not commentKeyStart(comment[i]) or
        (i > 0 and commentKeyChar(comment[i - 1])):
      inc i
      continue
    let keyStart = i
    inc i
    while i < comment.len and commentKeyChar(comment[i]):
      inc i
    let key = comment[keyStart ..< i]
    while i < comment.len and comment[i] in Whitespace:
      inc i
    if i >= comment.len or comment[i] != matcher.attributeSeparator:
      continue
    inc i
    while i < comment.len and comment[i] in Whitespace:
      inc i
    var raw = ""
    if i < comment.len and comment[i] in {'\'', '"'}:
      let quote = comment[i]
      inc i
      var closed = false
      while i < comment.len:
        if comment[i] == '\\' and i + 1 < comment.len and
            comment[i + 1] in {quote, '\\'}:
          raw.add(comment[i + 1])
          i += 2
        elif comment[i] == quote:
          inc i
          closed = true
          break
        else:
          raw.add(comment[i])
          inc i
      if not closed:
        raise newException(ValueError, "Unterminated quoted attribute " & key)
    else:
      let valueStart = i
      while i < comment.len and comment[i] notin Whitespace and comment[i] != ';':
        inc i
      raw = comment[valueStart ..< i]
    if key in result:
      case matcher.duplicateMode
      of "first": continue
      of "error": raise newException(ValueError, "Duplicate comment attribute: " & key)
      else: discard
    let value = commentTypedValue(raw, key, matcher)
    if value.invalid and matcher.invalidMode == "error" and key in matcher.forcedTypes:
      raise newException(ValueError, "Invalid " & $matcher.forcedTypes[key] &
                         " value for " & key & ": " & raw)
    result[key] = value

proc commentUnquote(text: string): string =
  result = text.strip()
  if result.len < 2 or result[0] notin {'\'', '"'} or result[^1] != result[0]:
    return
  let quote = result[0]
  let source = result
  result = ""
  var i = 1
  while i < source.len - 1:
    if source[i] == '\\' and i + 1 < source.len - 1 and
        source[i + 1] in {quote, '\\'}:
      result.add(source[i + 1])
      i += 2
    else:
      result.add(source[i])
      inc i

proc commentParseWhere(source: string, matcher: CommentMatcher): CommentWhere =
  let stripped = source.strip()
  var i = 0
  if i >= stripped.len or not commentKeyStart(stripped[i]):
    raise newException(ValueError, "Invalid --where predicate: " & source)
  inc i
  while i < stripped.len and commentKeyChar(stripped[i]):
    inc i
  result.key = stripped[0 ..< i]
  result.source = source
  let rest = stripped[i .. ^1].strip()
  if rest == "exists":
    result.op = cwExists
    return
  if rest == "missing":
    result.op = cwMissing
    return
  var operatorLength = 0
  for (symbol, kind) in [("!=", cwNotEqual), ("<=", cwLessEqual),
                         (">=", cwGreaterEqual), ("!~", cwNotRegex),
                         ("=", cwEqual), ("<", cwLess), (">", cwGreater),
                         ("~", cwRegex)]:
    if rest.startsWith(symbol):
      operatorLength = symbol.len
      result.op = kind
      break
  if operatorLength == 0 or rest.len == operatorLength:
    raise newException(ValueError, "Invalid --where predicate: " & source)
  result.operand = commentUnquote(rest[operatorLength .. ^1])
  if result.op in {cwRegex, cwNotRegex}:
    result.compiled = regex.re2(result.operand)
  else:
    result.operandValue = commentNumber(result.operand, matcher.decimalSeparator,
                                        matcher.thousandsSeparator)
    if result.op in {cwLess, cwLessEqual, cwGreater, cwGreaterEqual} and
        result.operandValue.kind == cvString:
      raise newException(ValueError, "Numeric --where predicate needs a numeric operand: " & source)

proc commentReadLines(path: string): seq[string] =
  if not fileExists(path):
    raise newException(IOError, "File not found: " & path)
  for line in lines(path):
    let item = line.strip()
    if item.len > 0 and item[0] != '#':
      result.add(item)

proc commentTextMatches(comment: string, matcher: CommentMatcher): bool =
  if matcher.patterns.len == 0:
    return true
  let normalized = if matcher.fixed and matcher.ignoreCase:
                     comment.toLowerAscii() else: comment
  if matcher.fixed and matcher.exact and not matcher.textAll:
    return normalized in matcher.exactPatterns
  for i in 0 ..< matcher.patterns.len:
    let matched =
      if matcher.fixed:
        if matcher.exact: normalized == matcher.patterns[i]
        else: matcher.patterns[i] in normalized
      elif matcher.exact:
        regex.match(normalized, matcher.regexes[i])
      else:
        regex.contains(normalized, matcher.regexes[i])
    if matcher.textAll and not matched:
      return false
    if not matcher.textAll and matched:
      return true
  matcher.textAll

proc commentCompare(left, right: CommentValue): int =
  if left.kind == cvInteger and right.kind == cvInteger:
    return cmp(left.integer, right.integer)
  if left.kind != cvString and right.kind != cvString:
    let a = if left.kind == cvInteger: float64(left.integer) else: left.real
    let b = if right.kind == cvInteger: float64(right.integer) else: right.real
    return cmp(a, b)
  cmp(left.raw, right.raw)

proc commentWhereMatches(test: CommentWhere,
                         attrs: Table[string, CommentValue],
                         matcher: CommentMatcher): bool =
  if test.op == cwExists:
    return test.key in attrs
  if test.op == cwMissing:
    return test.key notin attrs
  if test.key notin attrs:
    return false
  let value = attrs[test.key]
  if test.op in {cwLess, cwLessEqual, cwGreater, cwGreaterEqual}:
    if value.kind == cvString or test.operandValue.kind == cvString:
      if matcher.invalidMode == "error":
        raise newException(ValueError, "Non-numeric value for --where '" &
                           test.source & "': " & value.raw)
      return false
  case test.op
  of cwRegex: regex.contains(value.raw, test.compiled)
  of cwNotRegex: not regex.contains(value.raw, test.compiled)
  of cwEqual: commentCompare(value, test.operandValue) == 0
  of cwNotEqual: commentCompare(value, test.operandValue) != 0
  of cwLess: commentCompare(value, test.operandValue) < 0
  of cwLessEqual: commentCompare(value, test.operandValue) <= 0
  of cwGreater: commentCompare(value, test.operandValue) > 0
  of cwGreaterEqual: commentCompare(value, test.operandValue) >= 0
  of cwExists, cwMissing: false

proc commentExpression(expression: string): ptr kexpr_t =
  var parseError: cint
  result = ke_parse(expression, addr parseError)
  if result == nil or parseError != 0:
    if result != nil:
      ke_destroy(result)
    raise newException(ValueError, "Invalid --expr expression (code " &
                       $parseError & "): " & expression)
  discard ke_set_default_func(result)

proc commentExprKey(key: string): string =
  result = key
  for c in result.mitems:
    if c in {'-', '.'}:
      c = '_'

proc commentExpressionVariables(source: string): HashSet[string] =
  result = initHashSet[string]()
  var i = 0
  while i < source.len:
    if source[i] in {'\'', '"'}:
      let quote = source[i]
      inc i
      while i < source.len and source[i] != quote:
        if source[i] == '\\' and i + 1 < source.len:
          inc i
        inc i
      if i < source.len:
        inc i
    elif commentKeyStart(source[i]) and
        (i == 0 or source[i - 1] notin {'0'..'9', 'a'..'z', 'A'..'Z', '_', '.'}):
      let start = i
      inc i
      while i < source.len and source[i] in {'0'..'9', 'a'..'z', 'A'..'Z', '_'}:
        inc i
      var next = i
      while next < source.len and source[next] in Whitespace:
        inc next
      if next >= source.len or source[next] != '(':
        result.incl(source[start ..< i])
    else:
      inc i

proc commentExpressionMatches(expr: ptr kexpr_t,
                              attrs: Table[string, CommentValue],
                              matcher: CommentMatcher): bool =
  ke_unset(expr)
  var mapped = initHashSet[string]()
  for key, value in attrs:
    let name = commentExprKey(key)
    if name in mapped:
      raise newException(ValueError, "Comment attributes collide in --expr: " & name)
    mapped.incl(name)
    if name notin matcher.exprVariables:
      continue
    if value.invalid:
      if matcher.invalidMode == "error":
        raise newException(ValueError, "Invalid value for --expr attribute " & key &
                           ": " & value.raw)
      return false
    case value.kind
    of cvInteger: discard ke_set_int(expr, name.cstring, value.integer)
    of cvFloat:
      if value.real >= float64(high(int64)) or value.real <= float64(low(int64)):
        if matcher.invalidMode == "error":
          raise newException(ValueError, "Out-of-range --expr attribute " & key)
        return false
      discard ke_set_real(expr, name.cstring, value.real)
    of cvString: discard ke_set_str(expr, name.cstring, value.raw.cstring)
  var evalError: cint
  let value = ke_eval_real(expr, addr evalError)
  if (evalError and cint(KEE_UNVAR)) != 0:
    return false
  if evalError != 0 or not commentFinite(value):
    raise newException(ValueError, "Could not evaluate --expr (code " & $evalError & "): " &
                       matcher.expression)
  value != 0.0

proc commentMatches(comment: string, matcher: CommentMatcher,
                    expr: ptr kexpr_t): bool =
  if matcher.hasComment and comment.strip().len == 0:
    return false
  if matcher.noComment and comment.strip().len > 0:
    return false
  if not commentTextMatches(comment, matcher):
    return false
  if matcher.wheres.len == 0 and not matcher.hasExpression:
    return true
  let attrs = commentAttributes(comment, matcher)
  if matcher.wheres.len > 0:
    var passed = matcher.whereAll
    for test in matcher.wheres:
      let matched = commentWhereMatches(test, attrs, matcher)
      if matcher.whereAll and not matched:
        passed = false
        break
      if not matcher.whereAll and matched:
        passed = true
        break
    if not passed:
      return false
  if matcher.hasExpression:
    return commentExpressionMatches(expr, attrs, matcher)
  true

proc commentMatchRead(name, comment: string, matcher: CommentMatcher,
                      expr: ptr kexpr_t): bool =
  try:
    result = commentMatches(comment, matcher, expr)
  except ValueError as error:
    raise newException(ValueError, "read " & name & ": " & error.msg)

proc commentSelected(name1, comment1, name2, comment2: string, paired: bool,
                     matcher: CommentMatcher, expr: ptr kexpr_t,
                     pairBoth, invert: bool): bool =
  let first = commentMatchRead(name1, comment1, matcher, expr)
  var passed = first
  if paired:
    let second = commentMatchRead(name2, comment2, matcher, expr)
    passed = if pairBoth: first and second else: first or second
  if invert: not passed else: passed

proc commentProcessBatch(batch: ptr CommentBatch, matcher: ptr CommentMatcher,
                         pairBoth, invert: bool) =
  var expr: ptr kexpr_t
  try:
    if matcher.hasExpression:
      expr = commentExpression(matcher.expression)
    batch.selected = newSeq[bool](batch.first.len)
    for i in 0 ..< batch.first.len:
      let secondName = if batch.paired: batch.second[i].name else: ""
      let secondComment = if batch.paired: batch.second[i].comment else: ""
      batch.selected[i] = commentSelected(batch.first[i].name,
                                          batch.first[i].comment,
                                          secondName, secondComment,
                                          batch.paired, matcher[], expr,
                                          pairBoth, invert)
  except ValueError as error:
    batch.error = error.msg
  finally:
    if expr != nil:
      ke_destroy(expr)

proc commentFlush(state: var CommentRunState) =
  if state.batches.len == 0:
    return
  if state.threads > 1 and state.batches.len > 1:
    var master = createMaster()
    master.awaitAll:
      for i in 0 ..< state.batches.len:
        master.spawn commentProcessBatch(addr state.batches[i],
                                         addr state.matcher, state.pairBoth,
                                         state.invert)
  else:
    for i in 0 ..< state.batches.len:
      commentProcessBatch(addr state.batches[i], addr state.matcher,
                          state.pairBoth, state.invert)

  for batch in state.batches:
    if batch.error.len > 0:
      raise newException(ValueError, batch.error)
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
  state.batches.setLen(0)

proc commentConsume(state: var CommentRunState, first, second: FQRecordPtr,
                    paired: bool, expr: ptr kexpr_t) =
  if paired and (first.qualityLen == 0 or second.qualityLen == 0):
    raise newException(ValueError, "Paired input must contain FASTQ records")
  if state.threads == 1:
    inc state.processed
    let name1 = filterPtrString(first.name, first.nameLen)
    let text1 = filterPtrString(first.comment, first.commentLen)
    let name2 = if paired: filterPtrString(second.name, second.nameLen) else: ""
    let text2 = if paired: filterPtrString(second.comment, second.commentLen) else: ""
    if commentSelected(name1, text1, name2, text2, paired, state.matcher,
                       expr, state.pairBoth, state.invert):
      inc state.selected
      state.output1.writeFilterRecord(first)
      if paired:
        if state.plan.splitPairs:
          state.output2.writeFilterRecord(second)
        else:
          state.output1.writeFilterRecord(second)
    return

  state.current.first.add(copyFilterRecord(first))
  if paired:
    state.current.second.add(copyFilterRecord(second))
  if state.current.first.len >= state.batchSize:
    state.batches.add(state.current)
    state.current = CommentBatch(paired: paired)
    if state.batches.len >= state.threads:
      state.commentFlush()

proc commentFinish(state: var CommentRunState) =
  if state.current.first.len > 0:
    state.batches.add(state.current)
    state.current = CommentBatch()
  state.commentFlush()

proc filter_bycomment(argv: var seq[string]): int =
  let doc = """
Usage:
  by-comment [options] [-e PATTERN]... [--where PREDICATE]... [--attribute-type KEY:TYPE]... [<item>...]

Select FASTA/FASTQ records by comment text or key=value attributes.
With a positional pattern, remaining items are input files. Use -e to
disambiguate input files when combining selectors.

Comment text:
  -e, --pattern PATTERN           Add a text pattern; may be repeated
  -f, --patterns-file FILE        Read one text pattern per line
  --logic MODE                    Combine text patterns: any|all [default: any]
  -F, --fixed-string              Treat patterns as literal strings
  -x, --exact                     Match the complete comment
  -i, --ignore-case               Case-insensitive text matching
  --has-comment                   Require a non-empty comment
  --no-comment                    Require an empty comment

Attributes:
  --where PREDICATE               Add a typed test; may be repeated
  --where-file FILE               Read one predicate per line
  --where-logic MODE              Combine predicates: any|all [default: all]
  --expr EXPRESSION               Evaluate a kexpr expression on attributes
  --expr-file FILE                Read one expression from FILE
  --attribute-separator CHAR      Key/value separator [default: =]
  --decimal-separator CHAR        Numeric decimal separator [default: .]
  --thousands-separator CHAR      Numeric grouping separator [default: ,]
  --attribute-type KEY:TYPE       Force string|integer|float; may be repeated
  --duplicate-keys MODE           Resolve first|last|error [default: last]
  --invalid-value MODE            Failed typed conversion: false|error [default: false]

Selection:
  -v, --invert-match              Invert the final selection

Input:
  -1, --r1 FILE                  Paired-end R1 FASTQ
  -2, --r2 FILE                  Paired-end R2 FASTQ
  --interleaved                  Treat one input as interleaved FASTQ
  --pair-mode MODE               Match either or both mates: any|both [default: any]

Output:
  -o, --output FILE              Write to FILE (gzip if .gz)
  -O, --output-r2 FILE           Write selected R2 reads to FILE
  --interleaved-output           Keep paired output interleaved even when -o implies R2
  --gzip-level INT               Gzip compression level [default: 6]

Performance:
  -t, --threads INT              Worker threads [default: 1]
  --batch-size INT               Records or pairs per batch [default: 4096]

Other:
  --stats                        Print processed and selected counts to stderr
  --verbose                      Print input and output routing to stderr
  -h, --help                     Show this help
"""
  let args = docopt(doc, argv = argv, version = version())

  try:
    var matcher = CommentMatcher(forcedTypes: initTable[string, CommentValueKind]())
    let textLogic = $args["--logic"]
    let whereLogic = $args["--where-logic"]
    let pairMode = $args["--pair-mode"]
    if textLogic notin ["any", "all"]:
      raise newException(ValueError, "--logic must be any or all")
    if whereLogic notin ["any", "all"]:
      raise newException(ValueError, "--where-logic must be any or all")
    if pairMode notin ["any", "both"]:
      raise newException(ValueError, "--pair-mode must be any or both")
    matcher.textAll = textLogic == "all"
    matcher.whereAll = whereLogic == "all"
    matcher.fixed = bool(args["--fixed-string"])
    matcher.exact = bool(args["--exact"])
    matcher.ignoreCase = bool(args["--ignore-case"])
    matcher.hasComment = bool(args["--has-comment"])
    matcher.noComment = bool(args["--no-comment"])
    if matcher.hasComment and matcher.noComment:
      raise newException(ValueError, "--has-comment and --no-comment cannot be combined")

    for (option, target) in [("--attribute-separator", addr matcher.attributeSeparator),
                             ("--decimal-separator", addr matcher.decimalSeparator),
                             ("--thousands-separator", addr matcher.thousandsSeparator)]:
      let value = $args[option]
      if value.len != 1 or value[0] in Whitespace or value[0] == ';':
        raise newException(ValueError, option & " requires one non-whitespace character")
      target[] = value[0]
    if matcher.decimalSeparator == matcher.thousandsSeparator or
        matcher.attributeSeparator in {matcher.decimalSeparator,
                                       matcher.thousandsSeparator}:
      raise newException(ValueError, "Attribute and numeric separators must differ")
    if commentKeyChar(matcher.attributeSeparator) or
        matcher.attributeSeparator in {'\'', '"', '\\'}:
      raise newException(ValueError, "--attribute-separator conflicts with attribute syntax")
    if matcher.decimalSeparator in {'0'..'9', 'a'..'z', 'A'..'Z', '_', '+', '-', '\'', '"', '\\'} or
        matcher.thousandsSeparator in {'0'..'9', 'a'..'z', 'A'..'Z', '_', '+', '-', '\'', '"', '\\'}:
      raise newException(ValueError, "Numeric separators must be punctuation")
    matcher.duplicateMode = $args["--duplicate-keys"]
    matcher.invalidMode = $args["--invalid-value"]
    if matcher.duplicateMode notin ["first", "last", "error"]:
      raise newException(ValueError, "--duplicate-keys must be first, last, or error")
    if matcher.invalidMode notin ["false", "error"]:
      raise newException(ValueError, "--invalid-value must be false or error")

    for spec in args["--attribute-type"]:
      let parts = ($spec).split(':')
      if parts.len != 2 or not commentValidKey(parts[0]) or
          parts[0] in matcher.forcedTypes:
        raise newException(ValueError, "--attribute-type expects unique KEY:TYPE: " & $spec)
      case parts[1]
      of "string": matcher.forcedTypes[parts[0]] = cvString
      of "integer": matcher.forcedTypes[parts[0]] = cvInteger
      of "float": matcher.forcedTypes[parts[0]] = cvFloat
      else: raise newException(ValueError, "Unknown attribute type: " & parts[1])

    for pattern in args["--pattern"]:
      matcher.patterns.add($pattern)
    let patternsFile = $args["--patterns-file"]
    if patternsFile != "nil":
      matcher.patterns.add(commentReadLines(patternsFile))

    for value in args["--where"]:
      matcher.wheres.add(commentParseWhere($value, matcher))
    let whereFile = $args["--where-file"]
    if whereFile != "nil":
      for value in commentReadLines(whereFile):
        matcher.wheres.add(commentParseWhere(value, matcher))

    let expressionText = $args["--expr"]
    let expressionFile = $args["--expr-file"]
    if expressionText != "nil" and expressionFile != "nil":
      raise newException(ValueError, "Use either --expr or --expr-file")
    if expressionFile != "nil":
      if not fileExists(expressionFile):
        raise newException(IOError, "Expression file not found: " & expressionFile)
      matcher.expression = readFile(expressionFile).strip()
    elif expressionText != "nil":
      matcher.expression = expressionText.strip()
    matcher.hasExpression = expressionText != "nil" or expressionFile != "nil"
    if matcher.hasExpression:
      if matcher.expression.len == 0:
        raise newException(ValueError, "--expr cannot be empty")
      let check = commentExpression(matcher.expression)
      ke_destroy(check)
      matcher.exprVariables = commentExpressionVariables(matcher.expression)

    var items: seq[string]
    for item in args["<item>"]:
      items.add($item)
    let hasOptionSelector = matcher.patterns.len > 0 or matcher.wheres.len > 0 or
                            matcher.hasExpression or matcher.hasComment or matcher.noComment
    if items.len > 0:
      var firstIsPattern = not hasOptionSelector
      if hasOptionSelector and items.len > 1 and not fileExists(items[0]) and
          fileExists(items[1]):
        firstIsPattern = true
      if firstIsPattern:
        matcher.patterns.insert(items[0], 0)
        items.delete(0)
    if matcher.patterns.len == 0 and matcher.wheres.len == 0 and
        not matcher.hasExpression and not matcher.hasComment and not matcher.noComment:
      raise newException(ValueError, "A comment selector is required")
    if items.len == 0:
      items.add("-")

    if matcher.ignoreCase and matcher.fixed:
      for pattern in matcher.patterns.mitems:
        pattern = pattern.toLowerAscii()
    if matcher.fixed and matcher.exact and not matcher.textAll:
      matcher.exactPatterns = toHashSet(matcher.patterns)
    elif not matcher.fixed:
      for pattern in matcher.patterns:
        matcher.regexes.add(regex.re2((if matcher.ignoreCase: "(?i)" else: "") & pattern))

    let threadsValue = commentParseInt($args["--threads"], "--threads")
    let batchSizeValue = commentParseInt($args["--batch-size"], "--batch-size")
    let gzipLevelValue = commentParseInt($args["--gzip-level"], "--gzip-level")
    if threadsValue < 1 or threadsValue > ThreadPoolSize:
      raise newException(ValueError, "--threads must be between 1 and " & $ThreadPoolSize)
    if batchSizeValue < 1 or batchSizeValue > high(int):
      raise newException(ValueError, "--batch-size must be between 1 and " & $high(int))
    if gzipLevelValue < 0 or gzipLevelValue > 9:
      raise newException(ValueError, "--gzip-level must be between 0 and 9")
    let threads = int(threadsValue)
    let batchSize = int(batchSizeValue)
    let gzipLevel = int(gzipLevelValue)

    let r1 = $args["--r1"]
    let r2 = $args["--r2"]
    let twoFiles = r1 != "nil" or r2 != "nil"
    let interleaved = bool(args["--interleaved"])
    if twoFiles and (r1 == "nil" or r2 == "nil" or interleaved):
      raise newException(ValueError, "-1 and -2 are required together, without --interleaved")
    if twoFiles and (items.len != 1 or items[0] != "-"):
      raise newException(ValueError, "Paired input cannot be combined with positional files")
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
    for path in [patternsFile, whereFile, expressionFile]:
      if path != "nil":
        protectedInputs.add(path)
    validateFilterOutputs(plan, protectedInputs)
    if plan.splitPairs and plan.first != "-" and plan.second != "-" and
        fileExists(plan.first) and fileExists(plan.second) and
        sameFile(plan.first, plan.second):
      raise newException(ValueError, "R1 and R2 output paths must differ")

    var state = CommentRunState(plan: plan, matcher: matcher,
                                current: CommentBatch(paired: paired),
                                threads: threads, batchSize: batchSize,
                                pairBoth: pairMode == "both",
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

    var expr: ptr kexpr_t
    if threads == 1 and matcher.hasExpression:
      expr = commentExpression(matcher.expression)
    defer:
      if expr != nil:
        ke_destroy(expr)

    if args["--verbose"]:
      stderr.writeLine("[by-comment] input: ", inputs.join(", "))
      stderr.writeLine("[by-comment] output: ",
                       if plan.first.len == 0: "stdout" else: plan.first,
                       if plan.splitPairs: ", " & plan.second else: " (interleaved for pairs)")

    if twoFiles:
      for pair in readFQPairPtr(r1, r2):
        state.commentConsume(pair.read1, pair.read2, true, expr)
    elif interleaved:
      for pair in readFQInterleavedPairPtr(items[0]):
        state.commentConsume(pair.read1, pair.read2, true, expr)
    else:
      for path in items:
        for record in readFQPtr(path):
          state.commentConsume(record, FQRecordPtr(), false, expr)
    state.commentFinish()
    if args["--stats"]:
      stderr.writeLine("[by-comment] processed: ", state.processed,
                       if paired: " pairs; selected: " else: " reads; selected: ",
                       state.selected)
    return 0
  except CatchableError as error:
    stderr.writeLine("ERROR: by-comment: ", error.msg)
    return 1
