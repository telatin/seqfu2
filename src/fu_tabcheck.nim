import parsecsv
import docopt
import os
import tables
import algorithm
import zip/gzipfiles

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
    errormsg: string

proc `$`(s: checkResult): string =
  if s.valid:
    result &= "Pass\t"
  else:
    result &= "Error"
    return
  
  result &= $(s.columns) & "\t" & $(s.records) & "\tseparator=" & s.sep

proc checkFile(f: string, sep: char, header: char): checkResult =
  var parser: CsvParser

  if sep == '\t':
    result.sep = "<tab>"
  elif sep == ' ':
    result.sep = "<space>"
  else:
    result.sep = $sep

  var
    total_lines = 0
    col_per_line = initCountTable[int]()
  try:
    let file = newGzFileStream(f)
    parser.open(file, f, separator = sep)
    while readRow(parser):
      total_lines += 1
      col_per_line.inc( len(parser.row) )
    col_per_line.sort()

    if len(col_per_line) == 1:
      result.valid = true
      for cols, lines in col_per_line:
        if cols == 1:
          result.valid = false
          return
        result.columns = cols
        result.records = lines
    else:
      result.valid = false
      return
    return
  except Exception as e:
    stderr.writeLine("ERROR: parsing ", f, ": ", e.msg)

proc main(): int =
  let args = docopt("""
  fu-tabcheck

  A program inspect TSV and CSV files, that must contain more than 1 column.
  Double quotes are considered field delimiters, if present.
  Gzipped files are supported natively.

  Usage: 
  fu-tabcheck [options] <FILE>...

  Options:
    -s --separator CHAR   Character separating the values, 'tab' for tab and 'auto'
                          to try tab or commas [default: auto]
    -c --comment CHAR     Comment/Header char [default: #]
    --verbose             Enable verbose mode
  """, version=version, argv=commandLineParams())


  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  
  var
    sepList = newSeq[char]()
    commentChar = $args["--comment"]
  if $args["--separator"] == "auto":
    sepList.add("\t")
    sepList.add(",")
  elif $args["--separator"] == "tab":
    sepList.add("\t")
  else:
    sepList.add(  $args["--separator"] )

  let
    separators = sepList
  
  if args["--verbose"]:
    stderr.writeLine("Separator: ", separators)
  # Prepare the 
  # Process file read by read

  var
    okFiles = 0
    badFiles = 0
  for file in @(args["<FILE>"]):
    var
      bestFile: checkResult
    if args["--verbose"]:
      stderr.writeLine("Parsing ", file)

    for sepChar in separators:
      let check = checkFile(file, sepChar, commentChar[0])
      if args["--verbose"]:
        echo "<", sepChar, "> ", check
      if check.valid == true:
        if bestFile.columns < check.columns:
          bestFile = check
    
    if bestFile.valid == true:
      okFiles += 1
    else:
      badFiles += 1
    echo file, "\t", bestFile
  if args["--verbose"]:
    stderr.writeLine(okFiles, " valid. ", badFiles, " non-valid files.")
  
  if badFiles > 0:
    return 1

  return 0


when isMainModule:
  let exit = main()
  quit(exit)