import klib
import readfq
import strformat, math
import strutils
import os
import re
when not defined(windows):
  import posix



const NimblePkgVersion {.strdefine.} = "<NimblePkgVersion>"

proc version*(): string =
  if len(NimblePkgVersion) == 0:
    return "0.0.0"
  else:
    return NimblePkgVersion

type
  fileNameStrand* = tuple
    filename: string
    splittedFile: string
    id: string
    strand: string
    isRev: bool
 
type
  nucleoCount* = tuple
    at: int
    gc: int
    n: int
    tot: int

template print*(s: varargs[string, `$`]) =
  for x in s:
    stdout.write x

proc fmtFloat*(value      : float,
               decimals   : int,
               format     : string = "",
               thousandSep: string = ",",
               decimalSep : string = "."): string =
    if value != value:
        return "NaN"
    elif value == Inf:
        return "Inf"
    elif value == NegInf:
        return "-Inf"
    
    let
        forceSign  = format.find('s') >= 0
        thousands  = format.find('t') >= 0
        removeZero = format.find('z') >= 0
    
    var valueStr = ""
    
    if decimals >= 0:
        valueStr.formatValue(round(value, decimals), "." & $decimals & "f")
    else:
        valueStr = $value
    
    if valueStr[0] == '-':
        valueStr = valueStr[1 .. ^1]
    
    let
        period  = valueStr.find('.')
        negZero = 1.0 / value == NegInf
        sign    = if value < 0.0 or negZero: "-" elif forceSign: "+" else: ""
    
    var
        integer    = ""
        integerTmp = valueStr[0 .. period - 1]
        decimal    = decimalSep & valueStr[period + 1 .. ^1]
    
    if thousands:
        while true:
            if integerTmp.len > 3:
                integer = thousandSep & integerTmp[^3 .. ^1] & integer
                integerTmp = integerTmp[0 .. ^4]
            else:
                integer = integerTmp & integer
                
                break
    else:
        integer = integerTmp
    
    while removeZero:
        if decimal[^1] == '0':
            decimal = decimal[0 .. ^2]
        else:
            break
    
    if decimal == decimalSep:
        decimal = ""
    
    return sign & integer & decimal

proc splitPosWithPattern(s, p: string): int =
  for i in 0 ..< len(s) - len(p) - 1:
    if p == s[i ..< i+len(p)]:
      return i
  return -1
    
proc getStrandFromFilename*(f: string, forPattern = "auto"; revPattern = "auto"): fileNameStrand =
   
  result.filename = f
  
  var
    forCount = 0
    revCount = 0
    forPatterns=newSeq[string]()
    revPatterns=newSeq[string]()
    
  if forPattern == "auto":
    forPatterns = @["_R1_", "_R1.", "_1."]
  else:
    forPatterns.add(forPattern)
  
  if revPattern == "auto":
    revPatterns = @["_R2_", "_R2.", "_2."]
  else:
    revPatterns.add(revPattern)
  
  for pattern in forPatterns:
    let pos = splitPosWithPattern(f, pattern)
    if pos > 0:
      forCount += 1
      result.strand = "for"
      result.splittedFile = f[0 ..< pos]
      result.id = extractFilename(result.splittedFile)
      break

  for pattern in revPatterns:
    let pos = splitPosWithPattern(f, pattern)
    if pos > 0:
      revCount += 1
      result.strand = "rev"
      result.splittedFile = f[0 ..< pos]
      result.id = extractFilename(result.splittedFile)
      break
  
  if (revCount > 0 and forCount > 0) or (forCount == 0 and revCount == 0):
    result.strand = "unknown"
  elif revCount > 0:
    result.isRev = true
  

proc printFastxRecord*(s: FastxRecord): string =
  let seqName = if len(s.comment) > 0: s.name & " " & s.comment
                else: s.name

  if len(s.qual) > 0:
    "@" & seqName & "\n" & s.seq & "\n+\n" & s.qual
  else:
    ">" & seqName & "\n" & s.seq 


proc count_gc*(s: string): int =
  let
    upper_seq = toUpperAscii(s)  
  for c in upper_seq:
    if c == 'G' or c == 'C':
      result += 1

proc count_all*(s: string): nucleoCount =
  let
    upper_seq = toUpperAscii(s)  
  for c in upper_seq:
    if c == 'A' or c == 'T' or c == 'U':
      result.at += 1
    elif c == 'G' or c == 'C':
      result.gc += 1
    elif c == 'N':
      result.n += 1

    result.tot = result.at + result.gc
    
proc get_gc*(s: string): float =
  var 
    gc_count = 0
    at_count = 0
    upper_seq = toUpperAscii(s)
  for c in upper_seq:
    if c == 'G' or c == 'C':
      gc_count += 1
    elif c == 'A' or c == 'T' or c == 'U':
      at_count += 1
  
  return float(gc_count) / float(gc_count + at_count)

proc guessR2*(file_R1: string, pattern_R1="auto", pattern_R2="auto", verbose=false): string =
  if not fileExists(file_R1):
    return ""

  if pattern_R1 == "auto" and pattern_R2 == "auto":
    # automatic guess
    if match(file_R1, re".+_R1\..+"):           
      result = file_R1.replace(re"_R1\.", "_R2.")
    elif match(file_R1, re".+_R1_.+"):           
      result = file_R1.replace(re"_R1_", "_R2_")
    elif match(file_R1, re".+_1\..+"):            
      result = file_R1.replace(re"_1\.", "_2.")
    else:
      if verbose:
        stderr.writeLine("Warning: Unable to detect R2 filename using --for-tag (_R1. or _1.) in <", file_R1, ">:")
      return ""
  else:
    # user defined patterns
    if match(file_R1, re(".+" & pattern_R1 & ".+") ):
      result = file_R1.replace(re(pattern_R1), pattern_R2)
    else:
      if verbose:
        stderr.writeLine("Warning: Unable to detect R2 file using user defined patterns, from ", file_R1)
      return ""
  
  if not fileExists(result):
    if verbose:
        stderr.writeLine("Warning: Automatically detected R2 was not found: ", result)
    return ""



proc echoVerbose*(msg: string, print: bool) =
  if print:
    stderr.writeLine(" * ", msg)



# Common variables for switches
var
   verbose*:        bool    # verbose mode
   debug*:          bool    # debug mode
   check*:          bool    # enable basic checks
   stripComments*:  bool    # strip comments in output sequence
   stripName*:      bool    # strip name in output sequence
   forceFasta*:     bool
   forceFastq*:     bool
   defaultQual*     = 33
   lineWidth*       = 0


debug = if getEnv("seqfu_debug", "0") != "0": true
          else: false

proc reverse*(str: string): string =
  result = ""
  for index in countdown(str.high, 0):
    result.add(str[index])


proc translateIUPAC*(c: char): char =
  const
    inputBase = "ATUGCYRSWKMBDHVN"
    rcBase    = "TAACGRYSWMKVHDBN"
  let
    base = toUpperAscii(c)
  let o = inputBase.find(base)
  if o >= 0:
    return rcBase[o]
  else:
    return base

proc matchIUPAC*(a, b: char): bool =
  # a=primer; b=read
  let
    metachars = @['Y','R','S','W','K','M','B','D','H','V']

  if b == 'N':
    return false
  elif a == b or a == 'N':
    return true
  elif a in metachars:
    if a == 'Y' and (b == 'C' or b == 'T'):
      return true
    if a == 'R' and (b == 'A' or b == 'G'):
      return true
    if a == 'S' and (b == 'G' or b == 'C'):
      return true
    if a == 'W' and (b == 'A' or b == 'T'):
      return true
    if a == 'K' and (b == 'T' or b == 'G'):
      return true
    if a == 'M' and (b == 'A' or b == 'C'):
      return true
    if a == 'B' and (b != 'A'):
      return true
    if a == 'D' and (b != 'C'):
      return true
    if a == 'H' and (b != 'G'):
      return true
    if a == 'V' and (b != 'T'):
      return true
  return false


# Reverse complement
proc revcompl*(s: string): string =
  result = ""
  let rev = reverse(s)
  for c in rev:
      result &= c.translateIUPAC

proc revcompl*(s: FQRecord): FQRecord =
  result.name     = s.name
  result.comment  = s.comment
  result.quality  = reverse(s.quality)
  result.sequence = revcompl(s.sequence)


proc revcompl*(s: FastxRecord): FastxRecord =
  result.name    = s.name
  result.comment = s.comment
  result.qual    = reverse(s.qual)
  result.seq     = revcompl(s.seq)


proc charToQual*(c: char, offset = 33): int =
  ## returns Illumina quality score for a given character
  c.ord - offset

proc getBasename*(filename: string): string =
  let  fileParse = splitFile(filename)

  if fileParse[2] == ".gz":
    let  gunzippedParse = splitFile(fileParse[1])
    return gunzippedParse[1]
  else:
    return fileParse[1]
  #( dir, filenameNoExt, extension) = splitFile(filename)
  #(sampleId, direction) = extractTag(filenameNoExt, pattern1, pattern2)

proc format_dna*(seq: string, format_width: int): string =
  if format_width == 0:
    return seq
  for i in countup(0,seq.len - 1,format_width):
    #let endPos = if (seq.len - i < format_width): seq.len - 1
    #            else: i + format_width - 1
    if (seq.len - i <= format_width):
      result &= seq[i..seq.len - 1]
    else:
      result &= seq[i..i + format_width - 1] & "\n"


proc qualToChar*(q: int): char =
  ## returns character for a given Illumina quality score
  (q+33).char

proc print_seq*(record: FastxRecord, outputFile: File) =
  var
    name = record.name
    seqstring : string

  if not stripComments and len(record.comment) > 0:
    name.add(" " & record.comment)

  if len(record.qual) > 0 and (len(record.seq) != len(record.qual)):
    stderr.writeLine("Sequence <", record.name, ">: quality and sequence length mismatch.")
    return

  if len(record.qual) > 0 and forceFasta == false:
    # print FQ

    seqString = "@" & name & "\n" & record.seq & "\n+\n" & record.qual
  elif forceFastq == true:
    seqString = "@" & name & "\n" & record.seq & "\n+\n" & repeat(qualToChar(defaultQual), len(record.seq))
  else:
    # print FA
    seqString = ">" & name & "\n" & record.seq

  if outputFile == nil:
    echo seqString
  else:
    outputFile.writeLine(seqstring)


proc print_seq*(record: FQRecord, outputFile: File, rename="") =
  # Output file == nil then print
  var
    name = record.name
    seqstring : string

  if len(rename) > 0:
    name = rename
  if not stripComments:
    name.add(" " & record.comment)

  if len(record.quality) > 0 and (len(record.sequence) != len(record.quality)):
    stderr.writeLine("Sequence <", record.name, ">: quality and sequence length mismatch.")
    return

  if len(record.quality) > 0 and forceFasta == false:
    # print FQ
    seqString = "@" & name & "\n" & record.sequence & "\n+\n" & record.quality
  elif forceFastq == true:
    seqString = "@" & name & "\n" & record.sequence & "\n+\n" & repeat(qualToChar(defaultQual), len(record.sequence))
  else:
    # print FA
    seqString = ">" & name & "\n" & record.sequence

  if outputFile == nil:
    echo seqString
  else:
    outputFile.writeLine(seqstring)


  # FQRecord* = object
  #   name*: string
  #   comment*: string# optional
  #   sequence*: string
  #   quality*: string# optional
proc mergeSeqs*(f, r: FQRecord, minlen=10, minid=0.85, identityAccepted=0.90): FQRecord {.discardable.} =
  result.name = f.name
  var rc = revcompl(r) 
  var max = if     f.sequence.high > rc.sequence.high: rc.sequence.high
            else:  f.sequence.high
  
  var max_score = 0.0
  var pos = 0
  var str : string

  for i in minlen .. max:
    var
      s1 = f.sequence[f.sequence.high - i .. f.sequence.high]
      s2 = rc.sequence[0 .. 0 + i ]
      #q1 = f.quality[f.sequence.high - i .. f.sequence.high]
      #q2 = rc.quality[r.sequence.high - i .. r.sequence.high]
      score = 0.0
      

    for i in 0 .. s1.high:
      if s1[i] == s2[i]:
        score += 1
   
    score = score / float(len(s1))

    if score > max_score:
      max_score = score
      pos = i
      str = s1
      if score > identityAccepted:
        break
  # end loop

  # Fix mismatches
  if max_score > min_id:
    result.name = f.name
    result.sequence = f.sequence & rc.sequence[pos + 1 .. ^1]
    result.quality  = f.quality  & rc.quality[pos + 1 .. ^1]
  else:
    result = f


### NANOPORE


proc compressHomopolymers*(s: string): string =
  result  = $s[0]
  for c in s[1 .. ^1]:
    if c != result[^1]:
      result = result & c

proc compressHomopolymers*(s: FQRecord): FQRecord =
  result.name = s.name
  if len(s.comment) > 0:
    result.comment = s.comment
  result.sequence = $s.sequence[0]
  if len(s.quality) > 0:
    result.quality = $s.quality[0]

  for i, c in s.sequence[1 .. ^1]:
    if c != result.sequence[^1]:
      result.sequence = result.sequence & c 
      if len(s.quality) > 0:
        result.quality  = result.quality  & $s.quality[i + 1]    

### AMPLICHECK

proc extractTag*(filename: string, patternFor: string, patternRev: string): (string, string) =
    if patternFor == "auto":
      # automatic guess
      var basename = split(filename, "_R1.")
      if len(basename) > 1:
        return (basename[0], "R1")
      basename = split(filename, "_R1_")
      if len(basename) > 1:
        return (basename[0], "R1")
      basename = split(filename, "_1.")
      if len(basename) > 1:
        return (basename[0], "R1")
    else:
      var basename = split(filename, patternFor)
      if len(basename) > 1:
        return (basename[0], "R1")

    if patternFor == "auto":
      # automatic guess
      var basename = split(filename, "_R2.")
      if len(basename) > 1:
        return (basename[0], "R2")
      basename = split(filename, "_R2_")
      if len(basename) > 1:
        return (basename[0], "R2")
      basename = split(filename, "_2.")
      if len(basename) > 1:
        return (basename[0], "R2")
    else:
      var basename = split(filename, patternFor)
      if len(basename) > 1:
        return (basename[0], "R2")

    return (filename, "SE")


template initClosure*(id:untyped,iter:untyped) =
  let id = iterator():auto {.closure.} =
    for x in iter:
      yield x


proc findOligoMatches*(sequence, primer: string, threshold: float, max_mismatches = 0, min_matches = 6): seq[int] =
  let
    dna = ('-'.repeat(len(primer) - 1) & sequence & '-'.repeat(len(primer) - 1)).toUpper()
    primer = primer.toUpper()

  for pos in 0..len(dna)-len(primer):
    let query = dna[pos..<pos+len(primer)]
    var
      matches = 0
      mismatches = 0
      primerRealLen = 0

    for c in 0..<len(query):
      if matchIUPAC(primer[c], query[c]):
        matches += 1
        primerRealLen += 1
      elif query[c] != '-':
        mismatches += 1
        primerRealLen += 1

      if mismatches > max_mismatches:
        break
 
    let
      score = float(matches) / float(primerRealLen)
    if score >= threshold and mismatches <= max_mismatches and matches >= min_matches:
      result.add(pos-len(primer)+1)

proc findPrimerMatches*(sequence, primer: string, threshold: float, max_mismatches = 0, min_matches = 6): seq[seq[int]] =
  let
    forMatches = findOligoMatches(sequence, primer, threshold, max_mismatches, min_matches)
    primerReverse = revcompl(primer)
    revMatches = findOligoMatches(sequence, primerReverse, threshold, max_mismatches, min_matches)

  result = @[forMatches, revMatches]

# boiler plate code for handling exceptions in command line utils
import sugar

proc main_helper*(main_func: var seq[string] -> int) =
  var args: seq[string] = commandLineParams()
  when defined(windows):
    try:
      let exitStatus = main_func(args)
      quit(exitStatus)
    except IOError:
      # Broken pipe
      quit(0)
    except Exception:
      stderr.writeLine( getCurrentExceptionMsg() )
      quit(2)  
  else:
    signal(SIG_PIPE, cast[typeof(SIG_IGN)](proc(signal: cint) =
      if debug:
        stderr.write("SeqFu-debug: handled sigpipe\n")
      quit(0)
    ))

    # Handle Ctrl+C interruptions and pipe breaks
    type EKeyboardInterrupt = object of CatchableError
    proc handler() {.noconv.} =
      try:
        if getEnv("SEQFU_QUIET") == "" or debug:
          stderr.writeLine("[Quitting on Ctrl-C]")
        quit(1)
      except Exception as e:
        if debug:
          stderr.writeLine("SeqFu-debug: aborted quit: ", e.msg)
        quit(1)
      
    setControlCHook(handler)

    try:
      let exitStatus = main_func(args)
      if debug:
        stderr.writeLine("SeqFu-debug: Exiting ", exitStatus)
      quit(exitStatus)
    except EKeyboardInterrupt:
      # Ctrl-C interruption
      if debug:
        stderr.writeLine("SeqFu-debug: Keyboard Ctrl-C")
      quit(1)
    except IOError:
      # Broken pipe
      if debug:
        stderr.writeLine("SeqFu-debug: IOError")
      quit(1)
    except Exception:
      stderr.writeLine(getCurrentExceptionMsg())
      quit(2)

proc main_helper_v1*(main_func: var seq[string] -> int) =
  var args: seq[string] = commandLineParams()
  when defined(windows):
    try:
      let exitStatus = main_func(args)
      quit(exitStatus)
    except IOError:
      # Broken pipe
      quit(0)
    except Exception:
      stderr.writeLine( getCurrentExceptionMsg() )
      quit(2)   
  else:
    
    signal(SIG_PIPE,cast[typeof(SIG_IGN)](proc(signal:cint) =
      if debug:
        stderr.write("SeqFu-debug: handled sigpipe\n")
      quit(0)
    ))
    # Handle Ctrl+C interruptions and pipe breaks
    type EKeyboardInterrupt = object of CatchableError
    proc handler() {.noconv.} =
      raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
    setControlCHook(handler)
    # Handle "Ctrl+C" intterruption
    try:
      let exitStatus = main_func(args)
      if debug:
        stderr.writeLine("SeqFu-debug: Exiting ", exitStatus)
      quit(exitStatus)
    except EKeyboardInterrupt:
      # Ctrl+C

      if debug:
        stderr.writeLine("SeqFu-debug: Keyboard Ctrl-C")
      quit(1)
    except IOError:
      # Broken pipe
      if debug:
        stderr.writeLine("SeqFu-debug: IOError")
      quit(1)
    except Exception:
      stderr.writeLine( getCurrentExceptionMsg() )
      quit(2)   


####
####  Get Illumina Index

proc getIndex(s: string): string =
  let split = s.split(':')
  if len(split) > 2:
    return split[^1]

# TODO: Declared not used
#[
proc getIndexFromFile(f: string, max = 250): string =

  var
    c = 0
    countTable = initCountTable[string]()
  try:
    for record in readfq(f):
      c += 1
      if c > max:
        break
      let index = getIndex(record.comment)
      if len(index) > 0:
        countTable.inc(index)
    countTable.sort()

    for index, counts in countTable:
      if float(counts) > float(max) - float(max/10):
        return index


  except Exception:
    return ""
]#