import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils



proc rangesToTable(ranges: Table[string, tuple[rangeStart, rangeEnd: int]]): Table[int, string] =
  echo "OK"

proc rangeToStr(min, max: int, t: Table[string, tuple[rangeStart, rangeEnd: int]]): string =
  result = ""
  for x,y in t:
    if min >= y.rangeStart and max <= y.rangeEnd:
      result &= x & ";"
  if result == "":
    result = "Invalid Range"
  

proc fastx_qual(argv: var seq[string]): int =
    var ranges = initTable[string, tuple[rangeStart, rangeEnd: int]]()
    ranges["Illumina-1.8"] = (33, 74)
    ranges["Illumina-1.3"] = (64, 104)
    ranges["Illumina-1.5"] = (66, 105)
    ranges["Solexa"] = (59, 104)
    ranges["Sanger"] = (33, 73)

    let args = docopt("""
Usage: qual [options] [<FASTQ>...] 

Quickly check the quality of input files returning
the detected encoding and the profile of quality
scores

Options:
  -m, --max INT          Check the first INT reads [default: 2000]

  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    let
      maxSeqs = parseInt($args["--max"])

    for file in @(args["<FASTQ>"]):
      if args["--verbose"]:
        stderr.writeLine("Parsing: ", file)
      
      var count = 0
      var min, max: int 

      if not fileExists(file):
        stderr.writeLine("ERROR: File not found: ", file)
        continue
         
      try:        
        for record in readfq(file):
          count += 1
          if count > maxSeqs:
            break
          for q in record.quality:
            if count == 1:
              min = q.ord
              max = min
            else:
              if min > q.ord:
                min = q.ord
              if max < q.ord:
                max = q.ord
        let encodingType = rangeToStr(min, max, ranges)
        echo(file, "\t", min, "\t", max, "\t", encodingType)
      except Exception as e:
        stderr.writeLine("Error parsing ", file, ": ", e.msg)