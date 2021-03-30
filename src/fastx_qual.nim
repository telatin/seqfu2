import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import strformat
import stats

proc rangesToTable(ranges: Table[string, tuple[rangeStart, rangeEnd: int]]): Table[int, string] =
  echo "OK"

proc rangeToStr(min, max: float, t: Table[string, tuple[rangeStart, rangeEnd: int]]): string =
  result = ""
  for x,y in t:
    if min >= float(y.rangeStart) and max <= float(y.rangeEnd):
      result &= x & ";"
  if result == "":
    result = "Invalid Range"
  
proc qualityProfile(s: seq[RunningStat]): string =
  for i, stats in s:
    if stats.n == 0:
      break
    result &= qualToChar(int(stats.mean))
    
    

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
  -l, --maxlen INT       Maximum read length [default: 1000]
  -p, --profile          Quality profile per position
  -c, --colorbars        Print graphical average quality profile
  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    let
      maxSeqs = parseInt($args["--max"])
      maxLen  = parseInt($args["--maxlen"])
      comment = if args["--profile"]: "#"
                else: ""
    for file in @(args["<FASTQ>"]):
      if args["--verbose"]:
        stderr.writeLine("Parsing: ", file)
      
      var count = 0
 

      if not fileExists(file):
        stderr.writeLine("ERROR: File not found: ", file)
        continue
         
      try:
        var

          sttSeq = newSeq[RunningStat](maxLen + 1)
          stats: RunningStat
        for record in readfq(file):
          count += 1
          if count > maxSeqs:
            break
          for i, q in record.quality:
            let 
              quality_ord = q.ord
              quality_enc = charToQual(q)
            sttSeq[i].push(quality_enc)
            stats.push(quality_ord)
        let encodingType = rangeToStr(stats.min, stats.max, ranges)
        

        echo(comment, file, "\t", stats.min, "\t", stats.max, "\t", encodingType, "\t", fmt"{stats.mean:.2f}+/-{stats.standardDeviationS:.2f}")
        if args["--colorbars"]:
          let profile = qualityProfile(sttSeq)
          echo "#",  qualToUnicode(profile, @[1, 10, 20, 25, 30, 35, 40], true)


        if args["--profile"]:
          echo("#Pos\tMin\tMax\tMean\tStDev\tSkewness")
          var profString = ""
          for pos, stats in sttSeq:
            if stats.n == 0:
              continue
            profString &= fmt"{pos}" & "\t" & fmt"{stats.min:.1f}" & "\t" & fmt"{stats.max:.1f}" & "\t" & fmt"{stats.mean:.2f}" & "\t" & fmt"{stats.standardDeviationS:.2f}" & "\t" & fmt"{stats.skewness:.2f}" & "\n"
          echo profString

        
      except Exception as e:
        stderr.writeLine("Error parsing ", file, ": ", e.msg)