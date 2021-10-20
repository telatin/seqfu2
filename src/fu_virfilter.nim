import docopt
import readfq
import os, strutils 
import datamancer 
 
 

const NimblePkgVersion {.strdefine.} = "undef"

let
  programName = "fu-filter"
   

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
    
  
  var df = readCsv($args["<virfinder>"])

 
  
  let filtered = df.filter(f{ `score` > minscore and `pvalue` < maxpval and `length` > minlen and `length` < maxlen })
  if args["--verbose"]:
    stderr.writeLine "Filtered rows: ", filtered.high(), "/", df.high()

  var 
    sequenceToKeep = newSeq[string]()
  for row in filtered:
    let name = ($(row["name"])).split(" ")[0].replace("\"", "")
    sequenceToKeep.add(name)

  var
    total = 0
    c = 0
  for record in readfq($args["<fasta>"]):
    total = total + 1
    if record.name in sequenceToKeep:
      c = c + 1
      stdout.writeLine(record)

  if c != len(sequenceToKeep):
    stderr.writeLine("ERROR: printed less sequences than expected: ", c, "/", len(sequenceToKeep), " (total sequences in file: ", total, ")")
    quit(1)
when isMainModule:
  discard main()
