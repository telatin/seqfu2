import docopt
import readfq
import strformat
import os, strutils, sequtils
 
import threadpool
import neo
import tables, algorithm
 
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programVersion = if NimblePkgVersion == "undef": "0.0.2-alpha"
                       else: NimblePkgVersion
let
  programName = "fu-nanotags"
   


var
  poolsize = 200



type
  swAlignment* = object
   top, bottom, middle: string
   score, length: int
   pctid: float
   queryStart, queryEnd, targetStart, targetEnd: int

type
  swWeights* = object
    match, mismatch, gap, gapopening: int
    minscore: int
 
 
 
 

proc simpleSmithWaterman(alpha, beta: string, weights: swWeights): swAlignment =

  # Constants defining path sources
  const
     cNone    = -1
     cUp      = 1
     cLeft    = 2
     cDiag    = 3
     mismatchChar = ' '
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
    matchCount, totCount = 0


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
        matchCount += 1
        totCount   += 1
      else:
        matchString  &= mismatchChar
        totCount   += 1
      I -= 1
      J -= 1

    elif swHelper[I, J] == cLeft:
      alignString1 &= alpha[I-1]
      alignString2 &= "-"
      matchString  &= " "
      result.queryEnd += 1
      I -= 1
      totCount   += 1
    else:
      alignString1 &= "-"
      matchString  &= " "
      alignString2 &= beta[J-1]
      result.targetEnd += 1
      J -= 1
      totCount   += 1


  result.top = reverse(alignString1)
  result.bottom = reverse(alignString2)
  result.middle = reverse(matchString)
  result.pctid  = 100 * matchCount / totCount


proc isDNA(s: string): bool = 
  let ch = @['A', 'C', 'G', 'T', 'N']
  for c in s.toUpper():
    if c notin ch:
      return false
  return true
 
proc version(): string =
  return programName  & " " & programVersion

template initClosure(id:untyped,iter:untyped) =
  let id = iterator():auto {.closure.} =
    for x in iter:
      yield x
 
proc processPair(R1, R2: FQRecord, reference: string, alnOpt: swWeights, regionsDict: Table[int, string]): string =
  let
   aln1 = simpleSmithWaterman(R1.sequence, reference, alnOpt)
   aln2 = simpleSmithWaterman(R2.sequence, reference, alnOpt)
  


proc processSequenceArray(pool: seq[FQRecord], reference: string, alnOpts: swWeights, regionsDict: Table[int, string]): int =
  for i in 0 .. pool.high:
    echo "::"


proc main(args: var seq[string]): int =
  let args = docopt("""
  Usage: fu-nanotags [options] -q QUERY [<fastq-file>...]

  Options:
    -q, --query TAGSEQ         Sequence string OR file with the sequence(s) to align against reads
    -s, --showaln              Show graphical alignment
    -c, --cut INT              Cut input reads at INT position [default: 300]
    -x, --disable-rev-comp     Do not scan reverse complemented reads
  
  Alignment options:
    -i, --pct-id FLOAT         Percentage of identity in the aligned region [default: 80.0]
    -m, --min-score INT        Minimum alignment score (0 for auto) [default: 0]
  
  Smith-Waterman parameters:
    -M, --weight-match INT     Match [default: 5]
    -X, --weight-mismatch INT  Mismatch penalty [default: -3]
    -G, --weight-gap INT       Gap penalty [default: -5]

  Other options:
    --pool-size INT            Number of sequences/pairs to process per thread [default: 25]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

  #check parameters
  try:
    discard parseInt($args["--weight-match"])
    discard parseInt($args["--weight-mismatch"])
    discard parseInt($args["--weight-gap"])
  except Exception as e:
    stderr.writeLine("Error in Smith-Waterman parameters: not integers.", e.msg)
    quit(1)

  try:
    discard parseFloat($args["--pct-id"])
    discard parseInt($args["--min-score"])
  except Exception as e:
    stderr.writeLine("Error in --pct-id or --min-score: should be FLOAT and INT respectively.\n", e.msg)
    quit(1)

  var
    cutLength   = parseInt($args["--cut"])
    queryFile   = $args["--query"]
    querySeqs   = newSeq[FQRecord]() 
    inputFiles  = newSeq[string]()
    pctid       = parseFloat($args["--pct-id"])
    autoScores  = newSeq[int]()
    optMinscore = parseInt($args["--min-score"])
  
  # Read tags 
  if not fileExists(queryFile):
    if args["--verbose"]:
      stderr.writeLine("Query passed as string: ", $args["--query"])

      let
        q = FQRecord(name: $args["--query"], sequence: $args["--query"])
      if isDNA(q.sequence):
        querySeqs.add(q)
      else:
        stderr.writeLine("ERROR: The query (-q) can either be a FILE or a DNA Sequence: ", q.sequence, " is neither.")
        quit(1)
  else:
    var
      tagCount = 0
    for faRecord in readfq(queryFile):
      tagCount += 1
      querySeqs.add(faRecord)
      autoScores.add( toInt( len(faRecord.sequence) * parseInt($args["--weight-match"]) / 2))
    
    if args["--verbose"]:
      stderr.writeLine(tagCount, " tags found in ", queryFile)

  
  if len(@( args["<fastq-file>"])) == 0:
    stderr.writeLine("Reading from stdin. Press Ctrl-C to exit. Use -h/--help for more info.")
    inputFiles.add("-")
  else:
    # Check input files
    for i in args["<fastq-file>"]:
      if fileExists(i) or i == "-":
        inputFiles.add(i)
      else:
        stderr.writeLine("WARNING: File ", i, " not found. Skipping.")

  if len(inputFiles) == 0:
    stderr.writeLine("ERROR: No files to analyse.")
    quit(1)

  poolSize = parseInt($args["--pool-size"])
 
  var
    parsedSequences = 0
    printedSequences = 0
    printedSequencesRev = 0
    counter = 0
    readspool : seq[FQRecord]
    responses = newSeq[FlowVar[int]]()

  var
    alnParameters = swWeights(
      match:      parseInt($args["--weight-match"]), 
      mismatch :  parseInt($args["--weight-mismatch"]), 
      gap:        parseInt($args["--weight-gap"]), 
      gapopening: parseInt($args["--weight-gap"]),
      minscore:   optMinscore
    )



  

  for inputFile in inputFiles:
    if args["--verbose"]:
      stderr.writeLine("Reading file: ", inputFile)
    for fqRecord in readfq(inputFile):
      parsedSequences += 1
      
      
      var
        tagsFoundFor = 0
        tagsFoundRev = 0
        tagsString = ""

      let
        readFor = if cutLength > 0 and len(fqRecord.sequence) >= cutLength: fqRecord.sequence[0 ..< cutLength]
                  else: fqRecord.sequence
        
        readRev = if not args["--disable-rev-comp"] and cutLength > 0 and len(fqRecord.sequence) >= cutLength: revcompl(fqRecord).sequence[0 ..< cutLength]
                  elif not args["--disable-rev-comp"]: revcompl(fqRecord).sequence
                  else: ""

        
      for index, querySeq in querySeqs:
        if optMinscore == 0:
          alnParameters.minscore = autoScores[index]
        let alnFor = simpleSmithWaterman(readFor, querySeq.sequence, alnParameters)
        let alnRev = if not args["--disable-rev-comp"]: simpleSmithWaterman(readRev, querySeq.sequence, alnParameters)
                     else: swAlignment()
        if alnFor.pctid >= pctid:
          tagsFoundFor += 1
          tagsString &= querySeq.name & ";"
          if args["--showaln"]:
            stderr.writeLine("# ", fqRecord.name, ":", querySeq.name, " strand=+;score=", alnFor.score, ";pctid=", fmt"{alnFor.pctid:.2f}%")
            stderr.writeLine(" > " ,alnFor.top, "\n > ", alnFor.middle, "\n > ", alnFor.bottom)
        if alnRev.pctid >= pctid:
          tagsFoundRev += 1
          tagsString &= querySeq.name & ";"
          if args["--showaln"]:
            stderr.writeLine("# ", fqRecord.name, ":", querySeq.name, " strand=-;score=", alnFor.score, ";pctid=", fmt"{alnRev.pctid:.2f}%")    
            stderr.writeLine(" < ", alnRev.top, "\n < ", alnRev.middle, "\n < ", alnRev.bottom)  
      if tagsFoundFor > 0 or tagsFoundRev > 0:
        printedSequences += 1
        if tagsFoundRev > 0:
          printedSequencesRev += 1

        if len(fqRecord.quality) > 0:
          echo "@", fqRecord.name, " ", fqRecord.comment, " tags=", tagsString
          echo fqRecord.sequence
          echo "+"
          echo fqRecord.quality
        else:
          echo ">", fqRecord.name, " ", fqRecord.comment, " tags=", tagsString
          echo fqRecord.sequence

  
  if args["--verbose"]:
    stderr.writeLine(printedSequences, "/", parsedSequences, " sequences printed, of which ", printedSequencesRev, " in reverse strand.")
    
#[
  for s in readfq(target):
    if $args["--id"] == "nil" or ($args["--id"] != "nil" and s.name == $args["--id"]):
      targets.add(s)
  
  let tab = "\t"
  for s in readfq(query):
    let r = revcompl(s)
    echo("# QUERY: ", s.name)
    for target in targets:
      echo("## TARGET: ", target.name)
      let alnFor = simpleSmithWaterman(s.sequence, target.sequence, alnParameters)
      let alnRev = simpleSmithWaterman(r.sequence, target.sequence, alnParameters)
      var rev = 0
      for aln in @[alnFor, alnRev]:
        
        let strand = if rev > 0: '-'
          else: '+'
        rev += 1
        
        if aln.pctid >= pctid:
          echo(fmt"Score: {aln.score} ({aln.pctid:.2f}%){tab}Length: {aln.length}{tab}Strand: {strand}{tab}Query: {aln.queryStart}-{aln.queryEnd}{tab}Target: {aln.targetStart}-{aln.targetEnd}")
          if args["--showaln"]:
            echo(' ', aln.top)
            echo(' ', aln.middle)
            echo(' ', aln.bottom)
      echo() 
]#



when isMainModule:
  main_helper(main)
