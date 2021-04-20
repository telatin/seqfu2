import parsecsv, strutils, strformat
import docopt
import os
import md5
import posix
import ./seqfu_utils

let version = "1.0"

proc compare(x, y: string, maxMismatches: int): bool =
  if len(x) != len(y):
    return false
  var
    mismatches = 0
  
  if x == y:
    return true

  for i in 0 .. x.high:
    if x[i] != y[i]:
      mismatches += 1
      if mismatches > maxMismatches:
        return false
  return true


proc combine(x, y: string, maxMismatches: int): string =
  if maxMismatches == 0:
    for i in 0 .. x.high:
      let
        xSlice =  x[i .. y.high]
        ySlice =  y[0 .. min(xSlice.high, y.high)]
      if xSlice == ySlice:
        return x[0 ..< i] & y
    return ""
  else:
    for i in 0 .. x.high:
      let
        xSlice =  x[i .. y.high]
        ySlice =  y[0 .. min(xSlice.high, y.high)]
      if compare(xSlice, ySlice, maxMismatches):
        echo ">", x[0 ..< i] & y
        echo "<", x
        return x[0 ..< i] & y
    return ""
  
proc main(argv: var seq[string]): int =
  let args = docopt("""
  Combine pairs in DADA2 unmerged tables

  Usage: 
  dadaist2-mergeseqs [options] -i dada2.tsv 

  Options:
    -i, --input-file FILE      FASTA or FASTQ file
    -f, --fasta FILE           Write new sequences to FASTA
    -p, --pair-spacer STRING   Pairs separator [default: NNNNNNNNNN]
    -s, --strip STRING         Remove this string from sample names
    -n, --seq-name STRING      Sequence string name [default: MD5]
    -m, --max-mismatches INT   Maximum allowed mismatches [default: 0]
    --id STRING                Features column name [default: #OTU ID]
    --verbose                  Print verbose output

  """, version=version, argv=argv)

  
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  let
    input_file = $args["--input-file"]

  var
    fastaOut = newSeq[string]()

  if args["--verbose"] and $args["--fasta"] != "nil":
    stderr.writeLine("FASTA sequences will be saved to ",$args["--fasta"] , "with name: ", $args["--seq-name"])
  # Check input file existence
  if not fileExists(input_file):
    stderr.writeLine("ERROR: Input file not found: ", input_file)
    return 1

 
  # TSV parser
  var p: CsvParser
  try:
    p.open(filename=input_file, separator='\t')
    p.readHeaderRow()
  except Exception as e:
    stderr.writeLine("ERROR: Unable to parse ", input_file, "\n", e.msg)
    quit(1)


  # Check header
  if args["--verbose"]:
    if $args["--id"] notin p.headers:
      stderr.writeLine("ERROR: ", $args["--id"], " not found in the input header line.")
      quit(1)
    stderr.writeLine("Header: ", (p.headers).join(","))
  
  for i in 1 .. (p.headers).high:
    p.headers[i] = (p.headers[i]).replace($args["--strip"], "")

  # Output: header
  echo (p.headers).join("\t")

  let
    maxMismatches = parseInt($args["--max-mismatches"])
  var
    counter = 0
    joined = 0
    split = 0

  while p.readRow():
    counter += 1
    var
      repSeq = p.rowEntry($args["--id"])
      merge: string
    let
      fragments = repSeq.split($args["--pair-spacer"])

    if fragments.high == 1:
      merge = combine(fragments[0], fragments[1], maxMismatches)
      split += 1
    elif args["--verbose"]:
      stderr.writeLine("Sequence not splittable at ", counter)
    
    if len(merge) > 0:
      p.rowEntry($args["--id"]) = merge
      joined += 1

    if $args["--fasta"] != "nil":
      let sName = if $args["--seq-name"] == "MD5": $toMD5(p.rowEntry($args["--id"]))
                  else: $args["--seq-name"] & $counter
      fastaOut.add( '>' & sName & "\n" & p.rowEntry($args["--id"]) ) 

    #for col in items(p.headers):
    #  echo col, ": ", p.rowEntry(col)
    echo (p.row).join("\t")

  # Write fasta?
  if $args["--fasta"] != "nil":
    try:
      let f = open($args["--fasta"], fmWrite)
      defer: f.close()
      f.writeLine(fastaOut.join("\n"))
    except Exception as e:
      stderr.writeLine("ERROR: Unable to write file to: ", $args["--fasta"], "\n", e.msg)
      quit(1)

  if args["--verbose"]:
    stderr.writeLine(fmt"Total:{counter};Split:{split};Joined:{joined}")

when isMainModule:
  main_helper(main)