import parsecsv
import docopt
import os
import tables
import algorithm
import zip/gzipfiles
import std/strutils

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
    let file = newGzFileStream(f)
    parser.open(file, f, separator = sep)
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
    let file = newGzFileStream(f)
    parser.open(file, f, separator = sep)
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
    elif result.mismatch:
      result.score = result.rows
    elif result.columns <= 1:
      result.score = result.rows * 2
    else:
      result.score = 10_000 + (result.rows * 10) + result.columns
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


proc checkColumns(f: string, sep: char, header: char) =
  var
    parser: CsvParser

  try:
    let
      file = newGzFileStream(f)
    parser.open(file, f, separator = sep)

    var
      colnames: seq[string]

    while readRow(parser):
      if isCommentRow(parser.row, header):
        continue
      colnames = parser.row
      break

    if colnames.len == 0:
      return

    var
      colstats = newSeq[CountTable[string]](len(colnames))
      rowcount = 0
    for i in 0 ..< len(colstats):
      colstats[i] = initCountTable[string]()
    
    # Parse CSV file
    while readRow(parser):
      if isCommentRow(parser.row, header):
        continue
      rowcount += 1
      # Increment column count in the array
      for i in 0 ..< min(len(parser.row), len(colstats)):
        colstats[i].inc(parser.row[i])
    
    for i, counter in pairs(colstats):
      var
        top = ""
        topratio = 0.0
      colstats[i].sort()
       
      if rowcount > 0:
        for s, count in colstats[i]:
          top = s
          topratio = float(100 * count / rowcount)
          break
      echo os.extractFilename(f), "\t", i, "\t", colnames[i], "\t", len(colstats[i]), "\t", top, "\t", topratio.formatFloat(ffDecimal, 1), "%"


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
    -i, --inspect          Gather more informations on column content [if valid column]     
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
  
  if docArgs["--verbose"]:
    stderr.writeLine("Separator: ", separators)

  # Prepare the 
  # Process file read by read

  var
    okFiles = 0
    badFiles = 0
    validFiles = newSeq[(string, char)]()

  if printHeader and not doInspect:
    echo "File\tPassQC\tColumns\tRows\tSeparator"
  for file in @(docArgs["<FILE>"]):
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
          if bestFile.columns < check.columns:
            bestFile = check
    
    if bestFile.valid == true:
      okFiles += 1
      validFiles.add((file, bestFile.sepchar))
    else:
      badFiles += 1
    if not doInspect:
      echo file, "\t", bestFile.toString(printHeader)
  if docArgs["--verbose"]:
    stderr.writeLine(okFiles, " valid. ", badFiles, " non-valid files.")
  
  if badFiles > 0:
    return 1

  # Inspect?
  if doInspect:
    if printHeader:
      echo "File\tColID\tColName\tTypes\tTopItem\tTopRatio"
    for fileInfo in validFiles:
      checkColumns(fileInfo[0], fileInfo[1], commentChar)

  return 0

proc seqfuTabcheck*(args: var seq[string]): int =
  return tabcheck(args, "tabcheck")


when isMainModule:
  var cmdArgs = commandLineParams()
  let exitCode = tabcheck(cmdArgs, "fu-tabcheck")
  quit(exitCode)
