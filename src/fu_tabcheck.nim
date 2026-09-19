import parsecsv
import docopt
import os
import tables
import algorithm
import std/strutils
import std/times
import ./seqfu_legacy_fastx

const NimblePkgVersion {.strdefine.} = "undef"
const version = if NimblePkgVersion == "undef": "<prerelease>"
                else: NimblePkgVersion


type
  checkResult = object
    totalLines: int
    records: int
    columns: int
    valid: bool
    sep: string
    sepchar: char
    firstBadRow: int
    expectedColumns: int
    observedColumns: int
    reason: string
    errormsg: string

  separatorSample = object
    sep: char
    score: int
    rows: int
    columns: int
    mismatch: bool

  columnType = enum
    ctInt = "int"
    ctFloat = "float"
    ctString = "string"
    ctDate = "date"

  columnStats = object
    total: int
    nonEmpty: int
    allInt: bool
    allFloat: bool
    allDate: bool
    numericCount: int
    numericMin: float
    numericMax: float
    numericSum: float
    dateMin: string
    dateMax: string
    values: CountTable[string]
 
proc isCommentRow(row: openArray[string], comment: char): bool =
  if comment == '\0' or row.len == 0:
    return false
  let firstField = row[0].strip(leading = true, trailing = false)
  if firstField.len == 0:
    return false
  return firstField[0] == comment


proc toString(s: checkResult, withHeader=false): string =
  if s.valid:
    result &= "Pass\t"
  else:
    result &= "Error"
    var details = newSeq[string]()
    if s.firstBadRow > 0:
      details.add("row=" & $s.firstBadRow)
    if s.expectedColumns > 0 or s.observedColumns > 0:
      details.add("expected=" & $s.expectedColumns)
      details.add("observed=" & $s.observedColumns)
    if s.reason.len > 0:
      details.add("reason=" & s.reason)
    if details.len > 0:
      result &= "[" & join(details, ";") & "]"
    return
  
  let sepStr = if not withHeader: "separator="
                else: ""
  result &= $(s.columns) & "\t" & $(s.records) & "\t" & sepStr & "[" & s.sep & "]"

proc checkFile(f: string, sep: char, header: char): checkResult =
  var
    parser: CsvParser
  
  result.sepchar = sep
  if sep == '\t':
    result.sep = "tab"
  elif sep == ' ':
    result.sep = "space"
  else:
    result.sep = $sep 

  var
    total_lines = 0
    expectedCols = 0
  try:
    let file = openSeqfuGzStream(f)
    parser.open(file, f, separator = sep)
    defer: parser.close()
    while readRow(parser):
      if isCommentRow(parser.row, header):
        continue
      total_lines += 1
      let rowCols = len(parser.row)
      if total_lines == 1:
        expectedCols = rowCols
        result.expectedColumns = expectedCols
        if expectedCols <= 1:
          result.valid = false
          result.firstBadRow = 1
          result.observedColumns = rowCols
          result.reason = "single-column-table"
          return
      elif rowCols != expectedCols:
        result.valid = false
        result.firstBadRow = total_lines
        result.expectedColumns = expectedCols
        result.observedColumns = rowCols
        result.reason = "inconsistent-column-count"
        return

    result.totalLines = total_lines
    if total_lines == 0:
      result.valid = false
      result.reason = "no-data-rows"
      return

    result.valid = true
    result.columns = expectedCols
    result.records = total_lines
    return
  except Exception as e:
    result.valid = false
    result.reason = "parse-error"
    result.errormsg = e.msg
    stderr.writeLine("ERROR: parsing ", f, ": ", e.msg)

proc sampleSeparator(f: string, sep: char, header: char, maxRows = 128): separatorSample =
  result.sep = sep
  result.score = -1

  var
    parser: CsvParser
    expectedCols = 0

  try:
    let file = openSeqfuGzStream(f)
    parser.open(file, f, separator = sep)
    defer: parser.close()
    while readRow(parser):
      if isCommentRow(parser.row, header):
        continue
      result.rows += 1
      let cols = len(parser.row)
      if result.rows == 1:
        expectedCols = cols
        result.columns = cols
      elif cols != expectedCols:
        result.mismatch = true
        break
      if result.rows >= maxRows:
        break

    if result.rows == 0:
      result.score = 0
    elif result.columns > 1 and not result.mismatch:
      result.score = 10_000 + (result.rows * 10) + result.columns
    elif result.columns > 1:
      result.score = 5_000 + (result.rows * 10) + result.columns
    else:
      result.score = result.rows * 2
  except Exception:
    result.score = -1

proc pickAutoSeparator(f: string, separators: seq[char], commentChar: char, verbose = false): char =
  result = separators[0]
  var
    bestScore = low(int)

  for sep in separators:
    let sample = sampleSeparator(f, sep, commentChar)
    if verbose:
      stderr.writeLine("Auto sample <", sep, ">: rows=", sample.rows, " cols=", sample.columns, " mismatch=", sample.mismatch, " score=", sample.score)
    if sample.score > bestScore:
      bestScore = sample.score
      result = sample.sep
  if verbose:
    stderr.writeLine("Auto selected separator: <", result, ">")


proc initColumnStats(): columnStats =
  result.allInt = true
  result.allFloat = true
  result.allDate = true
  result.values = initCountTable[string]()

proc parseDate(value: string, normalized: var string): bool =
  for pattern in ["yyyy-MM-dd", "yyyy/MM/dd"]:
    try:
      let parsed = times.parse(value, pattern)
      normalized = parsed.format("yyyy-MM-dd")
      return true
    except ValueError:
      discard

proc addValue(stats: var columnStats, value: string) =
  stats.total += 1
  stats.values.inc(value)
  if value.len == 0:
    return

  stats.nonEmpty += 1
  try:
    discard parseBiggestInt(value)
  except ValueError:
    stats.allInt = false

  try:
    let number = parseFloat(value)
    if stats.numericCount == 0:
      stats.numericMin = number
      stats.numericMax = number
    else:
      stats.numericMin = min(stats.numericMin, number)
      stats.numericMax = max(stats.numericMax, number)
    stats.numericSum += number
    stats.numericCount += 1
  except ValueError:
    stats.allFloat = false

  var normalizedDate = ""
  if parseDate(value, normalizedDate):
    if stats.dateMin.len == 0 or normalizedDate < stats.dateMin:
      stats.dateMin = normalizedDate
    if stats.dateMax.len == 0 or normalizedDate > stats.dateMax:
      stats.dateMax = normalizedDate
  else:
    stats.allDate = false

proc inferredType(stats: columnStats): columnType =
  if stats.nonEmpty > 0 and stats.allInt:
    return ctInt
  if stats.nonEmpty > 0 and stats.allFloat:
    return ctFloat
  if stats.nonEmpty > 0 and stats.allDate:
    return ctDate
  return ctString

proc valueType(value: string): columnType =
  var stats = initColumnStats()
  stats.addValue(value)
  return stats.inferredType()

proc copyRow(row: openArray[string]): seq[string] =
  result = newSeq[string](row.len)
  for i, value in row:
    result[i] = value

proc looksLikeHeader(firstRow: seq[string], tailStats: seq[columnStats]): bool =
  if firstRow.len != tailStats.len:
    return false

  var typedDifference = false
  for i, value in firstRow:
    if value.len == 0:
      return false
    let tailType = tailStats[i].inferredType()
    if value.valueType() == ctString and tailType in {ctInt, ctFloat, ctDate}:
      typedDifference = true
  return typedDifference

proc compactFloat(value: float): string =
  result = value.formatFloat(ffDecimal, 6)
  while result.len > 1 and result[^1] == '0':
    result.setLen(result.len - 1)
  if result[^1] == '.':
    result.setLen(result.len - 1)

proc displayValue(value: string): string =
  if value.len == 0:
    return "<empty>"
  return value.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")

proc describe(stats: columnStats, kind: columnType): string =
  case kind
  of ctInt, ctFloat:
    let average = stats.numericSum / float(stats.numericCount)
    result = "min=" & compactFloat(stats.numericMin) &
      "; max=" & compactFloat(stats.numericMax) &
      "; average=" & compactFloat(average)
  of ctDate:
    result = "min=" & stats.dateMin & "; max=" & stats.dateMax
  of ctString:
    var counts = newSeq[(string, int)]()
    for value, count in stats.values:
      counts.add((value, count))
    counts.sort(proc(a, b: (string, int)): int =
      if a[1] != b[1]: cmp(b[1], a[1])
      else: cmp(a[0], b[0]))

    var top = newSeq[string]()
    for i in 0 ..< min(3, counts.len):
      let percentage = if stats.total > 0:
        100.0 * float(counts[i][1]) / float(stats.total)
      else:
        0.0
      top.add(displayValue(counts[i][0]) & ": " & $counts[i][1] &
        " (" & percentage.formatFloat(ffDecimal, 1) & "%)")
    result = "total=" & $stats.total & "; distinct=" & $stats.values.len &
      "; top3=" & top.join(", ")

proc checkColumns(f: string, sep: char, comment: char, columns: int): bool =
  var
    parser: CsvParser

  try:
    let
      file = openSeqfuGzStream(f)
    parser.open(file, f, separator = sep)
    defer: parser.close()

    var explicitHeader = newSeq[string]()
    var firstData = newSeq[string]()
    while readRow(parser):
      if isCommentRow(parser.row, comment):
        if explicitHeader.len == 0 and parser.row.len == columns:
          explicitHeader = copyRow(parser.row)
          explicitHeader[0] = explicitHeader[0].strip(leading = true, trailing = false)
          if explicitHeader[0].len > 0 and explicitHeader[0][0] == comment:
            explicitHeader[0] = explicitHeader[0][1 .. ^1].strip()
        continue
      firstData = copyRow(parser.row)
      break

    if firstData.len == 0:
      return

    var tailStats = newSeq[columnStats](columns)
    for i in 0 ..< columns:
      tailStats[i] = initColumnStats()

    while readRow(parser):
      if isCommentRow(parser.row, comment):
        continue
      for i in 0 ..< columns:
        tailStats[i].addValue(parser.row[i])

    var colnames = newSeq[string](columns)
    var colstats = tailStats
    if explicitHeader.len == columns:
      colnames = explicitHeader
      for i in 0 ..< columns:
        colstats[i].addValue(firstData[i])
    elif looksLikeHeader(firstData, tailStats):
      colnames = firstData
    else:
      for i in 0 ..< columns:
        colnames[i] = $(i + 1)
        colstats[i].addValue(firstData[i])

    for i, stats in colstats:
      let kind = stats.inferredType()
      let name = if colnames[i].len > 0: colnames[i] else: $(i + 1)
      echo displayValue(name), "\t", $kind, "\t", stats.describe(kind)
    return true


  except Exception as e:
    stderr.writeLine("ERROR: parsing ", f, ": ", e.msg)


proc tabcheck*(args: var seq[string], cmdName = "fu-tabcheck"): int =
  let doc = """
  $CMD$

  A program inspect TSV and CSV files, that must contain more than 1 column.
  Double quotes are considered field delimiters, if present.
  Gzipped files are supported natively.

  Usage: 
  $CMD$ [options] <FILE>...

  Options:
    -s, --separator CHAR   Character separating the values, 'tab' for tab and 'auto'
                           to try tab or commas [default: auto]
    -c, --comment CHAR     Comment/Header char [default: #]
    -i, --inspect          Inspect one valid table and infer column types and statistics
    --header               Print a header to the report
    --verbose              Enable verbose mode
  """.replace("$CMD$", cmdName)
  let docArgs = docopt(doc, version=version, argv=args)


  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  
  var
    sepList = newSeq[char]()
    commentText = $docArgs["--comment"]
    commentChar = if len(commentText) > 0: commentText[0] else: '#'

  if $docArgs["--separator"] == "auto":
    sepList.add("\t")
    sepList.add(",")
  elif $docArgs["--separator"] == "tab":
    sepList.add("\t")
  else:
    sepList.add(  $docArgs["--separator"] )

  let
    separators = sepList
    printHeader = bool(docArgs["--header"])
    doInspect   = bool(docArgs["--inspect"])

  let inputFiles = @(docArgs["<FILE>"])
  if doInspect and inputFiles.len != 1:
    stderr.writeLine("ERROR: --inspect requires exactly one input table")
    return 2
  
  if docArgs["--verbose"]:
    stderr.writeLine("Separator: ", separators)

  # Prepare the 
  # Process file read by read

  var
    okFiles = 0
    badFiles = 0
    validFiles = newSeq[(string, char, int)]()

  if printHeader and not doInspect:
    echo "File\tPassQC\tColumns\tRows\tSeparator"
  for file in inputFiles:
    var
      bestFile: checkResult
    if docArgs["--verbose"]:
      stderr.writeLine("Parsing ", file)

    if $docArgs["--separator"] == "auto":
      let sepChar = pickAutoSeparator(file, separators, commentChar, bool(docArgs["--verbose"]))
      let check = checkFile(file, sepChar, commentChar)
      if docArgs["--verbose"]:
        stderr.writeLine "<", sepChar, "> ", check
      bestFile = check
    else:
      for sepChar in separators:
        let check = checkFile(file, sepChar, commentChar)
        if docArgs["--verbose"]:
          stderr.writeLine "<", sepChar, "> ", check
        if check.valid == true:
          if not bestFile.valid or bestFile.columns < check.columns:
            bestFile = check
        elif not bestFile.valid:
          if bestFile.reason.len == 0 or check.expectedColumns > bestFile.expectedColumns:
            bestFile = check
    
    if bestFile.valid == true:
      okFiles += 1
      validFiles.add((file, bestFile.sepchar, bestFile.columns))
    else:
      badFiles += 1
      if doInspect:
        stderr.writeLine(file, "\t", bestFile.toString())
    if not doInspect:
      echo file, "\t", bestFile.toString(printHeader)
  if docArgs["--verbose"]:
    stderr.writeLine(okFiles, " valid. ", badFiles, " non-valid files.")
  
  if badFiles > 0:
    return 1

  # Inspect?
  if doInspect:
    if printHeader:
      echo "Column\tType\tDescription"
    for fileInfo in validFiles:
      if not checkColumns(fileInfo[0], fileInfo[1], commentChar, fileInfo[2]):
        return 1

  return 0

proc seqfuTabcheck*(args: var seq[string]): int =
  return tabcheck(args, "tabcheck")


when isMainModule:
  var cmdArgs = commandLineParams()
  let exitCode = tabcheck(cmdArgs, "fu-tabcheck")
  quit(exitCode)
