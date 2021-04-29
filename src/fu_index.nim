import readfq
import docopt
import os
 

import strutils, strformat
import tables, algorithm
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const version = if NimblePkgVersion == "undef": "X.9"
                else: NimblePkgVersion


 

type
  topHit = tuple
    hit: string
    tot, match: int

proc getIndex(s: string): string =
  let split = s.split(':')
  if len(split) > 2:
    return split[^1]

proc processReadPool(pool: seq[FQRecord]): topHit =
  # Receive a set of sequences to be processed and returns them as string to be printed
  var
    countTable = initCountTable[string]()
  
  for s in pool:
    let index = getIndex(s.comment)
    if len(index) > 0:
      countTable.inc(index)
  countTable.sort()

  for index, counts in countTable:
    result.hit   = index
    result.match = counts
    result.tot   = len(pool)
    return result



proc main(argv: var seq[string]): int =
  let args = docopt("""
  Fastx utility

  A program to print the Illumina INDEX of a set of FASTQ files

  Usage: 
  fu-index [options] <FASTQ>...

  Options:
  
    -m, --max-reads INT    Evaluate INT number of reads [default: 1000]
    -r, --min-ratio FLOAT  Minimum ratio of matches of the top index [default: 0.85]
    --verbose              Print verbose log
    --help                 Show help
  """, version=version, argv=argv)

  if args["--verbose"]:
    echo $args
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  
  var
    maxreads: int
    minratio: float

  try:
    maxreads = parseInt($args["--max-reads"])
    minratio = parseFloat($args["--min-ratio"])
 
  except Exception:
    stderr.writeLine("Error parsing options. See --help for manual.")
    quit(1)

 


  # Prepare the 
  # Process file read by read
  for file in @(args["<FASTQ>"]):

    var readspool : seq[FQRecord]
    var seqCounter = 0
    if not fileExists(file):
      stderr.writeLine("ERROR: File <", file, "> not found. Skipping.")
      continue

    try:
      for seqObject in readfq(file):
        seqCounter += 1
        readspool.add(seqObject)

        if seqCounter == maxreads:
          break
  
      let 
        topIndex = processReadPool(readspool)
        ratio = if topIndex.tot > 0: topIndex.match  / topIndex.tot
                else: 0.0

        status = if ratio > minratio: "PASS"
          else: "--"

      echo file, "\t", topIndex.hit, "\t", fmt"{ratio:.2f}", "\t", status
  
    except Exception as e:
      stderr.writeLine("ERROR: Unable to parse FASTX file: ", file, "\n", e.msg)
      return 1
    

when isMainModule:
  main_helper(main)