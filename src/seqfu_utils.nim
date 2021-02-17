import klib, readfq

import  strutils, os
 

proc version*(): string =
  return "0.8.7"




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



### AMPLICHECK


template initClosure*(id:untyped,iter:untyped) =
  let id = iterator():auto {.closure.} =
    for x in iter:
      yield x

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

proc reverse*(str: string): string =
  result = ""
  for index in countdown(str.high, 0):
    result.add(str[index])

proc revcompl*(s: string): string =
  result = ""
  let rev = reverse(s)
  for c in rev:
      result &= c.translateIUPAC

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

