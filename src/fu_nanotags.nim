import docopt
import readfq
import strformat
import os, strutils, sequtils
 
import threadpool

import tables
 
import ./seqfu_utils
import ./fu_sw
const NimblePkgVersion {.strdefine.} = "undef"
const programVersion = if NimblePkgVersion == "undef": "0.0.2-alpha"
                       else: NimblePkgVersion
let
  programName = "fu-nanotags"
   


var
  poolsize = 200


 
 

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
    -r, --reverse-reads        Reverse complement reads that have the tags at the end (3')
  
  Alignment options:
    -i, --pct-id FLOAT         Percentage of identity in the aligned region [default: 80.0]
    -m, --min-score INT        Minimum alignment score (0 for auto) [default: 0]
  
  Smith-Waterman parameters:
    -M, --weight-match INT     Match [default: 5]
    -X, --weight-mismatch INT  Mismatch penalty [default: -3]
    -G, --weight-gap INT       Gap penalty [default: -5]

  Other options:
    --pool-size INT            Number of sequences to process per thread, not implemented [default: 25]
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
        q = FQRecord(name: $args["--query"], sequence: ($args["--query"]).toUpper() )
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
      let
        rec = FQRecord(name: faRecord.name, sequence: (faRecord.sequence).toUpper() )
      querySeqs.add(rec)
      autoScores.add( toInt( len(rec.sequence) * parseInt($args["--weight-match"]) / 2))
    
    if args["--verbose"]:
      stderr.writeLine(tagCount, " tags found in ", queryFile)
  
  # Check tags lenght
  for index, querySeq in querySeqs:
    if len(querySeq.sequence) > cutLength:
      stderr.writeLine("WARNING: Tag <", querySeq.name, "> is longer than the '--cut ", cutLength, "' size: ", len(querySeq.sequence))

  
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
    totalParsedSequences = 0
    totalPrintedSequences = 0
    totalPrintedSequencesRev = 0
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
    var 
      printedSequences = 0
      printedSequencesRev = 0
      parsedSequences = 0
    if args["--verbose"]:
      stderr.writeLine("Reading file: ", inputFile)
    for fqRecord in readfq(inputFile):
      parsedSequences += 1
      #if args["--verbose"]:
      #  stderr.writeLine("## Processing ", fqRecord.name)
      
      var
        tagsFoundFor = 0
        tagsFoundRev = 0
        tagsString = ""
        strand = 0

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
          let cov = float(alnFor.length) * 100 / float(len(querySeq.sequence))
          tagsFoundFor += 1
          tagsString &= querySeq.name & ";"
          if args["--showaln"]:
            stderr.writeLine("# ", fqRecord.name, ":", querySeq.name, fmt" strand=+;coverage={cov:.2f}%;score={alnFor.score};pctid={alnFor.pctid:.2f}%")
            stderr.writeLine(" > " ,alnFor.top, "\n > ", alnFor.middle, "\n > ", alnFor.bottom)
        
        if alnRev.pctid >= pctid:
          let cov = float(alnRev.length) * 100 / float(len(querySeq.sequence))
          tagsFoundRev += 1
          tagsString &= querySeq.name & ";"
          if args["--showaln"]:
            stderr.writeLine("# ", fqRecord.name, ":", querySeq.name, fmt" strand=-;coverage={cov:.2f}%;score={alnRev.score};pctid={alnRev.pctid:.2f}%")    
            stderr.writeLine(" < ", alnRev.top, "\n < ", alnRev.middle, "\n < ", alnRev.bottom)  
      if tagsFoundFor > 0 or tagsFoundRev > 0:
        printedSequences += 1
        if tagsFoundRev > 0:
          printedSequencesRev += 1
        if tagsFoundFor > tagsFoundRev:
          strand = 1
        else:
          strand = -1

        var printRecord = fqRecord
        if args["--reverse-reads"] and strand < 0:
          printRecord = revcompl(fqRecord)
        if len(printRecord.quality) > 0:
          echo "@", printRecord.name, " ", printRecord.comment, " tags=", tagsString
          echo printRecord.sequence
          echo "+"
          echo printRecord.quality
        else:
          echo ">", printRecord.name, " ", printRecord.comment, " tags=", tagsString
          echo printRecord.sequence

    # Current file statistics
    let
      ratio = printedSequences * 100 / parsedSequences
    stderr.writeLine(inputFile, "\t", fmt"{ratio:.2f}% (", printedSequences, "/", parsedSequences, ") sequences printed, of which ", printedSequencesRev, " in reverse strand.")

    # Update global counters
    totalParsedSequences += parsedSequences
    totalPrintedSequences += printedSequences
    totalPrintedSequencesRev += printedSequencesRev

  # Total statistics
  let
    ratio = totalPrintedSequences * 100 / totalParsedSequences
  stderr.writeLine("Total\t", fmt"{ratio:.2f}% (", totalPrintedSequences, "/", totalParsedSequences, ") sequences printed, of which ", totalPrintedSequencesRev, " in reverse strand.")
    
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
