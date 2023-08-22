import docopt
import readfq
import json
import os, strutils, sequtils

import tables, algorithm
import ./seqfu_utils
import ./fu_sw

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
    
    result.sort()

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
    -m --max-reads INT        Parse up to INT reads then quit [default: 1000]
    -s --min-score INT        Minimum alignment score (approx. %id * readlen * matchScore) [default: 1000]
    -f --min-fraction FLOAT   Minimum fraction of reads classified to report a region as detected [default: 0.25]
    -c --min-coverage FLOAT   Minimum fraction of variable region to be reported [default: 0.40]
    
  Smith-Waterman:
    --score-match INT         Score for a match [default: 10]
    --score-mismatch INT      Score for a mismatch [default: -5]
    --score-gap INT           Score for a gap [default: -10]


    -v --verbose              Verbose output
    --debug                   Enable diagnostics
    -h --help                 Show this help

  Unused options:
    --pool-size INT           Number of sequences/pairs to process per thread [default: 1]
    --max-threads INT         Maximum number of working threads [default: 128]    
  """, version=programVersion, argv=argv)

  let
    optMinScore = parseInt($args["--min-score"])
    optMaxReads = parseInt($args["--max-reads"])
    optMinClassRatio = parseFloat($args["--min-fraction"])
    optMinCoverage   = parseFloat($args["--min-coverage"])
    optMatch    = parseInt($args["--score-match"])
    optMismatch = parseInt($args["--score-mismatch"])
    optGap      = parseInt($args["--score-gap"])
    optMaxThreads = parseInt($args["--max-threads"])
  var
    inputFile: string

  poolSize = parseInt($args["--pool-size"])
  #setMaxPoolSize(optMaxThreads)

  # Check regions / import
  var
    loadedRegions: JsonNode
  if $args["--regions"] != "nil":
    try:
      loadedRegions = parseFile($args["--regions"])
    except Exception as e:
      stderr.writeLine("ERROR: Unable to load JSON regions from ", $args["--regions"], "\n", e.msg)
      quit(1)
    if bool(args["--verbose"]):
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
        if bool(args["--verbose"]):
          stderr.writeLine("Loading reference: ", referenceRecord.name)
        break
    except Exception as e:
      stderr.writeLine("ERROR: Unable to load reference from file: ", $args["--reference"], "\n", e.msg)
      quit(1)

  let ribosomalSeq = if len(loadedRef) > 0: loadedRef
                     else: defaultTarget

  # Check input files
  if $args["<FASTQ-File>"] == "nil":
    stderr.writeLine("[fu-16sregion] Reading from STDIN...")
    inputFile = "-"
  else:
    if not fileExists($args["<FASTQ-File>"]):
      stderr.writeLine("Input file not found: ", $args["<FASTQ-File>"])
      quit(0)
    else:
      inputFile = $args["<FASTQ-File>"]
      if bool(args["--verbose"]):
        stderr.writeLine("# Reading from: ",  $args["<FASTQ-File>"])
  
 
 
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
 
  if bool(args["--verbose"]):
    stderr.writeLine("# Starting. minfract=", optMinClassRatio, "; maxreads=", optMaxReads)

  var
    seqCounter = 0
    regFreqs = initCountTable[string]()
    index: seq[string]
  for R1 in readfq(inputFile):
    seqCounter += 1
    if seqCounter > optMaxReads:
      if bool(args["--verbose"]):
        stderr.writeLine("# Reached max reads: ", optMaxReads)
      break
    
    let aln = simpleSmithWaterman(R1.sequence, ribosomalSeq, alnParameters)
    let reg = alnToRegs(aln.targetStart, aln.targetEnd, regionsDict)
    let filt = filtRegs(reg, regions, optMinCoverage)
    let region = if len(filt) > 0: join(filt, ",")
                 else: "Unclassified"
    if bool(args["--verbose"]):
      #M05517:39:000000000-CNNWR:1:1105:7840:22808   score:2955  alignment:340..805  regions:V3,V4  Pass
      let status = if len(filt) > 0: "Pass"
                   else: "Fail"
      stderr.writeLine(R1.name, "\t", "score:", aln.score, "\t", "alignment:", aln.targetStart, "..", aln.targetEnd, "\t", "regions:", region, "\t", status)
    
    regFreqs.inc(region)
  

  for k in regFreqs.keys:
    index.add k
  regFreqs.sort()
  
  for region, hits in regFreqs:
    let  ratio = hits / seqCounter
    if ratio > optMinClassRatio:
      echo  region, "\t", formatFloat(100 * ratio,format=ffDecimal,precision=2)
      break

when isMainModule:
  main_helper(main)
