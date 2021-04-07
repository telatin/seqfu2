import readfq
import docopt
import os
import posix

import strutils, strformat
import tables, algorithm

signal(SIG_PIPE, SIG_IGN)

const NimblePkgVersion {.strdefine.} = "undef"
const version = if NimblePkgVersion == "undef": "X.9"
                else: NimblePkgVersion

# Handle Ctrl+C interruptions and pipe breaks
type EKeyboardInterrupt = object of CatchableError
proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
setControlCHook(handler)
 

 

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



proc main(): int =
  let args = docopt("""
  Fastx utility

  A program to print the sequence size of each record in a FASTA/FASTQ file

  Usage: 
  fu-index [options] <FASTQ>...

  Options:
  
    -m, --max-reads INT    Evaluate INT number of reads [default: 1000]
    -r, --min-ratio FLOAT  Minimum ratio of matches of the top index [default: 0.85]
    --verbose              Print verbose log
    --help                 Show help
  """, version=version, argv=commandLineParams())

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
  # Handle "Ctrl+C" intterruption
  try:
    let exitStatus = main()
    quit(exitStatus) 
  except EKeyboardInterrupt:
    # Ctrl+C
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(1)
  except IOError:
    # Broken pipe
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(0)
  except Exception:
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(2)   
