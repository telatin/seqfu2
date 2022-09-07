import docopt
import readfq
import times
import os
import tables
import strutils
import strformat
import ./seqfu_utils
 

 
type
  FQcheck* = tuple
    filename: string
    firstSeqName: string
    lastSeqName: string
    firstSeq: string
    lastSeq: string
    seqCount: int
    bpCount: int
    isValid: bool
    errors: string
 
proc namesMatch(a, b: string): bool =
  let
    MINLEN = 4
  if a == b:
    return true
  else:
    for PAD in 1 .. 3:
      if a[0 .. a.len - PAD] == b[0 .. b.len - PAD]:
        if len(a[0 .. a.len - PAD]) > MINLEN:
          return true
        else:
          return false
  return false

proc checkFqFile(filename: string): FQcheck =
  let DNA = "ACGTN"
  result.filename = filename
  result.isValid = true
  result.errors = ""
  if not fileExists(filename):
    result.errors = "File does not exist;"
    result.isValid = false
    return
  var
    c = 0
    bp = 0
    name = ""
    read_sequence = ""
  for read in readfq(filename):
    c += 1
    if result.isValid == false:
      result.seqCount = -1
      result.bpCount = -1
      # Premature exit
      return
    if c == 1:
      result.firstSeqName = read.name
      result.firstSeq = read.sequence
    name = read.name
    read_sequence = read.sequence
    if len(read.sequence) != len(read.quality):
      result.errors = "Sequence and quality strings are not the same length at: " & name & ";"
      result.isValid = false

    for c in read.sequence.toUpper():
      if c notin DNA:
        result.errors &= "Invalid character in sequence: <" & c & "> in " & name & ";"
        result.isValid = false

    bp += len(read.sequence)
  
  result.seqCount = c
  result.bpCount = bp
  result.lastSeqName = name
  result.lastSeq = read_sequence
  
proc checkPairedFiles(fwdFile, revFile: string): FQcheck =
  let
    fwd = checkFqFile(fwdFile)
    rev = checkFqFile(revFile)
  
  result.isValid = true
  result.errors = ""

  result.filename = fwd.filename & ";" & rev.filename

  # Check individual files
  if fwd.isValid == false:
    result.isValid = false
    result.errors  &= "R1=" & fwd.errors & ";"
  if rev.isValid == false:
    result.isValid = false
    result.errors  &= "R2=" & rev.errors & ";"

  # Check number of sequences
  if fwd.isValid and rev.isValid and fwd.seqCount != rev.seqCount:
    result.isValid = false
    result.seqCount = -1
    result.errors &= fmt"Number of sequences in R1 and R2 do not match ({fwd.seqCount}, {rev.seqCount});"
  else:
    result.seqCount = fwd.seqCount + rev.seqCount

  if fwd.isValid and rev.isValid:
    result.bpCount = fwd.bpCount + rev.bpCount
  else:
    result.bpCount = -1
  # Check sequence names
  if not namesMatch(fwd.firstSeqName, rev.firstSeqName):
    result.isValid = false
    result.errors &= fmt"First sequence names do not match ({fwd.firstSeqName}, {rev.firstSeqName});"

  if not namesMatch(fwd.lastSeqName, rev.lastSeqName):
    result.isValid = false
    result.errors &= fmt"Last sequence names do not match ({fwd.lastSeqName}, {rev.lastSeqName});"
  
  # Check pairs are not equal
  if fwd.firstSeq == rev.firstSeq and fwd.lastSeq == rev.lastSeq and fwd.seqCount > 0:
    result.isValid = false
    result.errors &= fmt"First and last sequences are identical in R1 and R2;";

  return
  
  
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

proc gatherFqFiles(dir: string, no_paired: bool): (seq[string], seq[string]) =
  let
    fqext = @[".fq", ".fastq", ".fq.gz", ".fastq.gz"]
    fwd   = @["_R1_", "_R1.", "_1.", "_1_"]
    rev   = @["_R2_", "_R2.", "_2.", "_2_"]
  var
    files:     seq[string]
    singleEnd: seq[string]
    pairedEnd: seq[string]
    used:      seq[string]
  for kind, path in walkDir(dir):
    if kind != pcDir and kind != pcLinkToDir: #pcFile pcLinkToFile, pcLinkToDir
      for ext in fqext:
        if ext in path.toLower() and  path notin files:
          files.add(path)
  if no_paired == true:
    singleEnd = files
    return (singleEnd, pairedEnd)


  for forfile in files.sorted():
    let 
      basename = extractFilename(forfile)
      dirname = parentDir(forfile)
    var
      paired = false
    for i, fortag in fwd:
      if fortag in basename:
        let 
          revbase = basename.replace(fortag, rev[i])
          revfile = joinPath(dirname, revbase)
        if revfile in files:
          #files.delete(files.find(forfile))
          #files.delete(files.find(revfile))
          pairedEnd.add(forfile & ";" & revfile)
          paired = true
          used.add(forfile)
          used.add(revfile)
    if paired == false and forfile notin used:
      singleEnd.add(forfile)
  return (singleEnd, pairedEnd)



proc toString(fq: FQcheck, nice: bool): string =
  let
    paired = if len(fq.filename.split(";")) == 2: true
             else: false
    status = if fq.isValid == true: "OK"
             else: "ERR"
    libtag = if paired == true: "PE"
             else: "SE"
    fname  = if paired == false: fq.filename
             else: fq.filename.split(";")[0] 
    errnum = if fq.isValid == true: 0
             else: len(fq.errors.split(";"))
    countStr = if fq.seqCount == -1: "-"
               elif nice: ($fq.seqCount).insertSep(',')
               else: $(fq.seqCount)
    bpStr = if fq.bpCount == -1: "-"
               elif nice: ($fq.bpCount).insertSep(',')
               else: $(fq.bpCount)
    
  status & "\t" & libtag & "\t" & fname & "\t" & countStr & "\t" & bpStr & "\t" & $errnum & "\t" & fq.errors

proc `$`(fq: FQcheck): string =
  return toString(fq, false)
#proc fastx_metadata(argv: var seq[string]): int =
proc fqcheck(args: var seq[string]): int {.gcsafe.} =
  let args = docopt("""
  Usage: seqfu check [options] <FQFILE> [<REV>]
       seqfu check [options] --dir <FQDIR>

  Check the integrity of FASTQ files, returns non zero
  if an error occurs. Will print a table with a report.

  Input is a single dataset:
    <FQFILE>                   the forward read file
    <REV>                      the reverse read file
  or a directory of FASTQ files (--dir):
    <FQDIR>                    the directory containing the FASTQ files

  Options:
    -n, --no-paired            Disable autodetection of second pair
    -s, --safe-exit            Exit with 0 even if errors are found
    -q, --quiet                Do not print infos, just exit status
    -v, --verbose              Verbose output 
    -t, --thousands            Print numbers with thousands separator
    --debug                    Debug output
    -h, --help                 Show this help
  """, version=version(), argv=commandLineParams())

  var
    errors = 0
    totseq = 0

  if bool(args["--debug"]):
    stderr.writeLine "#DEBUG_ARGS", args
  #check parameters
  let
    startTime = cpuTime()

  var
    seList, peList: seq[string]


  if bool(args["--dir"]):
    (seList, peList) = gatherFqFiles($args["<FQDIR>"], bool(args["--no-paired"]))
    if args["--debug"]:
      stderr.writeLine "#DEBUG_DIR ", $args["<FQDIR>"], ": ", len(seList), " SE files and ", len(peList), " PE files"
  else:
    let
      autoRev = detectPairedFile($args["<FQFILE>"])
      reverse = if ($args["<REV>"] != "nil"): $args["<REV>"]
                elif ($args["<REV>"] == "nil" and autoRev != "" and not args["--no-paired"]): autoRev
                else: ""
      libtype = if reverse == "": "SE"
                else: "PE"
    
    #let result = if libtype == "SE": checkFqFile($args["<FQFILE>"])
    #             else: checkPairedFiles($args["<FQFILE>"], reverse)
    if libtype == "SE":
      seList.add($args["<FQFILE>"])
    else:
      peList.add($args["<FQFILE>"] & ";" & reverse)
    
    if bool(args["--debug"]):
      stderr.writeLine "#DEBUG_SINGLE: ", len(seList), " SE files and ", len(peList), " PE files"
  
  if true:
    for file in seList:
      let 
        result = checkFqFile(file)
      if result.isValid == false:
        errors += 1
      totseq += result.seqCount
      echo result.toString(bool(args["--thousands"]))
    for file in peList:
      let 
        result = checkPairedFiles(file.split(";")[0], file.split(";")[1])
      if result.isValid == false:
        errors += 1
      totseq += result.seqCount
      echo result.toString(bool(args["--thousands"]))
    
    if args["--verbose"]:
      let
        totalTime = cpuTime() - startTime
         
      if totalTime > 0:
        let speed = if totalTime > 1: fmt"({int(float(totseq) / totalTime)} reads/s)"
                    else: ""
        stderr.writeLine(fmt"Processed {($totseq).insertSep(',')} reads in {totalTime:.2f} seconds {speed}")
    
    if bool(args["--safe-exit"]):
      if bool(args["--debug"]):
        stderr.writeLine "#DEBUG_SAFEEXIT: ", errors
      return 0
    else:
      return errors
#[ 

  let
    autoRev = detectPairedFile($args["<FQFILE>"])
    reverse = if ($args["<REV>"] != "nil"): $args["<REV>"]
              elif ($args["<REV>"] == "nil" and autoRev != "" and not args["--no-paired"]): autoRev
              else: ""
    libtype = if reverse == "": "SE"
              else: "PE"

  let
    forCheck = checkFqFile($args["<FQFILE>"])
    revCheck : FQcheck = if libtype == "PE": checkFqFile(reverse)
               else: (filename: "", firstSeqName: "", lastSeqName: "", firstSeq: "", lastSeq: "", seqCount: 0, bpCount: 0, isValid: true, errors: "")

  # Runtime infos
  if args["--verbose"]:
    let
      totalTime = cpuTime() - startTime
      totalSeq  = forCheck.seqCount + revCheck.seqCount
    if totalTime > 0:
      let speed = if totalTime > 1: fmt"({int(float(forCheck.seqCount + revCheck.seqCount) / totalTime)} reads/s)"
                  else: ""
      stderr.writeLine(fmt"Processed {($totalSeq).insertSep(',')} reads in {totalTime:.2f} seconds {speed}")
  
  if libtype == "SE":
    if args["--verbose"]:
      stderr.writeLine forCheck
    if not forCheck.isValid:
      errors += 1
  else:
    if not forCheck.isValid:
      if args["--verbose"]:
        stderr.writeLine fmt"Error: Forward file {forCheck.filename} is invalid"
      errors += 1
    if not revCheck.isValid:
      if args["--verbose"]:
        stderr.writeLine fmt"Error: Reverse file {forCheck.filename} is invalid"
      errors += 1
    # Individually check the pairs
    if forCheck.filename == revCheck.filename:
      stderr.writeLine fmt"Error: forward and reverse files are the same"
      errors += 1


    if forCheck.seqCount != revCheck.seqCount:
      stderr.writeLine fmt"Error: sequence counts do not match ({forCheck.seqCount} vs {revCheck.seqCount})"
      errors += 1

    if not namesMatch(forCheck.firstSeqName, revCheck.firstSeqName):
      stderr.writeLine fmt"Error: first sequence names do not match ({forCheck.firstSeqName} vs {revCheck.firstSeqName})"
      errors += 1
    elif not namesMatch(forCheck.lastSeqName, revCheck.lastSeqName):
      stderr.writeLine fmt"Error: last sequence names do not match ({forCheck.lastSeqName} vs {revCheck.lastSeqName})"
      errors += 1
    if not forCheck.isValid or not revCheck.isValid:
      errors += 1
    if forCheck.seqCount != revCheck.seqCount:
      stderr.writeLine fmt"ERROR: Sequence count mismatch: {forCheck.seqCount} vs {revCheck.seqCount}"
      errors += 1
  

    if args["--verbose"]:
      if errors > 0:
        stderr.writeLine "Files:     ", forCheck.filename,     ",", revCheck.filename
        stderr.writeLine "First seq: ", forCheck.firstSeqName, ",", revCheck.firstSeqName
        stderr.writeLine "Last seq:  ", forCheck.lastSeqName,  ",", revCheck.lastSeqName
        stderr.writeLine "Seq count: ", forCheck.seqCount,     ",", revCheck.seqCount
        stderr.writeLine "BP count:  ", forCheck.bpCount,      ",", revCheck.bpCount, " (ignored)"
      else:
        stderr.writeLine "Files:     ", forCheck.filename, ",", revCheck.filename
        stderr.writeLine "First seq: ", forCheck.firstSeqName 
        stderr.writeLine "Last seq:  ", forCheck.lastSeqName 
        stderr.writeLine "Seq count: ", forCheck.seqCount 
        stderr.writeLine "BP count:  ", forCheck.bpCount, ",", revCheck.bpCount, " (ignored)"


  let status = if errors == 0: "OK"
              else: "ERROR"

  if not bool(args["--quiet"]):
    echo status, "\t", libtype ,"\t", args["<FQFILE>"]

  return errors
]#

#when isMainModule:
#  main_helper(fqcheck)
