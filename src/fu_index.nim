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
  readInfo = tuple
    instrument: string
    run: int
    flowcell: string
    lane: int
    tile: int
    x: int
    y: int
    umi: string
    read: int
    filtered: bool
    control: int
    index: string
  
  illuminaDataset = tuple
    index: string
    tot, match: int
    info: readInfo

  


proc getIndex(s: string): string =
  let split = s.split(':')
  if len(split) > 2:
    return split[^1]

proc getReadInfo(n, c: string): readInfo =
  #n = <instrument>:<run number>:<flowcell ID>:<lane>:<tile>:<x-pos>:<y-pos>:<UMI>
  #c = <read>:<is filtered>:<control number>:<index>
  let
    nameparts = n.split(':')
    commparts = n.split(':')
  
  try:
    if len(nameparts) >= 7:
      result.instrument = nameparts[0]
      result.run = parseInt(nameparts[1])
      result.flowcell = nameparts[2]
      result.lane = parseInt(nameparts[3])
      result.tile = parseInt(nameparts[4])
      result.x = parseInt(nameparts[5])
      result.y = parseInt(nameparts[6])
      if len(nameparts) == 8:
        result.umi = nameparts[7]
  except Exception as e:
    stderr.writeLine("Error parsing read name: ", n, ": ", e.msg)
  
  try:
    if len(commparts) >= 4:
      result.read = parseInt(commparts[1])
      result.filtered = if commparts[2] == "Y": true 
                        else: false
      result.control = parseInt(commparts[3])
      result.index = commparts[4]
  except Exception as e:
    stderr.writeLine("Error parsing comment: ", c, ": ", e.msg)

proc processReadPool(pool: seq[FQRecord]): illuminaDataset =
  # Receive a set of sequences to be processed and returns them as string to be printed
  var
    countTable = initCountTable[string]()
    countInstrument = initCountTable[string]()
    countFlowcell = initCountTable[string]()
    countRun = initCountTable[int]()
    info : readInfo
  for s in pool:
    let
      index = getIndex(s.comment)
      info  = getReadInfo(s.name, s.comment)
    if len(index) > 0:
      countTable.inc(index)
    if len(info.instrument) > 0:
      countInstrument.inc(info.instrument)
    if len(info.flowcell) > 0:
      countFlowcell.inc(info.flowcell)
    if info.run > 0:
      countRun.inc(info.run)
    

  
  countTable.sort()
  countInstrument.sort()
  countFlowcell.sort()
  countRun.sort()

  for index, counts in countTable:
    result.index   = index
    result.match = counts
    result.tot   = len(pool)
    break


  for index, counts in countInstrument:
    if counts >= result.match:
      info.instrument = index
    else:
      info.instrument = "Unknown"
    break

  for index, counts in countFlowcell:
    if counts >= result.match:
      info.flowcell = index
    else:
      info.flowcell = "Unknown"
    break

  for index, counts in countRun:
    if counts >= result.match:
      info.run = index
    else:
      info.run = 0
    break

  result.info = info
    #return result



proc main(argv: var seq[string]): int =
  let args = docopt("""
  Fastx utility

  A program to print the Illumina INDEX of a set of FASTQ files

  Usage: 
  fu-index [options] <FASTQ>...

  Options:
  
    -m, --max-reads INT    Evaluate INT number of reads, 0 for unlimited [default: 8000]
    -r, --min-ratio FLOAT  Minimum ratio of matches of the top index [default: 0.90]
    -h, --header           Add header to output
    --verbose              Print verbose log
    --help                 Show help
  """, version=version, argv=argv)

  verbose = bool(args["--verbose"])
  if verbose:
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

 

  if bool(args["--header"]):
    echo "#Filename\tIndex\tRatio\tPass\tInstrument\tRun\tFlowcell"
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
      
      if verbose:
        stderr.writeLine "Processed ", len(readspool), " reads from ", file
  
      let 
        topIndex = processReadPool(readspool)
        ratio = if topIndex.tot > 0: topIndex.match  / topIndex.tot
                else: 0.0

        status = if ratio > minratio: "PASS"
          else: "--"

      echo file, "\t", topIndex.index, "\t", fmt"{ratio:.2f}", "\t", status, "\t", topIndex.info.instrument, "\t", topIndex.info.run, "\t", topIndex.info.flowcell
  
    except Exception as e:
      stderr.writeLine("ERROR: Unable to parse FASTX file: ", file, "\n", e.msg)
      return 1
    

when isMainModule:
  main_helper(main)