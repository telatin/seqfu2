import klib, readfq
import  strutils, os, re
when not defined(windows):
  import posix
const NimblePkgVersion {.strdefine.} = "<NimblePkgVersion>"
proc version*(): string =
  return NimblePkgVersion

 


proc `$`(s: FQRecord): string =
  if len(s.quality) > 0:
    "@" & s.name & " " & s.comment & "\n" & s.sequence & "\n+\n" & s.quality
  else:
    ">" & s.name & " " & s.comment & "\n" & s.sequence & "\n"



proc guessR2*(file_R1: string, pattern_R1="auto", pattern_R2="auto"): string =
  if not fileExists(file_R1):
    return ""

  if pattern_R1 == "auto" and pattern_R2 == "auto":
    # automatic guess
    if match(file_R1, re".+_R1\..+"):           
      result = file_R1.replace(re"_R1\.", "_R2.")
    elif match(file_R1, re".+_1\..+"):            
      result = file_R1.replace(re"_1\.", "_2.")
    else:
      #echo "Unable to detect --for-tag (_R1. or _1.) in <", file_R1, ">"
      return ""
  else:
    # user defined patterns
    if match(file_R1, re(".+" & pattern_R1 & ".+") ):
      result = file_R1.replace(re(pattern_R1), pattern_R2)
    else:
      return ""
  
  if not fileExists(result):
    return ""



proc echoVerbose*(msg: string, print: bool) =
  if print:
    stderr.writeLine(" * ", msg)



# Common variables for switches
var
   verbose*:        bool    # verbose mode
   check*:          bool    # enable basic checks
   stripComments*:  bool    # strip comments in output sequence
   forceFasta*:     bool
   forceFastq*:     bool
   defaultQual*     = 33
   lineWidth*       = 0


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


proc charToQual*(c: char): int =
  ## returns Illumina quality score for a given character
  c.ord - 33

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

  if not stripComments:
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
      q1 = f.quality[f.sequence.high - i .. f.sequence.high]
      q2 = r.quality[r.sequence.high - i .. r.sequence.high]
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
    result.quality = f.quality & rc.quality[pos + 1 .. ^1]
  else:
    result = f



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
  let dna = '-'.repeat(len(primer) - 1) & sequence & '-'.repeat(len(primer) - 1)

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
    
    signal(SIG_PIPE, SIG_IGN)
    # Handle Ctrl+C interruptions and pipe breaks
    type EKeyboardInterrupt = object of CatchableError
    proc handler() {.noconv.} =
      raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
    setControlCHook(handler)
    # Handle "Ctrl+C" intterruption
    try:
      let exitStatus = main_func(args)
      quit(exitStatus)
    except EKeyboardInterrupt:
      # Ctrl+C
      quit(1)
    except IOError:
      # Broken pipe
      quit(0)
    except Exception:
      stderr.writeLine( getCurrentExceptionMsg() )
      quit(2)   