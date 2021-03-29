import docopt
import readfq
import json
import os, strutils, re, iterutils, sequtils
import threadpool
import neo
import tables, algorithm
import posix
import ./seqfu_utils

signal(SIG_PIPE, SIG_IGN)

const NimblePkgVersion {.strdefine.} = "<NimblePkgVersion>"

let
  programVersion = NimblePkgVersion
  programName = "dadaist2-region"
  defaultTarget =  "AAATTGAAGAGTTTGATCATGGCTCAGATTGAACGCTGGCGGCAGGCCTAACACATGCAAGTCGAACGGTAACAGGAAGCAGCTTGCTGCTTCGCTGACGAGTGGCGGACGGGTGAGTAATGTCTGGGAAGCTGCCTGATGGAGGGGGATAACTACTGGAAACGGTAGCTAATACCGCATAATGTCGCAAGACCAAAGAGGGGGACCTTCGGGCCTCTTGCCATCGGATGTGCCCAGATGGGATTAGCTTGTTGGTGGGGTAACGGCTCACCAAGGCGACGATCCCTAGCTGGTCTGAGAGGATGACCAGCCACACTGGAACTGAGACACGGTCCAGACTCCTACGGGAGGCAGCAGTGGGGAATATTGCACAATGGGCGCAAGCCTGATGCAGCCATGCCGCGTGTATGAAGAAGGCCTTCGGGTTGTAAAGTACTTTCAGCGGGGAGGAAGGGAGTAAAGTTAATACCTTTGCTCATTGACGTTACCCGCAGAAGAAGCACCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGGTGCAAGCGTTAATCGGAATTACTGGGCGTAAAGCGCACGCAGGCGGTTTGTTAAGTCAGATGTGAAATCCCCGGGCTCAACCTGGGAACTGCATCTGATACTGGCAAGCTTGAGTCTCGTAGAGGGGGGTAGAATTCCAGGTGTAGCGGTGAAATGCGTAGAGATCTGGAGGAATACCGGTGGCGAAGGCGGCCCCCTGGACGAAGACTGACGCTCAGGTGCGAAAGCGTGGGGAGCAAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGTCGACTTGGAGGTTGTGCCCTTGAGGCGTGGCTTCCGGAGCTAACGCGTTAAGTCGACCGCCTGGGGAGTACGGCCGCAAGGTTAAAACTCAAATGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGATGCAACGCGAAGAACCTTACCTGGTCTTGACATCCACGGAAGTTTTCAGAGATGAGAATGTGCCTTCGGGAACCGTGAGACAGGTGCTGCATGGCTGTCGTCAGCTCGTGTTGTGAAATGTTGGGTTAAGTCCCGCAACGAGCGCAACCCTTATCCTTTGTTGCCAGCGGTCCGGCCGGGAACTCAAAGGAGACTGCCAGTGATAAACTGGAGGAAGGTGGGGATGACGTCAAGTCATCATGGCCCTTACGACCAGGGCTACACACGTGCTACAATGGCGCATACAAAGAGAAGCGACCTCGCGAGAGCAAGCGGACCTCATAAAGTGCGTCGTAGTCCGGATTGGAGTCTGCAACTCGACTCCATGAAGTCGGAATCGCTAGTAATCGTGGATCAGAATGCCACGGTGAATACGTTCCCGGGCCTTGTACACACCGCCCGTCACACCATGGGAGTGGGTTGCAAAAGAAGTAGGTAGCTTAACCTTCGGGAGGGCGCTTACCACTTTGTGATTCATGACTGGGGTGAAGTCGTAACAAGGTAACCGTAGGGGAACCTGCGGTTGGATCACCTCCTTA"
  regions = parseJson("""
{
 "V1": {
   "start": 68,
   "end": 99
  }, "V2": {
   "start": 136,
   "end": 242
  }, "V3": {
   "start": 338,
   "end": 533
  }, "V4": {
   "start": 576,
   "end": 682
  }, "V5": {
   "start": 821,
   "end": 879
  }, "V6": {
   "start": 970,
   "end": 1046
  }, "V7": {
   "start": 1117,
   "end": 1294
  }, "V8": {
   "start": 1435,
   "end": 1465
  }
}""")


var
  poolsize = 200



type
  swAlignment* = object
   top, bottom, middle: string
   score, length: int
   queryStart, queryEnd, targetStart, targetEnd: int

type
  swWeights* = object
    match, mismatch, gap, gapopening: int
    minscore: int

let
  swDefaults = swWeights(
    match:       6,
    mismatch:   -2,
    gap:        -4,
    gapopening: -4,
    minscore:    1 )


proc regionsToDict(regions: JsonNode): Table[int, string] =
  result = initTable[int, string]()
  for n in regions.keys:
    if "start" in regions[n] and "end" in regions[n]:
      for i in countup(regions[n]["start"].getInt(), regions[n]["end"].getInt() ):
        result[i] = n

proc reverse*(str: string): string =
  result = ""
  for index in countdown(str.high, 0):
    result.add(str[index])


# proc `$`(i: swAlignment): string =
#   let
#     alignmentWidth = 60
#   result = "#score=" & $i.score & ";length=" & $i.length & ";query=" & $i.queryStart & "-" & $i.queryEnd & ";target=" & $i.targetStart  & "-" & $i.targetEnd &  "\n"
#   #     i.top    & "\n" &
#   #     i.middle & "\n" &
#   #     i.bottom
#   for p in countup(0, len(i.top), alignmentWidth):
#     let span = if p+alignmentWidth > len(i.top): len(i.top)
#                else: p+alignmentWidth
#     result &= " " & i.top[p ..< span] & "\n"
#     result &= " " & i.middle[p ..< span] & "\n"
#     result &= " " & i.bottom[p ..< span] & "\n\n"


# proc swInitializeMatrix(alpha, beta: string, weights: swWeights): Matrix[system.int] =
#   result = makeMatrix(len(alpha) + 1,
#     len(beta) + 1,
#     proc(i, j: int): int = 0
#   )

#   for t, x in result:
#     let
#       (i, j) = t

#     if i == 0 or j == 0:
#       result[i, j] = 0
#     else:
#       let
#         score= if alpha[i - 1] == beta[j - 1]: weights.match
#                else: weights.mismatch
#         top  = result[i,   j-1] + weights.gap
#         left = result[i-1, j]   + weights.gap
#         diag = result[i-1, j-1] + score
#       result[i, j] =  max( 0, max(top, max(left, diag)))
#   return result



proc simpleSmithWaterman(alpha, beta: string, weights: swWeights): swAlignment =

  # Constants defining path sources
  const
     cNone    = -1
     cUp      = 1
     cLeft    = 2
     cDiag    = 3
     mismatchChar = 'x'
     matchChar    = '|'

  # swMatrix: scores
  # swHelper: path sources [cNone,...]
  var
    swMatrix = makeMatrix(len(alpha) + 1,   len(beta) + 1,     proc(i, j: int): int = 0  )
    swHelper = constantMatrix(len(alpha) + 1, len(beta) + 1,    -1)
    iMax, jMax, scoreMax = -1

  # Initialize the matrix
  for t, x in swMatrix:
    let
      (i, j) = t

    # Set first row and col to zeros
    if i == 0 or j == 0:
      swMatrix[i, j] = 0
      swHelper[i, j] = cNone
    else:
      # Set each cell to max(0, up, diag, left)
      let
        score= if alpha[i - 1] == beta[j - 1]: weights.match
               else: weights.mismatch

        top  = swMatrix[i,   j-1] + weights.gap
        left = swMatrix[i-1, j]   + weights.gap
        diag = swMatrix[i-1, j-1] + score

      if diag < 0 and left < 0 and top < 0:
        swMatrix[i,j] = 0
        swHelper[i,j] = cNone
        continue

      # Check which is the max and set provenance in swHelper
      if diag >= top:
        if diag >= left:
          swMatrix[i,j] = diag
          swHelper[i,j] = cDiag
        else:
          swMatrix[i,j] = left
          swHelper[i,j] = cLeft
      else:
        if top >= left:
          swMatrix[i,j] = top
          swHelper[i,j] = cUp
        else:
          swMatrix[i,j] = left
          swHelper[i,j] = cLeft

      # Keep Max score and its coordinates
      if swMatrix[i,j] > scoreMax:
        scoreMax = swMatrix[i,j]
        iMax = i
        jMax = j


  # Find alignment (path)
  var
    matchString = ""
    alignString1 = ""
    alignString2 = ""
    I = iMax
    J = jMax


  result.queryEnd    = 0
  result.targetEnd   = 0
  result.length      = 0
  result.score       = scoreMax
  if scoreMax < weights.minscore:
    return

  while true:
    if swHelper[I, J] == cNone:
      result.queryStart  = I
      result.targetStart = J
      result.queryEnd    += I
      result.targetEnd   += J
      break
    elif swHelper[I, J] == cDiag:
      alignString1 &= alpha[I-1]
      alignString2 &= beta[J-1]
      result.queryEnd += 1
      result.targetEnd += 1
      result.length += 1
      if alpha[I-1] == beta[J-1]:
        matchString  &= matchChar
      else:
        matchString  &= mismatchChar
      I -= 1
      J -= 1

    elif swHelper[I, J] == cLeft:
      alignString1 &= alpha[I-1]
      alignString2 &= "-"
      matchString  &= " "
      result.queryEnd += 1
      I -= 1
    else:
      alignString1 &= "-"
      matchString  &= " "
      alignString2 &= beta[J-1]
      result.targetEnd += 1
      J -= 1


  result.top = reverse(alignString1)
  result.bottom = reverse(alignString2)
  result.middle = reverse(matchString)




type
  primerOptions = object
    primers: seq[string]
    minMatches, maxMismatches: int
    matchThs: float

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

proc version(): string =
  return programName  & " " & programVersion

template initClosure(id:untyped,iter:untyped) =
  let id = iterator():auto {.closure.} =
    for x in iter:
      yield x

# proc translateIUPAC(c: char): char =
#   const
#     inputBase = "ATUGCYRSWKMBDHVN"
#     rcBase    = "TAACGRYSWMKVHDBN"
#   let
#     base = toUpperAscii(c)
#   let o = inputBase.find(base)
#   if o >= 0:
#     return rcBase[o]
#   else:
#     return base

# proc matchIUPAC(a, b: char): bool =
#   # a=primer; b=read
#   let
#     metachars = @['Y','R','S','W','K','M','B','D','H','V']

#   if b == 'N':
#     return false
#   elif a == b or a == 'N':
#     return true
#   elif a in metachars:
#     if a == 'Y' and (b == 'C' or b == 'T'):
#       return true
#     if a == 'R' and (b == 'A' or b == 'G'):
#       return true
#     if a == 'S' and (b == 'G' or b == 'C'):
#       return true
#     if a == 'W' and (b == 'A' or b == 'T'):
#       return true
#     if a == 'K' and (b == 'T' or b == 'G'):
#       return true
#     if a == 'M' and (b == 'A' or b == 'C'):
#       return true
#     if a == 'B' and (b != 'A'):
#       return true
#     if a == 'D' and (b != 'C'):
#       return true
#     if a == 'H' and (b != 'G'):
#       return true
#     if a == 'V' and (b != 'T'):
#       return true
#   return false



# proc revcompl(s: string): string =
#   result = ""
#   let rev = reverse(s)
#   for c in rev:
#       result &= c.translateIUPAC


 
proc processPair(R1, R2: FQRecord, reference: string, opts: primerOptions, alnOpt: swWeights, regionsDict: Table[int, string]): string =
  let
   aln1 = simpleSmithWaterman(R1.sequence, reference, alnOpt)
   aln2 = simpleSmithWaterman(R2.sequence, reference, alnOpt)
  var
    reg1, reg2: string
    regCount1 = initCountTable[string]()
    regCount2 = initCountTable[string]()
  for position in aln1.targetStart .. aln1.targetEnd:
    if position in regionsDict:
      regCount1.inc(regionsDict[position], 1)
  for position in aln2.targetStart .. aln2.targetEnd:
    if position in regionsDict:
      regCount2.inc(regionsDict[position], 1)

  regCount1.sort()
  regCount2.sort()
  for i,v in regCount1.pairs:
    reg1 = i
    break

  for i,v in regCount2.pairs:
    reg2 = i
    break
  stdout.writeLine(R1.name, ".1\t", reg1, "\tscore=", aln1.score, "\t", aln1.targetStart, "-", aln1.targetEnd)
  stdout.writeLine(R2.name, ".2\t", reg2, "\tscore=", aln2.score, "\t", aln2.targetStart, "-", aln2.targetEnd)


proc processSequenceArray(pool: seq[FQRecord], reference: string, opts: primerOptions, alnOpts: swWeights, regionsDict: Table[int, string]): int =
  for i in 0 .. pool.high:
    if i mod 2 == 1:
      result += 1
      try:
        stdout.write( processPair(pool[i - 1], pool[i], reference, opts, alnOpts, regionsDict))
      except:
        stdout.write( processPair(pool[i - 1], pool[i], reference, opts, alnOpts, regionsDict))
        quit()


proc main(args: seq[string]) =
  let args = docopt("""
  Usage: dadaist2-regions [options] -1 <FOR> [-2 <REV>]

  Options:
    -1 --first-pair <FOR>     First sequence in pair
    -2 --second-pair <REV>    Second sequence in pair (can be inferred)
    -r --reference FILE       FASTA file with a reference sequence, E. coli 16S by default
    -j --regions FILE         Regions names in JSON format, E. coli variable regions by default
    --pattern-R1 <tag-1>      Tag in first pairs filenames [default: auto]
    --pattern-R2 <tag-2>      Tag in second pairs filenames [default: auto]
    --pool-size INT           Number of sequences/pairs to process per thread [default: 20]
    --min-score INT           Minimum alignment score [default: 80]
    --max-reads INT           Parse up to INT reads then quit [default: 1000]
    --se                      Force single end
    -v --verbose              Verbose output
    -h --help                 Show this help
    """, version=version(), argv=args)

  var
    file_R2: string
    file_R1 = $args["--first-pair"]
    respCount = 0
    singleend = false

  poolSize = parseInt($args["--pool-size"])

  # Check essential parameters
  if (not args["--first-pair"]):
    stderr.writeLine("Missing required parameter -1 (--first-pair)")
    quit(0)

  # Try inferring second filename (not specified and not SE)
  if (not args["--second-pair"] and not args["--se"]):
    if $args["--pattern-R1"] == "auto" and $args["--pattern-R2"] == "auto":
        # automatic guess
        if match(file_R1, re".+_R1_.+"):
          file_R2 = file_R1.replace(re"_R1_", "_R2_")
        elif match(file_R1, re".+_1\..+"):
          file_R2 = file_R1.replace(re"_R1\.", "_R2.")
        elif match(file_R1, re".+_R1\..+"):
          file_R2 = file_R1.replace(re"_R1\.", "_R2.")
        else:
          #echo "Unable to automatically detect --for-tag (_R1_, _R1. or _1.) in <", file_R1, ">"
          #quit(1)
          singleend = true

    else:
      # user defined patterns
      if match(file_R1, re(".+" & $args["--pattern-R1"] & ".+") ):
        file_R2 = file_R1.replace(re($args["--pattern-R1"]), $args["--pattern-R2"])
      else:
        echo "Unable to find pattern <", $args["--pattern-R1"], "> in file <", file_R1, ">"
        quit(1)
  else:
    file_R2 = $args["--second-pair"]

  if not fileExists(file_R1):
    stderr.writeLine("ERROR: File R1 not found: ", fileR1)
    quit(1)
  
  if not fileExists(file_R2) or args["--se"]:
    stderr.writeLine("Running single end mode")
    singleend = true

  initClosure(getR1,readfq(file_R1))
  initClosure(getR2,readfq(file_R2))

 
  var
    counter = 0
    readspool : seq[FQRecord]
    responses = newSeq[FlowVar[int]]()
  let
    programParameters = primerOptions(
      #primers:       @[p1for, p2for],
      minMatches:    1,
      maxMismatches: 1,
      matchThs:      1
    )
    alnParameters = swWeights(
      match: swDefaults.match, 
      mismatch : swDefaults.mismatch, 
      gap: swDefaults.mismatch, 
      gapopening: swDefaults.gapopening,
      minscore: parseInt($args["--min-score"])
    )
    regionsDict = regionsToDict(regions)

  if not singleend:
    for (R1, R2) in zip(getR1, getR2):
      counter += 1

      readspool.add(R1)
      readspool.add(R2)

      if counter mod poolSize == 0:
        #stderr.writeLine(counter, ": Spawning pool of size: ", len(readspool))
        responses.add(spawn processSequenceArray(readspool, defaultTarget, programParameters, alnParameters, regionsDict))
        readspool.setLen(0)

    responses.add(spawn processSequenceArray(readspool, defaultTarget, programParameters, alnParameters, regionsDict))

    for resp in responses:
      respCount += ^resp

  else:
    for R1 in  getR1:
      counter += 1

      readspool.add(R1)

      if counter mod poolSize == 0:
        #stderr.writeLine(counter, ": Spawning pool of size: ", len(readspool))
        responses.add(spawn processSequenceArray(readspool, defaultTarget, programParameters, alnParameters, regionsDict))
        readspool.setLen(0)

    responses.add(spawn processSequenceArray(readspool, defaultTarget, programParameters, alnParameters, regionsDict))

    for resp in responses:
      respCount += ^resp

when isMainModule:
  main(commandLineParams())
