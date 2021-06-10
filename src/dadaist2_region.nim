import docopt
import readfq
import json
import os, strutils, sequtils
import threadpool
import neo
import tables, algorithm
import ./seqfu_utils


const NimblePkgVersion {.strdefine.} = "internal-build"

let
  programVersion = NimblePkgVersion
  programName = "dadaist2-region"
  defaultTarget =  "AAATTGAAGAGTTTGATCATGGCTCAGATTGAACGCTGGCGGCAGGCCTAACACATGCAAGTCGAACGGTAACAGGAAGCAGCTTGCTGCTTCGCTGACGAGTGGCGGACGGGTGAGTAATGTCTGGGAAGCTGCCTGATGGAGGGGGATAACTACTGGAAACGGTAGCTAATACCGCATAATGTCGCAAGACCAAAGAGGGGGACCTTCGGGCCTCTTGCCATCGGATGTGCCCAGATGGGATTAGCTTGTTGGTGGGGTAACGGCTCACCAAGGCGACGATCCCTAGCTGGTCTGAGAGGATGACCAGCCACACTGGAACTGAGACACGGTCCAGACTCCTACGGGAGGCAGCAGTGGGGAATATTGCACAATGGGCGCAAGCCTGATGCAGCCATGCCGCGTGTATGAAGAAGGCCTTCGGGTTGTAAAGTACTTTCAGCGGGGAGGAAGGGAGTAAAGTTAATACCTTTGCTCATTGACGTTACCCGCAGAAGAAGCACCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGGTGCAAGCGTTAATCGGAATTACTGGGCGTAAAGCGCACGCAGGCGGTTTGTTAAGTCAGATGTGAAATCCCCGGGCTCAACCTGGGAACTGCATCTGATACTGGCAAGCTTGAGTCTCGTAGAGGGGGGTAGAATTCCAGGTGTAGCGGTGAAATGCGTAGAGATCTGGAGGAATACCGGTGGCGAAGGCGGCCCCCTGGACGAAGACTGACGCTCAGGTGCGAAAGCGTGGGGAGCAAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGTCGACTTGGAGGTTGTGCCCTTGAGGCGTGGCTTCCGGAGCTAACGCGTTAAGTCGACCGCCTGGGGAGTACGGCCGCAAGGTTAAAACTCAAATGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGATGCAACGCGAAGAACCTTACCTGGTCTTGACATCCACGGAAGTTTTCAGAGATGAGAATGTGCCTTCGGGAACCGTGAGACAGGTGCTGCATGGCTGTCGTCAGCTCGTGTTGTGAAATGTTGGGTTAAGTCCCGCAACGAGCGCAACCCTTATCCTTTGTTGCCAGCGGTCCGGCCGGGAACTCAAAGGAGACTGCCAGTGATAAACTGGAGGAAGGTGGGGATGACGTCAAGTCATCATGGCCCTTACGACCAGGGCTACACACGTGCTACAATGGCGCATACAAAGAGAAGCGACCTCGCGAGAGCAAGCGGACCTCATAAAGTGCGTCGTAGTCCGGATTGGAGTCTGCAACTCGACTCCATGAAGTCGGAATCGCTAGTAATCGTGGATCAGAATGCCACGGTGAATACGTTCCCGGGCCTTGTACACACCGCCCGTCACACCATGGGAGTGGGTTGCAAAAGAAGTAGGTAGCTTAACCTTCGGGAGGGCGCTTACCACTTTGTGATTCATGACTGGGGTGAAGTCGTAACAAGGTAACCGTAGGGGAACCTGCGGTTGGATCACCTCCTTA"
  regionsTemplate = parseJson("""
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
  alignedRead = object
    readname: string
    regions: seq[string]
    score: int
    alignStart, alignEnd: int

proc `$`(a: alignedRead): string =
  let
    status = if a.alignEnd > 0: "Pass"
                  else: "Fail"
    boundaries = if a.alignEnd > 0: $(a.alignStart) & ".." & $(a.alignEnd)
                  else: "NA"
  a.readname & "\tscore:" & $(a.score) & "\talignment:" & boundaries & "\tregions:" & (a.regions).join(",") & "\t" & status

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
    match:       10,
    mismatch:   -5,
    gap:        -10,
    gapopening: -10,
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


proc version(): string =
  return programName  & " " & programVersion

proc alnToRegs(alnStart, alnEnd: int, regionsDict: Table[int, string]): Table[string, int] =
  var
    regCount = initCountTable[string]()
  for position in alnStart ..< alnEnd:
    if position in regionsDict:
      regCount.inc(regionsDict[position], 1)
  
  
  regCount.sort()

  for i,j in regCount:
    result[i] = j


proc filtRegs(regs: Table[string, int], regions: JsonNode, threshold = 0.66): seq[string] =
  for region, counts in regs:
    var regLen : int
    try:
      regLen =  regions[region]["end"].getInt() - regions[region]["start"].getInt() + 1
    except Exception as e:
      stderr.writeLine("ERROR: Non integer values or 'start' and 'end' not found in JSON schema.\n Exeption -> ",e.msg)
      quit(1)
    let coverage = float(counts) / float(regLen)
    if coverage >= threshold:
      result.add(region)

proc processRead(R1: FQRecord, reference: string, opts: primerOptions, alnOpt: swWeights, regionsDict: Table[int, string], regions: JsonNode): alignedRead =
  let
    alignment_for = simpleSmithWaterman(R1.sequence, reference, alnOpt)
    alignment_rev = simpleSmithWaterman(revcompl(R1.sequence), reference, alnOpt)
    alignment = if alignment_for.score >= alignment_rev.score: alignment_for
                else: alignment_rev
 
  let
    regs = alnToRegs(alignment.targetStart, alignment.targetEnd, regionsDict)
  var
    filtRegs = filtRegs(regs, regions, 0.500)

  filtRegs.sort()

  result = alignedRead(readname: R1.name, 
    regions: filtRegs,
    score: alignment.score,
    alignStart: alignment.targetStart,
    alignEnd:   alignment.targetEnd)


proc processSequenceArray(pool: seq[FQRecord], reference: string, opts: primerOptions, alnOpts: swWeights, regionsDict: Table[int, string], regions: JsonNode): seq[alignedRead] =
  for i in 0 ..< pool.high:
    try:
      let regions =  processRead( pool[i], reference, opts, alnOpts, regionsDict, regions)
      result.add(regions)
    except Exception as e:
      stderr.writeLine("Exception raised while processing reads: ", e.msg)
      quit()
  


proc main(argv: var seq[string]): int =
  let args = docopt("""
  Usage: fu-16Sregion [options] [<FASTQ-File>]

  Options:
    -r --reference FILE       FASTA file with a reference sequence, E. coli 16S by default
    -j --regions FILE         Regions names in JSON format, E. coli variable regions by default
    -m --max-reads INT        Parse up to INT reads then quit [default: 500]
    -s --min-score INT        Minimum alignment score (approx. %id * readlen * matchScore) [default: 2000]
    -f --min-fraction FLOAT   Minimum fraction of reads classified to report a region as detected [default: 0.5]
    
  Smith-Waterman:
    --score-match INT         Score for a match [default: 10]
    --score-mismatch INT      Score for a mismatch [default: -5]
    --score-gap INT           Score for a gap [default: -10]
  
  Other options:
    --pool-size INT           Number of sequences/pairs to process per thread [default: 25]
    -v --verbose              Verbose output
    --debug                   Enable diagnostics
    -h --help                 Show this help
    """, version=version(), argv=argv)

  let
    optMinScore = parseInt($args["--min-score"])
    optMaxReads = parseInt($args["--max-reads"])
    optMinClassRatio = parseFloat($args["--min-fraction"])
    optMatch    = parseInt($args["--score-match"])
    optMismatch = parseInt($args["--score-mismatch"])
    optGap      = parseInt($args["--score-gap"])
  var
    inputFile: string

  poolSize = parseInt($args["--pool-size"])
  
  # Check regions / import
  var
    loadedRegions: JsonNode
  if $args["--regions"] != "nil":
    try:
      loadedRegions = parseFile($args["--regions"])
    except Exception as e:
      stderr.writeLine("ERROR: Unable to load JSON regions from ", $args["--regions"], "\n", e.msg)
      quit(1)
    if args["--verbose"]:
      stderr.writeLine("Loading regions from: ", $args["--regions"])
  
  let
    regions = if fileExists($args["--regions"]): loadedRegions
              else: regionsTemplate

  # Check FASTA file?
  var
    loadedRef: string
  if $args["--reference"] != "nil":
    try:
      for referenceRecord in readfq($args["--reference"]):
        loadedRef = referenceRecord.sequence
        if args["--verbose"]:
          stderr.writeLine("Loading reference: ", referenceRecord.name)
        break
    except Exception as e:
      stderr.writeLine("ERROR: Unable to load reference from file: ", $args["--reference"], "\n", e.msg)
      quit(1)

  let ribosomalSeq = if len(loadedRef) > 0: loadedRef
                     else: defaultTarget

  # Check input files
  if $args["<FASTQ-File>"] == "nil":
    if args["--verbose"]:
      stderr.writeLine("Reading from STDIN...")
    inputFile = "-"
  else:
    if not fileExists($args["<FASTQ-File>"]):
      stderr.writeLine("Input file not found: ", $args["<FASTQ-File>"])
      quit(0)
    else:
      inputFile = $args["<FASTQ-File>"]
      if args["--verbose"]:
        stderr.writeLine("Reading from: ",  $args["<FASTQ-File>"])
  
 
  var
    counter = 0
    readspool : seq[FQRecord]
    responses = newSeq[FlowVar[seq[alignedRead]]]()

  let
    programParameters = primerOptions(
      minMatches:    1,
      maxMismatches: 1,
      matchThs:      1
    )
    alnParameters = swWeights(
      match: optMatch, 
      mismatch : optMismatch, 
      gap: optGap, 
      gapopening: optGap,
      minscore: optMinScore
    )
    regionsDict = regionsToDict(regions)
 
  if args["--verbose"]:
    stderr.writeLine("Starting. poolsize=", poolSize, "; minfract=", optMinClassRatio, "; maxreads=", optMaxReads)

  for R1 in readfq(inputFile):
    counter += 1
    readspool.add(R1)

    if counter mod poolSize == 0:
      if args["--debug"]:
        stderr.writeLine("[",counter, "] spawning thread")
      responses.add(spawn processSequenceArray(readspool, ribosomalSeq, programParameters, alnParameters, regionsDict, regions))
      readspool.setLen(0)

    if counter > optMaxReads:
      break

  responses.add(spawn processSequenceArray(readspool, ribosomalSeq, programParameters, alnParameters, regionsDict, regions))


  var
    hits = initCountTable[string]()
    total = 0
    classified = 0
  for resp in responses:
    if args["--debug"]:
      stderr.writeLine("Receiving results from a working thread...")
    let alnArray = ^resp
    
    for aln in alnArray:
      if args["--verbose"]:
       stderr.writeLine(aln)
      
      total += 1
      if len(aln.regions) > 0:
        classified += 1
        hits.inc((aln.regions).join(","))
 
      else:
        hits.inc("unaligned")
    
  
  if args["--verbose"]:
    stderr.writeLine("End. ", classified, "/", total, " reads classified.")
  
  for region, count in hits:
    if float(count) / float(total) > optMinClassRatio:
      let ratio = (float(count) / float(total)).formatFloat(ffDecimal, 2)
      echo region, "\t", ratio
when isMainModule:
  main_helper(main)
