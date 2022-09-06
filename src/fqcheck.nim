import docopt
import readfq
import times
import os
import tables
import strutils

import ./seqfu_utils
 

 
type
  FQcheck* = tuple
    filename: string
    firstSeqName: string
    lastSeqName: string
    seqCount: int
    bpCount: int
    isValid: bool
    
proc namesMatch(a, b: string): bool =
  if a == b:
    return true
  elif a[0 .. a.len - 2] == b[0 .. b.len - 2]:
    return true
  else:
    return false

proc checkFqFile(filename: string): FQcheck =
  let DNA = "ACGTN"
  result.filename = filename
  result.isValid = true
  if not fileExists(filename):
    result.isValid = false
    return
  var
    c = 0
    bp = 0
    name = ""
  for read in readfq(filename):
    c += 1
    if c == 1:
      result.firstSeqName = read.name
    name = read.name

    if len(read.sequence) != len(read.quality):
      result.isValid = false

    for c in read.sequence.toUpper():
      if c notin DNA:
        result.isValid = false

    bp += len(read.sequence)
  
  result.seqCount = c
  result.bpCount = bp
  result.lastSeqName = name
  

  
proc detectPairedFile(filename: string): string =
  let
    tags = @["_R1.", "_R1_", "_1.", "_1_", "_1"]
    forfile = extractFilename(filename)
    dirname = parentDir(filename)

  for fortag in tags:
    let
      revtag = fortag.replace("1", "2")
      revfile = forfile.replace(fortag, revtag)
      fullrevfile = joinPath(dirname,revfile)
    if revfile != forfile and fileExists(fullrevfile):
      return fullrevfile
  
  return ""



#proc fastx_metadata(argv: var seq[string]): int =
proc fqcheck(args: var seq[string]): int {.gcsafe.} =
  let args = docopt("""
  Usage:
    fqcheck [options] FQFILE [REV]

  Check the integrity of FASTQ files

  Other options:
    -n, --no-paired            Autodetect second pair
    -p, --print-info           Print final check info
    -v, --verbose              Verbose output
    -h, --help                 Show this help
  """, version=version(), argv=commandLineParams())

  #check parameters
  let
    startTime = cpuTime()
    autoRev = detectPairedFile($args["FQFILE"])
    reverse = if ($args["REV"] != "nil"): $args["REV"]
              elif ($args["REV"] == "nil" and autoRev != "" and not args["--no-paired"]): autoRev
              else: ""

    libtype = if reverse == "": "SE"
              else: "PE"
  

  let
    forCheck = checkFqFile($args["FQFILE"])
    revCheck : FQcheck = if libtype == "PE": checkFqFile(reverse)
               else: (filename: "", firstSeqName: "", lastSeqName: "", seqCount: 0, bpCount: 0, isValid: true)

  if libtype == "SE":
    if args["--verbose"]:
      stderr.writeLine forCheck
    if not forCheck.isValid:
      return 1
  else:
    if args["--verbose"]:
      stderr.writeLine "Files:     ", forCheck.filename, ",", revCheck.filename
      stderr.writeLine "First seq: ", forCheck.firstSeqName, ",", revCheck.firstSeqName
      stderr.writeLine "Last seq:  ", forCheck.lastSeqName, ",", revCheck.lastSeqName
      stderr.writeLine "Seq count: ", forCheck.seqCount, ",", revCheck.seqCount
      stderr.writeLine "BP count:  ", forCheck.bpCount, ",", revCheck.bpCount, " (ignored)"


      let
        totalTime = cpuTime() - startTime
      if totalTime > 0:
          let speed = int(float(forCheck.seqCount + revCheck.seqCount) / totalTime)
          stderr.writeLine("Processed ", forCheck.seqCount + revCheck.seqCount, " reads in ", totalTime, " seconds (", speed, " reads/sec)")
      
    var
      errors = 0
    if forCheck.filename == revCheck.filename:
      echo "Error: forward and reverse files are the same"
      errors += 1


    if forCheck.seqCount != revCheck.seqCount:
      echo "Error: sequence counts do not match"
      errors += 1

    if not namesMatch(forCheck.firstSeqName, revCheck.firstSeqName):
      echo "Error: first sequence names do not match"
      errors += 1
    elif not namesMatch(forCheck.lastSeqName, revCheck.lastSeqName):
      echo "Error: last sequence names do not match"
      errors += 1
    if not forCheck.isValid or not revCheck.isValid:
      errors += 1
    if forCheck.seqCount != revCheck.seqCount:
      echo "ERROR: Sequence count mismatch: ", forCheck.seqCount, " != ", revCheck.seqCount
      errors += 1
    
    let status = if errors == 0: "OK"
                 else: "ERROR"
    if args["--print-info"]:
      echo status, "\t", args["FQFILE"]

    return errors

when isMainModule:
  main_helper(fqcheck)
