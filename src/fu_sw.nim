import docopt
import readfq
import strformat
import os, strutils, sequtils
import threadpool
import ./seqfu_utils

const NimblePkgVersion = "undef"
const programVersion = if NimblePkgVersion == "undef": "X.9"
                       else: NimblePkgVersion
let programName = "fu-sw"

var poolsize = 200

type
  swAlignment* = object
    top*, bottom*, middle*: string
    score*, length*: int
    pctid*: float
    queryStart*, queryEnd*, targetStart*, targetEnd*: int

type
  swWeights* = object
    match*, mismatch*, gap*, gapopening*: int
    minscore*: int

let
  swDefaults* = swWeights(
    match:       6,
    mismatch:   -4,
    gap:        -6,
    gapopening: -6,
    minscore:    1 )


proc makeMatrix*[T](rows, cols: int, initValue: T): seq[seq[T]] =
  var result: seq[seq[T]] = newSeq[seq[T]](rows)
  for i in 0..<rows:
    result[i] = newSeq[T](cols)
    for j in 0..<cols:
      result[i][j] = initValue
  return result

proc simpleSmithWaterman*(alpha, beta: string, weights: swWeights): swAlignment =
  const
    cNone    = -1
    cUp      = 1
    cLeft    = 2
    cDiag    = 3
    mismatchChar = ' '
    matchChar    = '|'

  var
    swMatrix: seq[seq[int]]
    swHelper: seq[seq[int]]
    iMax, jMax, scoreMax = -1

  swMatrix = makeMatrix(len(alpha) + 1, len(beta) + 1, 0)
  swHelper = makeMatrix(len(alpha) + 1, len(beta) + 1, -1)

  for i in 0..len(alpha):
    for j in 0..len(beta):
      if i == 0 or j == 0:
        swMatrix[i][j] = 0
        swHelper[i][j] = cNone
      else:
        let
          score = if alpha[i - 1] == beta[j - 1]: weights.match
                 else: weights.mismatch
          top = swMatrix[i][j - 1] + weights.gap
          left = swMatrix[i - 1][j] + weights.gap
          diag = swMatrix[i - 1][j - 1] + score

        if diag < 0 and left < 0 and top < 0:
          swMatrix[i][j] = 0
          swHelper[i][j] = cNone
          continue

        if diag >= top:
          if diag >= left:
            swMatrix[i][j] = diag
            swHelper[i][j] = cDiag
          else:
            swMatrix[i][j] = left
            swHelper[i][j] = cLeft
        else:
          if top >= left:
            swMatrix[i][j] = top
            swHelper[i][j] = cUp
          else:
            swMatrix[i][j] = left
            swHelper[i][j] = cLeft

        if swMatrix[i][j] > scoreMax:
          scoreMax = swMatrix[i][j]
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
    if swHelper[I][J] == cNone:
      result.queryStart  = I
      result.targetStart = J
      result.queryEnd    += I
      result.targetEnd   += J
      break
    elif swHelper[I][J] == cDiag:
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

    elif swHelper[I][J] == cLeft:
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



type
  primerOptions* = object
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


proc main(args: var seq[string]): int =
  let args = docopt("""
  Usage: fu-sw [options] -q QUERY -t TARGET

  Options:
    -q --query <FILE>         File with the sequence(s) to align against target
    -t --target <FILE>        File with the target sequence(s)
    -i --id ID                Align only against the sequence named `ID` in the target file
    -s --showaln              Show graphical alignment
    
  Smith-Waterman options:
    --score-match INT         Score for a match [default: 10]
    --score-mismatch INT      Score for a mismatch [default: -8]
    --score-gap INT           Score for a gap [default: -10]
    --min-score INT           Minimum alignment score [default: 80]
    --pct-id FLOAT            Minimum percentage of identity [default: 85]
  
  Other options:
    --pool-size INT           Number of sequences/pairs to process per thread [default: 20]
    -v --verbose              Verbose output
    -h --help                 Show this help
    """, version=version(), argv=commandLineParams())

  var
    query = $args["--query"]
    target = $args["--target"] 
    pctid = parseFloat($args["--pct-id"])


  let
    optMatch = parseInt($args["--score-match"])
    optMismatch = parseInt($args["--score-mismatch"])
    optGap      = parseInt($args["--score-gap"])
    optMinScore = parseInt($args["--min-score"])

  if not fileExists(query):
    stderr.writeLine("ERROR: Query file not found: ", query)
    quit(1)

  
  if not fileExists(target):
    stderr.writeLine("ERROR: Target file not found: ", target)
    quit(1)

  poolSize = parseInt($args["--pool-size"])
 
  var
    counter = 0
    readspool : seq[FQRecord]
    responses = newSeq[FlowVar[int]]()

  let
    primerParameters = primerOptions(
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


  var
    targets = newSeq[FQRecord]()
  


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



when isMainModule:
  main_helper(main)
