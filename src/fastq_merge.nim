import os
import klib
import ./seqfu_utils
import strutils


type
  mergeOptions = object
    minlen: int
    minid: float
    start: int
    accepted_identity: float

type
  joinedRecord = object
    record: FastxRecord
    joined: bool
    score: float

proc fxToString(s: FastxRecord): string =
  if len(s.qual) > 0:
    "@" & s.name & " " & s.comment & "\n" & s.seq & "\n+\n" & s.qual
  else:
    ">" & s.name & " " & s.comment & "\n" & s.seq & "\n"

proc fxToString(s: joinedRecord): string =
  if len(s.record.qual) > 0:
    "@" & s.record.name & " " & s.record.comment & "\n" & s.record.seq & "\n+\n" & s.record.qual
  else:
    ">" & s.record.name & " " & s.record.comment & "\n" & s.record.seq & "\n"

    
proc joinreads(R1, raw_R2: FastxRecord, o: mergeOptions): joinedRecord =
  let R2 = revcompl(raw_R2)
  var max = if R1.seq.high > R2.seq.high: R2.seq.high
            else:  R1.seq.high
  
  var max_score = 0.0
  var pos = 0
  var str : string
  var joinedSeq: FastxRecord

  for i in o.minlen .. max:
    var
      s1 = R1.seq[R1.seq.high - i .. R1.seq.high]
      s2 = R2.seq[0 .. 0 + i ]
      q1 = R1.qual[R1.seq.high - i .. R1.seq.high]
      q2 = raw_R2.qual[raw_R2.seq.high - i .. raw_R2.seq.high]
      score = 0.0
      

    for i in 0 .. s1.high:
      if s1[i] == s2[i]:
        score += 1
   
    score = score / float(len(s1))

    if score > max_score:
      max_score = score
      pos = i
      str = s1
      if score > o.accepted_identity:
        break
  # end loop

  # Fix mismatches
  if max_score > o.minid:
    joinedSeq.name = R1.name
    joinedSeq.seq = R1.seq & R2.seq[pos + 1 .. ^1]
    joinedSeq.qual = R1.qual & R2.qual[pos + 1 .. ^1]
    result.record = joinedSeq
    result.joined = true
    result.score = max_score
    return
  else:
    result.record = R1 
    result.joined = false
    result.score = 0.0
    return

  


proc fastq_merge(argv: var seq[string]): int {.gcsafe.} =
    
  let args = docopt("""
Usage: merge [options] -1 <file_R1> [-2 <file_R2>]

Options:
  -i, --minid FLOAT            Minimum identity [default: 0.80]
  -m, --minlen INT             Minimum overlap [default: 20]
  --accepted-identity FLOAT    Accept fusion when identity is above FLOAT [default: 0.95]
  -v, --verbose                Print verbose messages
  -h, --help                   Show this help

  
  """, version=version(), argv=argv)
 
  
  let
    file_R1 = $args["<file_R1>"]
    file_R2 = guessR2(file_R1)
  
  var 
    sourceOptions: mergeOptions

  try:
    sourceOptions.minlen = parseInt($args["--minlen"])
    sourceOptions.minid  = parseFloat($args["--minid"])
    sourceOptions.accepted_identity = parseFloat($args["--accepted-identity"])
  except Exception as e:
    stderr.writeLine("Error parsing options. Check --help.", "\n", e.msg)
    quit(1)

  if not fileExists(file_R1):
    stderr.writeLine("ERROR: Unable to find file R1: ", file_R1)
  if not fileExists(file_R2):
    stderr.writeLine("ERROR: Unable to find file R2. ", file_R2)
  

  initClosure(getR1,readfq(file_R1))
  initClosure(getR2,readfq(file_R2))

  let
    opt = sourceOptions

  var R1 = xopen[GzFile](fileR1)
  defer: R1.close()
  var read1: FastxRecord

  var R2 = xopen[GzFile](fileR2)
  defer: R2.close()
  var read2: FastxRecord

  while R1.readFastx(read1):
    R2.readFastx(read2)

    let joined = joinreads(read1, read2, opt)
    echo fxToString(joined)