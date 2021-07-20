import threadpool
import klib
import docopt, strutils, tables, math
import os
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const prog = "fu-orf"
const version = if NimblePkgVersion == "undef": "<preprelease>"
                else: NimblePkgVersion
const minSeqLen = 18

  
type
    mergeCfg = tuple[join: bool, minId: float, minOverlap, maxOverlap, minorf: int]

proc length*(self:FastxRecord): int = 
  ## returns length of sequence
  self.seq.len()

proc `$`*(s: FastxRecord): string = 
  "@" & s.name & " " & s.comment & "\n" & s.seq & "\n+\n" & s.qual

iterator codons(self: FastxRecord) : string = 
  var i = 0
  var s = self.seq.toUpperAscii
  while i < self.length - 2:
    let codon = s[i .. i+2]
    if codon.len == 3:
       yield codon
    i += 3

proc kmer2num*(kmer:string):int =
  ## converts a kmer string into an integer 0..4^(len-1)
  let baseVal = {'T': 0, 'C': 1, 'A': 2, 'G': 3, 'U': 0}.toTable
  let klen = len(kmer)
  var num = 0
  for i in 0..(klen - 1):
    try:
      let p = 4^(klen - 1 - i)
      num += p * baseVal[kmer[i]]
    except:
      num = -1
      break
  num

proc num2kmer*(num, klen:int):string =
  ## converts an integer into a kmer string given the number and length of kmer
  let baseVal = {0:'T', 1:'C', 2:'A', 3:'G'}.toTable
  var kmer = repeat(" ",klen)
  var n = num
  for i in 0..(klen - 1):
    let p = 4^(klen - 1 - i)
    var baseNum = int(n/p)
    kmer[i] = baseVal[baseNum]
    n = n - p*baseNum
  kmer

proc translate*(self:FastxRecord, code = 1): FastxRecord = 
  ## translates a nucleotide sequence with the given genetic code number: https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi for codes
  var codeMap = 
    ["FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSS**VVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCWWTTTTPPPPHHQQRRRRIIMMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSSSSVVVVAAAADDEEGGGG",
     "FFLLSSSSYYQQCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "", "",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNNKSSSSVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCCWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CC*WLLLSPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSSGGVVVVAAAADDEEGGGG",
     "FFLLSSSSYYY*CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNNKSSSSVVVVAAAADDEEGGGG",
     "",
     "FFLLSSSSYY*LCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "", "", "", "",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNNKSSSSVVVVAAAADDEEGGGG",
     "FFLLSS*SYY*LCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FF*LSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSSKVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CCGWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYY**CC*WLLLAPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYYQQCCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYYQQCCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYYYYCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYYEECC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
     "FFLLSSSSYYEECCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG"]
  var code = codeMap[code - 1]
  var transeq = newseq[char]()
  for codon in self.codons:
    let num = kmer2num(codon)
    if num != -1:
      transeq.add(code[num])
    else:
      transeq.add('-')
  result = self
  result.seq = transeq.join


proc verbose(msg: string, print: bool) =
  if print:
    stderr.writeLine(" * ", msg)

proc format_dna(seq: string, format_width: int): string =
  if format_width == 0:
    return seq
  for i in countup(0,seq.len - 1,format_width):
 
    if (seq.len - i <= format_width):
      result &= seq[i..seq.len - 1]
    else:
      result &= seq[i..i + format_width - 1] & "\n"



proc translateAll(input: FastxRecord, minOrfSize=10): seq[string] =
  var
    rawprots : seq[string]
      
  for sequence in @[input, input.revcompl()]:
    if len(sequence.seq) < minSeqLen:
      break
    for frame in @[0, 1, 2]:
      let
        dna = sequence.seq[frame .. ^1]
      var
        obj : FastxRecord
      obj.seq = dna
      rawprots.add( obj.translate().seq )
  
  for translatedseq in rawprots:
    let translations : seq = translatedseq.split('-')
    for t in translations:
      if len(t) > minOrfSize:
        let orfs = t.split('*')
        for orf in orfs:
          if len(orf) > minOrfSize:
            result.add(orf)
      
 
proc mergePair(R1, R2: FastxRecord, minlen=10, minid=0.85, identityAccepted=0.90): FastxRecord {.discardable.} = 
  var REV = revcompl(R2) 
  var max = if R1.seq.high > REV.seq.high: REV.seq.high
          else:  R1.seq.high
  
  var max_score = 0.0
  var pos = 0
  var str : string

  for i in minlen .. max:
    var
      s1 = R1.seq[R1.seq.high - i .. R1.seq.high]
      s2 = REV.seq[0 .. 0 + i ]
      q1 = R1.qual[R1.seq.high - i .. R1.seq.high]
      q2 = R2.qual[R2.seq.high - i .. R2.seq.high]
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
    result.name = R1.name
    result.seq = R1.seq & REV.seq[pos + 1 .. ^1]
    result.qual = R1.qual & REV.qual[pos + 1 .. ^1]
  else:
    result = R1

proc processPair(R1, R2: FastxRecord, opts: mergeCfg): string =
  var
    orfs: seq[string]
    s1, s2: FastxRecord
    joined = false
    counter = 0

  if opts.join:
    s1 = mergePair(R1, R2, opts.minOverlap, opts.minId)
    
    if length(s1) == length(R1):
      joined = false
    else:
      joined = true

  if joined == true:
    orfs.add( translateAll(s1, opts.minorf) )
  else:
    orfs.add( translateAll(R1, opts.minorf))
    orfs.add( translateAll(R2, opts.minorf))
  
  for peptide in orfs:
    counter += 1
    result &= '>' & R1.name & "_" & $counter & "/" & $(len(orfs)) & "\n" & peptide & "\n"

  
proc parseArray(pool: seq[FastxRecord], opts: mergeCfg): string =
  for i in 0 .. pool.high:
    if i mod 2 == 1:
      try:
        result &= processPair(pool[i - 1], pool[i], opts)  
      except:
        result &= processPair(pool[i - 1], pool[i], opts) 
        quit()

   
proc main(argv: var seq[string]): int =
  let args = docopt("""
  fu-orf

  Extract ORFs from Paired-End reads.

  Usage: 
  fu-orf [options] -1 File_R1.fq

  Options:
    -1, --R1 FILE          First paired end file
    -2, --R2 FILE          Second paired end file
    -m, --min-size INT     Minimum ORF size (aa) [default: 25]
    -p, --prefix STRING    Rename reads using this prefix
    --min-overlap INT      Minimum PE overlap [default: 12]
    --max-overlap INT      Maximum PE overlap [default: 200]
    --min-identity FLOAT   Minimum sequence identity in overlap [default: 0.80]
    -j, --join             Attempt Paired-End joining
    --pool-size INT        Size of the sequences array to be processed
                           by each working thread [default: 250]
    --verbose              Print verbose log
    --help                 Show help
  """, version=version, argv=argv)
  var
    fileR1, fileR2: string
    minOrfSize, counter: int
    verbose: bool
    mergeOptions: mergeCfg
    respCount = 0
    poolSize : int
    prefix : string
    singleEnd = true

  try:
    fileR1 = $args["--R1"]
    fileR2 = $args["--R2"]
    minOrfSize = parseInt($args["--min-size"])
    verbose = args["--verbose"]
    poolSize = parseInt($args["--pool-size"])
    prefix = $args["--prefix"]
    mergeOptions = (join: args["--join"] or false,  minId: parseFloat($args["--min-identity"]), minOverlap: parseInt($args["--min-overlap"]), maxOverlap: parseInt($args["--max-overlap"]), minorf: minOrfSize)
  except:
    stderr.writeLine("Use fu-orf --help")
    stderr.writeLine("Arguments error: ", getCurrentExceptionMsg())
    quit(0)

    
  if len(fileR1) == 0:
    verbose("Missing required parameters: -1 FILE1 [-2 FILE2]", true)
    quit(0)

  if not fileExists(fileR1):
    stderr.writeLine("FATAL ERROR: File [-1] ", fileR1, " not found.")
    quit(1)
  if fileR2 != "nil" and not fileExists(fileR2):
    stderr.writeLine("FATAL ERROR: File [-2] ", fileR2, " not found.")
    quit(1)
  elif fileR2 == "nil":
    verbose("Single end mode", args["--verbose"])
    singleEnd = true
  

  var R1 = xopen[GzFile](fileR1)
  defer: R1.close()
  var read1: FastxRecord
  verbose("Reading R1:" & fileR1, verbose)


  
  var readspool : seq[FastxRecord]
  var responses = newSeq[FlowVar[string]]()
  if not singleEnd:
    var R2 = xopen[GzFile](fileR2)
    defer: R2.close()
    var read2: FastxRecord
    verbose("Reading R2:" & fileR2, verbose)
    while R1.readFastx(read1):
      counter += 1
      if prefix != "nil":
        read1.name = prefix & $counter
        read2.name = prefix & $counter
      R2.readFastx(read2)
      
      readspool.add(read1)
      readspool.add(read2)  

      if counter mod poolSize == 0:
        responses.add(spawn parseArray(readspool, mergeOptions))
        readspool.setLen(0)

    responses.add(spawn parseArray(readspool, mergeOptions))
    
    for resp in responses:
      let s = ^resp
      stdout.write(s)
  else:
    while R1.readFastx(read1):
      counter += 1
      if prefix != "nil":
        read1.name = prefix & $counter
         
      readspool.add(read1)
      if counter mod poolSize == 0:
        responses.add(spawn parseArray(readspool, mergeOptions))
        readspool.setLen(0)

    responses.add(spawn parseArray(readspool, mergeOptions))
    
    for resp in responses:
      let s = ^resp
      stdout.write(s)

when isMainModule:
  main_helper(main)
