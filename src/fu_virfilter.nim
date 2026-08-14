import docopt
import readfq
import os, parsecsv, sets, strutils

const NimblePkgVersion {.strdefine.} = "undef"

let
  programName = "fu-filter"
   
proc columnIndex(headers: seq[string], column: string): int =
  for i, header in headers:
    if header.strip() == column:
      return i
  return -1

proc requireColumn(headers: seq[string], column: string): int =
  result = headers.columnIndex(column)
  if result < 0:
    stderr.writeLine("Error: VirFinder table is missing required column: ", column)
    quit(1)

proc field(row: seq[string], idx: int, column: string, line: int): string =
  if idx >= row.len:
    stderr.writeLine("Error: missing value for column ", column, " at row ", line)
    quit(1)
  result = row[idx].strip()

proc readVirfinderNames(filename: string, sep: char, minscore, maxpval: float,
                        minlen, maxlen: int, totalRows: var int): seq[string] =
  var parser: CsvParser
  parser.open(filename, separator = sep)
  defer: parser.close()

  parser.readHeaderRow()
  let
    nameIdx = parser.headers.requireColumn("name")
    scoreIdx = parser.headers.requireColumn("score")
    pvalueIdx = parser.headers.requireColumn("pvalue")
    lengthIdx = parser.headers.requireColumn("length")

  while parser.readRow():
    inc totalRows
    let line = parser.processedRows()
    try:
      let
        score = parser.row.field(scoreIdx, "score", line).parseFloat()
        pvalue = parser.row.field(pvalueIdx, "pvalue", line).parseFloat()
        length = parser.row.field(lengthIdx, "length", line).parseInt()

      if score > minscore and pvalue < maxpval and length > minlen and length < maxlen:
        result.add(parser.row.field(nameIdx, "name", line).split(" ")[0].replace("\"", ""))
    except ValueError as e:
      stderr.writeLine("Error: invalid numeric value in VirFinder table at row ", line, ": ", e.msg)
      quit(1)

proc main(): int =
  let args = docopt("""
  Usage: fu-virfilter [options] <virfinder> <fasta>

  Files:
    <virfinder>                VirFinder output file (csv format)
    <fasta-file>               FASTA file to filter

  Options:
    -p, --max-pvalue FLOAT     Maximum p-value to keep [default: 0.05]
    -s, --min-score FLOAT      Minimum score [default: 0.90]
    --min-len INT              Minimum length [default: 100]
    --max-len INT              Maximum length [default: 1000000]

  Other options:
    --sep CHAR                 Separator [default: ,]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=NimblePkgVersion, argv=commandLineParams())

  #check parameters
  try:
    discard parseFloat($args["--max-pvalue"])
    discard parseFloat($args["--min-score"])
    discard parseInt($args["--min-len"])
    discard parseInt($args["--max-len"])
  except Exception as e:
    stderr.writeLine("Error in parameters: invalid number(s).", e.msg)
    quit(1)

  let
    minscore = parseFloat($args["--min-score"])
    maxpval  = parseFloat($args["--max-pvalue"])
    minlen   = parseInt($args["--min-len"])
    maxlen   = parseInt($args["--max-len"])

  # Check input files
  if not fileExists($args["<virfinder>"]):
    stderr.writeLine("Error: unable to find virfinder table: ", $args["<virfinder>"])
    quit(1)
  else:
    if args["--verbose"]:
      stderr.writeLine("Reading virfinder table: ", $args["<virfinder>"])

  if not fileExists($args["<fasta>"]):
    stderr.writeLine("Error: unable to find virfinder table: ", $args["<fasta>"])
    quit(1)
    
  
  let sepText = $args["--sep"]
  if sepText.len != 1:
    stderr.writeLine("Error: --sep must be exactly one character")
    quit(1)

  var totalRows = 0
  let sequenceToKeep = readVirfinderNames($args["<virfinder>"], sepText[0],
                                          minscore, maxpval, minlen, maxlen,
                                          totalRows)
  if args["--verbose"]:
    stderr.writeLine "Filtered rows: ", sequenceToKeep.len, "/", totalRows

  var keepSet = initHashSet[string]()
  for name in sequenceToKeep:
    keepSet.incl(name)

  var
    total = 0
    c = 0
  for record in readfq($args["<fasta>"]):
    total = total + 1
    if record.name in keepSet:
      c = c + 1
      stdout.writeLine(record)

  if c != len(sequenceToKeep):
    stderr.writeLine("ERROR: printed less sequences than expected: ", c, "/", len(sequenceToKeep), " (total sequences in file: ", total, ")")
    quit(1)
when isMainModule:
  discard main()
