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

 
 
proc main(): int =
  let args = docopt("""
  fu-kraken

  A program inspect TSV and CSV files, that must contain more than 1 column.
  Double quotes are considered field delimiters, if present.
  Gzipped files are supported natively.

  Usage: 
  fu-krakencounts [options] <FILE> 

  Options:
    --verbose             Enable verbose mode
  """, version=version, argv=commandLineParams())
  var
    parser: CsvParser
    hits = initCountTable[int]()
  try:
    let file = newGzFileStream($args["<FILE>"])
    parser.open(file, $args["<FILE>"], separator = '\t')
    while readRow(parser):
      hits.inc( parseInt(parser.row[2]) )
  except Exception as e:
    stderr.writeLine("ERROR: parsing ", $args["<FILE>"], ": ", e.msg)


  for k,v in hits:
    echo k, "\t", v



when isMainModule:
  let exit = main()
  quit(exit)