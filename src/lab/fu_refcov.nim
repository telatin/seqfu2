import docopt
import readfq
import sequtils
import os, strutils
import algorithm
  
import tables
 
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programVersion = if NimblePkgVersion == "undef": "0.0.2-alpha"
                       else: NimblePkgVersion
let
  programName = "fu-refc"
   


type
  Position = tuple[chrname: string, pos: int]

proc `$`(p: Position): string =
  $(p.chrname) & ":" & $(p.pos)

proc `>`(x,y: Position): bool = 
  if x.chrname == y.chrname:
    x.pos > y.pos
  else:
    cmp(x.chrname, y.chrname) < 0

proc pSort(x, y: Position): int =
  if x.chrname == y.chrname:
    if x.pos == y.pos:
      return 0
    elif x.pos > y.pos:
      return 1
    else:
      return -1
  else:
    return cmp(x.chrname, y.chrname)


proc scanKmers(file: string, kmersize: int): Table[string, Position] =
  var 
    tot = 0
    discarded = 0
    positions: Table[string, seq[Position]]
  for refRecord in readfq(file):
    for pos in 1 .. (len(refRecord.sequence) - kmersize):
      let 
        kmerStr = refRecord.sequence[pos .. pos + kmersize - 1]
        kmer = min(kmerStr, kmerStr.revcompl())
      
      var
        position : Position = (chrname: refRecord.name, pos: pos)
      
      if kmer in positions:
        positions[kmer].add(position)
      else:
        positions[kmer] = @[position]
  for kmer, poss in positions:
    tot += 1
    if len(poss) == 1:
      result[kmer] = poss[0]
    else:
      discarded += 1

 
proc version(): string =
  return programName  & " " & programVersion

 

proc main(args: var seq[string]): int =
  let args = docopt("""
  Usage: fu-nanotags [options] -r ref.fa [<fastq-file>...]

  Options:
    -r, --reference FASTA      Sequence string OR file with the sequence(s) to align against reads
    -k, --kmer-size INT        Kmer size [default: 15]
    -s, --showaln              Show graphical alignment
    -c, --cut INT              Cut input reads at INT position [default: 300]
    -x, --disable-rev-comp     Do not scan reverse complemented reads

  Other options:
    --pool-size INT            Number of sequences to process per thread, not implemented [default: 25]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

 
  var
    inputFiles = newSeq[string]()
    covPos = OrderedTable[Position, int]()

  # Input sanitation
  for file in args["<fastq-file>"]:
    if not fileExists(file):
      stderr.writeLine("File not found: " & file)
      quit()
    inputFiles.add(file)
  # Parse reference
  let kmerTable = scanKmers($args["--reference"], parseInt($args["--kmer-size"]))
  stderr.writeLine("Loaded " & $(len(kmerTable)) & " kmers")

  # Map reads
  for inputFile in inputFiles:
    stderr.writeLine("Processing " & inputFile)
    for fqRecord in readfq(inputFile):
      for pos in 1 .. (len(fqRecord.sequence) - parseInt($args["--kmer-size"])):
        let 
          kmerStr = fqRecord.sequence[pos .. pos + parseInt($args["--kmer-size"]) - 1]
          kmer = min(kmerStr, kmerStr.revcompl())
        if kmer in kmerTable:
          if kmerTable[kmer] in covPos:
            covPos[kmerTable[kmer]] += 1
          else:
            covPos[kmerTable[kmer]] = 1

  #covPos.sort(proc (x, y: (int, string)): int = cmp(x[1], y[1]))
  #covPos.sort(proc (x, y: Position): int = cmp(x.pos, y.pos))
  var 
    seqKeys  = toSeq(keys(covPos))
  seqKeys.sort(pSort)

  # Scan
  for i, chrPos in seqKeys:
    let
      delta = if i > 0: covPos[chrPos] - covPos[seqKeys[i - 1]]
              else: 0
      star  = if abs(delta) > 100: "*"
              else: ""
    echo chrPos, "\t", covPos[chrPos], "\t", delta, "\t", star

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
