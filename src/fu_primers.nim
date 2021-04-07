import docopt
import readfq, iterutils
import os, strutils, re, sequtils
import threadpool
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programName = "fu-primers"
const programVersion = if NimblePkgVersion == "undef": "X.9"
                       else: NimblePkgVersion


var
  poolsize = 100
 
type
  trimmingResults = object
    input,     output,     trimmed: int

type
  primerOptions = object
    primers: seq[string]
    margin: int
    minMatches, maxMismatches: int
    matchThs: float

proc version(): string =
  return programName  & " " & programVersion

proc processRead(read: FQRecord, opts: primerOptions): FQRecord =
  result.name = read.name
  result.comment = read.comment

  let 
    slen = len(read.sequence)
  var
    trimFrom = 0
    trimEnd = slen

  for primer in opts.primers:
    let 
      plen = len(primer)
      primerMatches = findPrimerMatches(read.sequence, primer, opts.matchThs, opts.maxMismatches, opts.minMatches)

    for m in concat(primerMatches[0], primerMatches[1]) :
      if (m > (0 + opts.margin) ) and (m+plen < (slen - opts.margin)):
        # Primer match inside the sequence: discard
        result.sequence = ""
        result.quality  = ""
        return
      else:
        # Primer match possibly at the extremities (trim)
        if  m <= (0 + opts.margin):
          if trimFrom < m + plen:
            trimFrom = m + plen
        elif m+plen >= slen - opts.margin:
          if trimEnd > m:
            trimEnd = m

  if trimEnd - trimFrom < 2:
      result.sequence = ""
      result.quality = ""
      return

  result.sequence = read.sequence[trimFrom ..< trimEnd]
   
  if len(read.quality) > 0:
    result.quality  = read.quality[trimFrom  ..< trimEnd]

proc processSequencePairsArray(pool: seq[FQRecord], opts: primerOptions, minlen: int): trimmingResults =
  result.input = 2 * (pool.high + 1)
  var
    results1 = newSeq[FQRecord]()
    results2 = newSeq[FQRecord]()
  for i in 0 .. pool.high:
    if i mod 2 == 1:
      let 
        trim1 = processRead(pool[i-1], opts)
        trim2 = processRead(pool[i], opts)

      if len(trim1.sequence) > minlen and len(trim2.sequence) > minlen:
        result.output += 2
        results1.add(trim1)
        results2.add(trim2)
        if len(trim1.sequence) < len(pool[i-1].sequence) or len(trim2.sequence) < len(pool[i].sequence):
          result.trimmed += 1

  for (r, s) in zip(results1, results2):
    stdout.write( '@' & r.name & "\n" & r.sequence & "\n+\n" & r.quality & "\n" )
    stdout.write( '@' & s.name & "\n" & s.sequence & "\n+\n" & s.quality & "\n" )
    
proc processSequenceSingleArray(pool: seq[FQRecord], opts: primerOptions, minlen: int): trimmingResults =
  result.input = pool.high + 1
  var
    results = newSeq[FQRecord]()
  for i in 0 .. pool.high:
    let trimmed = processRead(pool[i], opts)
    if len(trimmed.sequence) >= minlen:
      result.output += 1
      results.add(trimmed)
  
  for r in results:
    stdout.write( '@' & r.name & "\n" & r.sequence & "\n+\n" & r.quality & "\n" )
  

proc main(args: seq[string]) =
  let args = docopt("""
  Usage: fu-primers [options] -1 <FOR> [-2 <REV>]

  This program currently only supports paired-end Illumina reads.

  Options:
    -1 --first-pair <FOR>     First sequence in pair
    -2 --second-pair <REV>    Second sequence in pair (can be guessed)
    -f --primer-for FOR       Sequence of the forward primer [default: CCTACGGGNGGCWGCAG]
    -r --primer-rev REV       Sequence of the reverse primer [default: GGACTACHVGGGTATCTAATCC]
    -m --min-len INT          Minimum sequence length after trimming [default: 50]
    --primer-thrs FLOAT       Minimum amount of matches over total length [default: 0.8]
    --primer-mismatches INT   Maximum number of missmatches allowed [default: 2]
    --primer-min-matches INT  Minimum numer of matches required [default: 8]
    --primer-pos-margin INT   Number of bases from the extremity of the sequence allowed [default: 2]
    --pattern-R1 <tag-1>      Tag in first pairs filenames [default: auto]
    --pattern-R2 <tag-2>      Tag in second pairs filenames [default: auto]
    -v --verbose              Verbose output
    -h --help                 Show this help
    """, version=version(), argv=args)

  var
    file_R2: string
    file_R1 = $args["--first-pair"]
    sampleId, direction: string
    respCount = 0
    inputIsPaired = true

  let
    p1for = $args["--primer-for"]
    p2for = $args["--primer-rev"]
    p1rev = p1for.revcompl()
    p2rev = p2for.revcompl()
    minLen = parseInt( $args["--min-len"] )

  # Check essential parameters
  if (not args["--first-pair"]):
    stderr.writeLine("Missing required parameter -1 (--first-pair)")
    quit(0)

  # Try inferring second filename
  if (not args["--second-pair"]):
    if $args["--pattern-R1"] == "auto" and $args["--pattern-R2"] == "auto":
        # automatic guess
        if match(file_R1, re".+_R1_.+"):
          file_R2 = file_R1.replace(re"_R1_", "_R2_")
        elif match(file_R1, re".+_1\..+"):
          file_R2 = file_R1.replace(re"_R1\.", "_R2.")
        elif match(file_R1, re".+_R1\..+"):
          file_R2 = file_R1.replace(re"_R1\.", "_R2.")
        else:
          if args["--verbose"]:
            stderr.writeLine("Processnig as Single End: tag not found")
          inputIsPaired = false
    else:
      # user defined patterns
      if match(file_R1, re(".+" & $args["--pattern-R1"] & ".+") ):
        file_R2 = file_R1.replace(re($args["--pattern-R1"]), $args["--pattern-R2"])
      else:
        stderr.writeLine("Processing single-end file")
        inputIsPaired = false
  else:
    file_R2 = $args["--second-pair"]

  if not fileExists(file_R1):
    stderr.writeLine("ERROR: File R1 not found: ", fileR1)
    quit(1)
  
  if  not fileExists(file_R2):
    inputIsPaired = false

  initClosure(getR1,readfq(file_R1))
  initClosure(getR2,readfq(file_R2))


  if $args["--first-pair"] != "nil" and args["--verbose"]:
    stderr.writeLine("# Primer Forward: ", p1for, ":", p1rev)
    stderr.writeLine("# Primer Reverse: ", p2for, ":", p2rev)

  var
    counter = 0
    readspool : seq[FQRecord]
    responses = newSeq[FlowVar[trimmingResults]]()

  let
    programParameters = primerOptions(
      primers:       @[p1for, p2for],
      margin:        parseInt(   $args["--primer-pos-margin"]  ),
      minMatches:    parseInt(   $args["--primer-min-matches"] ),
      maxMismatches: parseInt(   $args["--primer-mismatches"]  ),
      matchThs:      parseFloat( $args["--primer-thrs"]        )
    )


  if inputIsPaired == true:
    for (R1, R2) in zip(getR1, getR2):
      counter += 1

      readspool.add(R1)
      readspool.add(R2)

      if counter mod poolSize == 0:
        responses.add(spawn processSequencePairsArray(readspool, programParameters, minLen))
        readspool.setLen(0)

    # Process last sequences
    responses.add(spawn processSequencePairsArray(readspool, programParameters, minLen))



  else:
    for R1 in getR1:
      counter += 1
      readspool.add(R1)

      if counter mod poolSize == 0:
        responses.add(spawn processSequenceSingleArray(readspool, programParameters, minLen))
        readspool.setLen(0)

    # Process last sequences
    responses.add(spawn processSequenceSingleArray(readspool, programParameters, minLen))

  # Wait responses
  var
    processed = 0
    filteredout = 0
    trimmed = 0
  for resp in responses:
    let s = ^resp
    processed += s.input
    filteredout += s.output
    trimmed += s.trimmed

  filteredout = processed - filteredout
  if args["--verbose"]:
    stderr.writeLine("Seqs: ", processed, "; Trimmed: ", trimmed, "; Discarded: ", filteredout)
 
    




when isMainModule:
  main(commandLineParams())
