import parsecsv
import docopt
import os
import tables
import strutils
import zip/gzipfiles
import threadpool
import nimdata
const NimblePkgVersion {.strdefine.} = "undef"
const version = if NimblePkgVersion == "undef": "<prerelease>"
                else: NimblePkgVersion



proc loadKrakenFromFile(f: string): bool = 
  const krakenSchema = [
    strCol("class"),
    strCol("read"),
    intCol("taxonomy"),
    intCol("readlen"),
    strCol("classification")
  ]
  let dfRawText = DF.fromFile(f).map(schemaParser(krakenSchema, '\t'))
  echo dfRawText.count()
  echo dfRawText.filter(record => record.class == "C").unique().count()
  return true

proc countKraken(f: string): CountTable[int] =
  var parser: CsvParser
  try:
    let file = newGzFileStream(f)
    parser.open(file, f, separator = '\t')
    while readRow(parser):
      result.inc( parseInt(parser.row[2]) )
  except Exception as e:
    stderr.writeLine("ERROR: parsing ", f, ": ", e.msg)

proc main(): int =
  let args = docopt("""
  fu-kraken

  A program inspect TSV and CSV files, that must contain more than 1 column.
  Double quotes are considered field delimiters, if present.
  Gzipped files are supported natively.

  Usage: 
  fu-kraken [options] <FILE>...

  Options:
    --df                  use dataframe
    -s --separator CHAR   Character separating the values, 'tab' for tab and 'auto'
                          to try tab or commas [default: auto]
    -c --comment CHAR     Comment/Header char [default: #]
    --verbose             Enable verbose mode
  """, version=version, argv=commandLineParams())

  var
    responses = newSeq[ FlowVar[CountTable[int]] ]()

  for file in args["<FILE>"]:
    echo file
    if args["--df"]:
      discard loadKrakenFromFile(file)
    else:
      discard countKraken(file)
#[ 
  for file in args["<FILE>"]:
    if fileExists(file):
      responses.add(spawn countKraken(file))

  for resp in responses: # Iterates through each response
    #Blocks the main thread until the response can be read and then saves the response value in the statistics variable
    let counts = ^resp
     ]#
  return 0


when isMainModule:
  let exit = main()
  quit(exit)