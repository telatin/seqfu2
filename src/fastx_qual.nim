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
    
    

proc getStopPos(s: seq[RunningStat], w: int, minq, wndq: float, debug: bool): int =
  
  for i, stats in s:
    let max = if i + w - 1 <= len(s): i + w - 1
          else: len(s)
    if stats.n == 0:
      return i
    var
      wnd = 0.0
      c = 0
    for j in i .. max:
      wnd += s[j].mean
      c += 1

    if debug:
      echo "#DEBUG\t", i, "\t", wnd, "\t", c, "\t", s[i].mean, "<", minq , "\t", (wnd / float(c)), "<", wndq
    if s[i].mean < minq:
      return i

    if wnd / float(c) < wndq:
      return i
    
   
proc fastx_qual(argv: var seq[string]): int =
    var ranges = initTable[string, tuple[rangeStart, rangeEnd: int]]()
    ranges["Illumina-1.8"] = (33, 74)
    ranges["Illumina-1.3"] = (64, 104)
    ranges["Illumina-1.5"] = (66, 105)
    ranges["Solexa"] = (59, 104)
    ranges["Sanger"] = (33, 73)

    let args = docopt("""
Usage: qual [options] [<FASTQ>...] 

Quickly check the quality of input files returning the detected encoding 
and the profile of quality scores. 
To read from STDIN, use - as filename.

  -m, --max INT          Check the first INT reads [default: 5000]
  -l, --maxlen INT       Maximum read length [default: 1000]
  -k, --skip INT         Print one sequence every INT [default: 1]

Qualified position:
  -w, --wnd INT          Sliding window size [default: 4]
  -q, --wnd-qual FLOAT   Minimum quality in the sliding window [default: 28.5]
  -z, --min-qual FLOAT   Stop the sliding windows when quality is below [default: 18.0]   

Additional output:
  --gc                   Print GC content as extra column
  -p, --profile          Quality profile per position (will comment the summary lines)
  -c, --colorbars        Print graphical average quality profile

Other options:
  -v, --verbose          Verbose output
  -O, --offset INT       Quality encoding offset [default: 33]
  --debug                Debug mode
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    if bool(args["--debug"]):
      stderr.writeLine args
    let
      debug      = bool(args["--debug"])
      addGC      = args["--gc"]
      skip       = parseInt($args["--skip"])
      qualOffset = parseInt($args["--offset"])
      wndSize = parseInt($args["--wnd"])
      minQual = parseFloat($args["--min-qual"])
      wndQual = parseFloat($args["--wnd-qual"])
      maxSeqs = parseInt($args["--max"])
      maxLen  = parseInt($args["--maxlen"])
      comment = if args["--profile"]: "#"
                else: ""
    
    if len(  @(args["<FASTQ>"]) ) == 0:
      stderr.writeLine("No files specified. Use '-' to read STDIN, --help for help.")
    for file in @(args["<FASTQ>"]):
      var
        totalLength = 0
        totalGC = 0

      if args["--verbose"]:
        stderr.writeLine("Parsing: ", file)
      
      var
        count = 0
        readnum = 0
      if not fileExists(file) and file != "-":
        stderr.writeLine("ERROR: File not found: ", file)
        continue
         
      try:
        var
          sttSeq = newSeq[RunningStat](maxLen + 1)
          stats: RunningStat

        for record in readfq(file):
          readnum += 1
          var
            modulo = readnum mod skip  

          if modulo > 0:
            continue

          # Printed total reads
          if count >= maxSeqs:
            break
          
          count += 1

          if addGC:
            totalGC += count_gc(record.sequence)
            totalLength += len(record.sequence)

          for i, q in record.quality:
            if i > maxLen:
              break
            let 
              quality_ord = q.ord
              quality_enc = charToQual(q)
            sttSeq[i].push(quality_enc)
            stats.push(quality_ord - qualOffset)


        # End parsing file

        let encodingType = rangeToStr(stats.min + float(qualOffset), stats.max + float(qualOffset), ranges)
        let stopPos = getStopPos(sttSeq, wndSize, minQual, wndQual, debug)        
        
        # Generate GC column if required
        let gcColumn = if addGC: "\t" &  fmt"{float(totalGC) / float(totalLength):.5f}"
                       else: ""
 
        # Comment "#" if needed
        echo(comment, file, "\t", stats.min, "\t", stats.max, "\t", encodingType, "\t", fmt"{stats.mean:.2f}+/-{stats.standardDeviationS:.2f}", "\t", stopPos, gcColumn)
        
        # Color profile
        # ▇▇▇▇▇▇▇▇▇▇▇▇▆▆▆▇▇▇▇▇▆▆▆▇▇▇▇▇▇▇▆▆▆▆▆▆▆▆▇▇▆▆▆▆▆▆▆▆▆▆▆▆▆▅▆▆▆▆▅▆▆▆▆▆▆▅...
        if args["--colorbars"]:
          let profile = qualityProfile(sttSeq)
          echo "#",  qualToUnicode(profile, @[1, 5, 10, 15, 20, 30, 40], true)

        # Print long profile
        if args["--profile"]:
          echo("#Pos\tMin\tMax\tMean\tStDev\tSkewness")
          var profString = ""
          for pos, stats in sttSeq:
            if stats.n == 0:
              continue
            profString &= fmt"{pos}" & "\t" & fmt"{stats.min:.1f}" & "\t" & fmt"{stats.max:.1f}" & "\t" & fmt"{stats.mean:.2f}" & "\t" & fmt"{stats.standardDeviationS:.2f}" & "\t" & fmt"{stats.skewness:.2f}" & "\n"
          echo profString

        if verbose:
          stderr.writeLine("Parsed ", count, " reads from ", file)

        
      except Exception as e:
        stderr.writeLine("Error parsing ", file, ": ", e.msg)