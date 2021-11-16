import docopt
import readfq
 
import os
import tables
import strutils

import ./seqfu_utils
 


proc restart(s: FQRecord, i: int): FQRecord =

  result.name = s.name
  try:
    result.sequence =  s.sequence[i .. ^1] & s.sequence[0 ..< i]
  except:
    stderr.writeLine "Sequence length ", len(s.sequence), " is not long enough to rotate by ", i

  if len(s.quality) > 0:
    result.quality  =  s.quality[i .. ^1]  & s.quality[0 ..< i]
  else:
    result.quality = ""
  result.comment  =  s.comment

proc restartMotif(s: FQRecord, m: string, rc: bool):FQRecord =
  #proc findOligoMatches*(sequence, primer: string, threshold: float, max_mismatches = 0, min_matches = 6): seq[int] =
  let
    min = len(m)
    oligo_matches = findOligoMatches(s.sequence, m, 0.5, 0, min)
    
  if rc:
    let
      r = revcompl(s)
      rev_matches = findOligoMatches(r.sequence, m, 0.5, 0, min)
    if len(oligo_matches) > 0 and len(rev_matches) > 0:
      # Matches both in forward and in reverse: DISCARD
      return
    elif len(oligo_matches) == 1:
      return restart(s, oligo_matches[0])
    elif len(rev_matches) == 1:
      return restart(r, rev_matches[0])
    else:
      # Multimatch in forward and reverse: DISCARD
      return
  else:
    if len(oligo_matches) == 1:
      return restart(s, oligo_matches[0])
    else:
      # Multimatch in forward: DISCARD
      return
  
  



#proc fastx_metadata(argv: var seq[string]): int =
proc fastx_rotate(args: var seq[string]): int {.gcsafe.} =
  let args = docopt("""
  Usage:
    fu-rotate [options] -i POS [<fastq-file>...]
    fu-rotate [options] -m STR [<fastq-file>...]

  Rotate the sequences of one or more sequence files using 
  coordinates or motifs.

  Position based:
    -i, --start-pos POS        Restart from base POS, where 1 is the first base [default: 1]
  
  Motif based:
    -m, --motif STR            Rotate sequences using motif STR as the new start,
                               where STR is a string of bases
    -s, --skip-unmached        If a motif is provided, skip sequences that do not
                               match the motif
    -r, --revcomp              Also scan for reverse complemented motif

  Other options:
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

  #check parameters
  try:
    discard parseInt($args["--start-pos"])
  except Exception as e:
    stderr.writeLine e.msg
    quit(1)
    
  let
    newStart = parseInt($args["--start-pos"]) - 1
    motifsearch = if $args["--motif"] != "nil": true
                  else: false
    motif = $args["--motif"]
    searchRc = if $args["--revcomp"] != "nil": true
               else: false

  var inputFiles = newSeq[string]()
  if len( @( args["<fastq-file>"]))  > 0:
    for f in args["<fastq-file>"]:
      if fileExists(f):
        inputFiles.add(f)
      else:
        if f != "rotate":
          stderr.writeLine("ERROR: Skipping file <", f, ">: not found.")
  else:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[fu-rotate] Waiting for sequences from STDIN (Ctrl-C to quit)...")
      inputFiles.add("-")

  for inputFile in inputFiles:
    if not fileExists(inputFile) and inputFile != "-":
        stderr.writeLine("ERROR: Input file not found: ", inputFile)
        quit(1)
    try:
      for fqRecord in readfq(inputFile):
        if motifsearch:
          let
            restartedRecord = restartMotif(fqRecord, motif, searchRc)
          if len(restartedRecord.sequence) > 0:
            echo restartedRecord
        else:
          echo restart(fqRecord, newStart)
    except Exception as e:
      stderr.writeLine("ERROR: parsing ", inputFile, ": ", e.msg)
      quit(1)
        



#when isMainModule:
#  main_helper(main)
