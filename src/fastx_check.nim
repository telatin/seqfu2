import docopt
import readfq
import times
import os
import tables
import strutils
import strformat
import ./seqfu_utils
import zip/gzipfiles  # Import zip package
 

 
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


proc namesMatch(seqNameFwd, seqNameRev: string): bool =
  let
    MIN_REMAINING_NAME_LENGTH = 4
  if seqNameFwd == seqNameRev:
    return true
  else:
    for PAD in 1 .. 3:
      if len(seqNameFwd) >= MIN_REMAINING_NAME_LENGTH + PAD and len(seqNameRev) >= MIN_REMAINING_NAME_LENGTH + PAD:
        if seqNameFwd[0 .. seqNameFwd.len - PAD] == seqNameRev[0 .. seqNameRev.len - PAD]:
          if len(seqNameFwd[0 .. seqNameFwd.len - PAD]) > MIN_REMAINING_NAME_LENGTH:
            return true
          else:
            return false
  return false

proc deepCheckStandardFqFile(filename: string): FQcheck =
  let DNA = "ACGTN"
  let QUAL = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
  result.filename = filename
  result.isValid = true
  result.errors = ""

  if not fileExists(filename):
    result.errors = "File does not exist;"
    result.isValid = false
    return

  let fileReader = if filename.endsWith(".gz"): newGzFileStream(filename) 
                   else: newFileStream(filename)  # Open gzip file
  

  var line: string 
  # Loop over each line in the file
  var seqNumber = 0
  var bpTotal   = 0
  #var emptyLines = 0

  var seqName,seqLine, sepLine, qualLine: string
  while not fileReader.atEnd():
    line = fileReader.readLine()
    
    if (len(line) == 0):
      #emptyLines += 1
      continue
    
    if (line[0] == '@'):
        # Sequence block
        if (len(line) == 1):
          result.errors &= "Empty sequence name at sequence" & $seqNumber     & ";"
          result.isValid = false
          # DO NOT PARSE FURTHER
          return
        seqName = line[1 .. ^1].split(" ")[0].split("\t")[0]
        seqLine = fileReader.readLine()
        sepLine = fileReader.readLine()
        qualLine = fileReader.readLine()
        if (len(seqLine) == 0 and len(qualLine) == 0):
          result.errors &= "Empty sequence at sequence" & $seqNumber     & ";"
          result.isValid = false
          # DO NOT PARSE FURTHER
          return
          
        if (len(seqLine) != len(qualLine)):
          result.errors &= "Sequence/Quality mismatch lenght at sequence: " & $seqNumber     & ";"
          result.isValid = false
          # DO NOT PARSE FURTHER
          return

        if (sepLine[0] != '+'):
          result.errors &= "Invalid separator line at sequence: " & $seqNumber & ": " & seqName     & ";"
          result.isValid = false
          # DO NOT PARSE FURTHER
          return
        for c in seqLine.toUpper():
          if c notin DNA:
            result.errors &= "Invalid character in sequence: <" & $c & "> in " & line     & ";"
            result.isValid = false
            # DO NOT PARSE FURTHER
            return
        #[for q in qualLine:
          if q notin QUAL:
            result.errors &= "Invalid character in sequence: <" & $q & "> in " & line     & ";"
            result.isValid = false
        ]#

        # Update records
        seqNumber += 1
        bpTotal += len(seqLine)

        if seqNumber == 1:
          result.firstSeqName = seqName
          result.firstSeq = seqLine

    result.lastSeqName = seqName
    result.lastSeq = seqLine

    if result.isValid == false:
      result.seqCount = -1
      result.bpCount = -1
      # Premature exit
      return



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
  
proc checkPairedFiles(fwdFile, revFile: string, deep = false): FQcheck =
  let
    #fwd = checkFqFile(fwdFile)
    #rev = checkFqFile(revFile)
    fwd = if deep == false: checkFqFile(fwdFile)
          else: deepCheckStandardFqFile(fwdFile)
    rev = if deep == false: checkFqFile(revFile)
          else: deepCheckStandardFqFile(revFile)
  result.isValid = true
  result.errors = ""

  result.filename = fwd.filename & ";" & rev.filename

  # Check individual files
  if fwd.isValid == false:
    result.isValid = false
    result.errors  &= "R1=" & fwd.errors # & ";"
  if rev.isValid == false:
    result.isValid = false
    result.errors  &= "R2=" & rev.errors # & ";"

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

proc gatherFqFiles(dir: string, no_paired, debug: bool): (seq[string], seq[string]) =
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
          if debug:
            stderr.writeLine "#DEBUG_INIT: Adding file: " & path
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


proc toDebugString(fq: FQcheck, nice: bool): string =
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
    
  "#DEBUG FOR " & fq.filename.split(";")[0] &
  "\n#------ status: " & status & 
  "\n#------ library:" & libtag & 
  "\n#------ counts: " & countStr & 
  "\n#------ bp:     " & bpStr & 
  "\n#------ num_err: " & $errnum & 
  "\n#------ errors:  " & fq.errors

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
    -d, --deep                 Perform a deep check of the file and will not 
                               lsupport multiline Sanger FASTQ [default: false]
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
    (seList, peList) = gatherFqFiles($args["<FQDIR>"], bool(args["--no-paired"]),bool(args["--debug"]))
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
  
  if bool(args["--debug"]):
    for file in seList:
      stderr.writeLine "#DEBUG_PRE_RUN: SE: ", file
    for file in peList:
      stderr.writeLine "#DEBUG_PRE_RUN: SE: ", file
  if true:
    for file in seList:
      if bool(args["--debug"]):
        stderr.writeLine "#DEBUG: Processing SE: ", file
      let 
        result = if args["--deep"] == false: checkFqFile(file)
                 else: deepCheckStandardFqFile(file)
      if result.isValid == false:
        errors += 1
      totseq += result.seqCount
      echo result.toString(bool(args["--thousands"]))
    for file in peList:
      if bool(args["--debug"]):
        stderr.writeLine "#DEBUG: Processing PE: ", file
      let 
        result = checkPairedFiles(file.split(";")[0], file.split(";")[1], deep=bool(args["--deep"]))

      if result.isValid == false:
        errors += 1
      totseq += result.seqCount
      echo result.toString(bool(args["--thousands"]))
      if args["--debug"]:
        echo result.toDebugString(bool(args["--thousands"]))
    
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
