import docopt
import readfq
import os, strutils
 
import threadpool
import tables
 
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "alpha"

const programVersion = NimblePkgVersion 
let
  programName = "fu-homocomp"
   
 
type
  homocompOptions = tuple
    forcefasta: bool

 
 
proc version(): string =
  return programName  & " " & programVersion
 
proc processReadPool(readspool: seq[FQRecord]): seq[FQRecord] =
  for record in readspool:
    let compressed = compressHomopolymers(record)
    result.add(compressed)

proc main(args: var seq[string]): int =
  let args = docopt("""
  Usage: fu-homocompress [options] [<fastq-file>...]
 
  Remove all the homopolymers from the input sequences.

  Options:
    --pool-size INT            Number of sequences to process per thread [default: 50]
    --max-threads INT          Maxiumum number of threads to use [default: 24]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

  var
    inputFiles = newSeq[string]()

  let 
    poolSize = parseInt($args["--pool-size"])
    maxThreads = parseInt($args["--max-threads"])
  
  # Set max threads
  if maxThreads > 0:
    setMaxPoolSize(maxThreads)
    
  # STDIN
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
 

  
 
  var
    seqCounter = 0
    readspool : seq[FQRecord]
    outputSeqs = newSeq[FlowVar[seq[FQRecord]]]()
 

  for inputFile in inputFiles:
    if args["--verbose"]:
      stderr.writeLine("Reading file: ", inputFile)

    for fqRecord in readfq(inputFile):
      seqCounter += 1
      readspool.add(fqRecord)
 
      if len(readspool) >= poolSize:
        outputSeqs.add(spawn processReadPool(readspool))
        readspool.setLen(0)
  
  # Finished parsing inputs

  # Last reads
  if len(readspool) > 0:
    outputSeqs.add(spawn processReadPool(readspool))

  for resp in outputSeqs:
      let
        filteredReads = ^resp
      for read in filteredReads:
        echo read


when isMainModule:
  main_helper(main)
