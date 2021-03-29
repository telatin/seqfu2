import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import colorize


proc rangesToTable(ranges: Table[string, tuple[rangeStart, rangeEnd: int]]): Table[int, string] =
  echo "OK"

proc rangeToStr(min, max: int, t: Table[string, tuple[rangeStart, rangeEnd: int]]): string =
  result = ""
  for x,y in t:
    if min >= y.rangeStart and max <= y.rangeEnd:
      result &= x & ";"
  if result == "":
    result = "Invalid Range"
  
proc qualityProfile(sum,cnt: seq[int]): string =
  for i, quality in sum:
    if cnt[i] < 1:
      break
    let avg = quality / cnt[i]
    result &= qualToChar(int(avg))
    
    

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
  -l, --maxlen INT       Maximum read length [default: 300]
  -p, --profile          Print graphical average quality profile
  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    let
      maxSeqs = parseInt($args["--max"])
      maxLen  = parseInt($args["--maxlen"])

    for file in @(args["<FASTQ>"]):
      if args["--verbose"]:
        stderr.writeLine("Parsing: ", file)
      
      var count = 0
      var min, max: int 

      if not fileExists(file):
        stderr.writeLine("ERROR: File not found: ", file)
        continue
         
      try:
        var
          sumSeq = newSeq[int]()
          cntSeq = newSeq[int]() 

        for i in 0 .. maxLen:
          sumSeq.add(0)
          cntSeq.add(0)   

        for record in readfq(file):
          count += 1
          if count > maxSeqs:
            break
          for i, q in record.quality:
            if count == 1:
              min = q.ord
              max = min
            else:
              if min > q.ord:
                min = q.ord
              if max < q.ord:
                max = q.ord
            cntSeq[i] += 1
            sumSeq[i] += charToQual(q)

        let encodingType = rangeToStr(min, max, ranges)
        
        echo(file, "\t", min, "\t", max, "\t", encodingType)
        if args["--profile"]:
          let profile = qualityProfile(sumSeq, cntSeq)
          echo qualToUnicode(profile, @[1, 10, 20, 25, 30, 35, 40], true)
      except Exception as e:
        stderr.writeLine("Error parsing ", file, ": ", e.msg)