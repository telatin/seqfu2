import readfx
import docopt
import os
import strutils, strformat
import tables, algorithm
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const version = if NimblePkgVersion == "undef": "X.9"
                else: NimblePkgVersion


 

type
  ReadInfo* = object
    instrument*: string
    run*: int
    flowcell*: string
    lane*: int
    tile*: int
    x*: int
    y*: int
    umi*: string
    read*: int
    filtered*: bool
    control*: int
    index*: string
  
  IlluminaDataset = tuple
    index: string
    tot, match: int
    info: ReadInfo

  IndexCounters = object
    indexCounts: CountTable[string]
    instrumentCounts: CountTable[string]
    flowcellCounts: CountTable[string]
    runCounts: CountTable[int]
    total: int

  


proc getCommentIndex(s: string): string =
  let split = s.split(':')
  if len(split) > 2:
    return split[^1]

proc getReadInfo*(n, c: string): ReadInfo =
  #n = <instrument>:<run number>:<flowcell ID>:<lane>:<tile>:<x-pos>:<y-pos>:<UMI>
  #c = <read>:<is filtered>:<control number>:<index>
  let
    nameparts = n.split(':')
    commparts = c.split(':')
  
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
      result.read = parseInt(commparts[0])
      result.filtered = commparts[1] == "Y"
      result.control = parseInt(commparts[2])
      result.index = commparts[3]
  except Exception as e:
    stderr.writeLine("Error parsing comment: ", c, ": ", e.msg)

proc initIndexCounters(): IndexCounters =
  result.indexCounts = initCountTable[string]()
  result.instrumentCounts = initCountTable[string]()
  result.flowcellCounts = initCountTable[string]()
  result.runCounts = initCountTable[int]()

proc addRead(counters: var IndexCounters, record: FQRecord) =
  let
    index = getCommentIndex(record.comment)
    info = getReadInfo(record.name, record.comment)

  counters.total += 1
  if len(index) > 0:
    counters.indexCounts.inc(index)
  if len(info.instrument) > 0:
    counters.instrumentCounts.inc(info.instrument)
  if len(info.flowcell) > 0:
    counters.flowcellCounts.inc(info.flowcell)
  if info.run > 0:
    counters.runCounts.inc(info.run)

proc summarize(counters: var IndexCounters): IlluminaDataset =
  # Select the most common index and matching run metadata from streaming counts.
  var
    info: ReadInfo
  result.tot = counters.total

  counters.indexCounts.sort()
  counters.instrumentCounts.sort()
  counters.flowcellCounts.sort()
  counters.runCounts.sort()

  for index, counts in counters.indexCounts:
    result.index = index
    result.match = counts
    break


  for index, counts in counters.instrumentCounts:
    if counts >= result.match:
      info.instrument = index
    else:
      info.instrument = "Unknown"
    break

  for index, counts in counters.flowcellCounts:
    if counts >= result.match:
      info.flowcell = index
    else:
      info.flowcell = "Unknown"
    break

  for index, counts in counters.runCounts:
    if counts >= result.match:
      info.run = index
    else:
      info.run = 0
    break

  result.info = info



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
    return 1

  if maxreads < 0:
    stderr.writeLine("ERROR: --max-reads must be >= 0.")
    return 1

  if minratio < 0.0 or minratio > 1.0:
    stderr.writeLine("ERROR: --min-ratio must be between 0 and 1.")
    return 1
 

  if bool(args["--header"]):
    echo "#Filename\tIndex\tRatio\tPass\tInstrument\tRun\tFlowcell"
  # Prepare the 
  # Process file read by read
  for file in @(args["<FASTQ>"]):

    var counters = initIndexCounters()
    var seqCounter = 0
    if not fileExists(file):
      stderr.writeLine("ERROR: File <", file, "> not found.")
      return 1

    try:
      for seqObject in readFQ(file):
        seqCounter += 1
        counters.addRead(seqObject)

        if maxreads > 0 and seqCounter == maxreads:
          break
      
      if verbose:
        stderr.writeLine "Processed ", seqCounter, " reads from ", file
  
      let 
        topIndex = summarize(counters)
        ratio = if topIndex.tot > 0: topIndex.match  / topIndex.tot
                else: 0.0

        status = if ratio >= minratio: "PASS"
          else: "--"

      echo file, "\t", topIndex.index, "\t", fmt"{ratio:.2f}", "\t", status, "\t", topIndex.info.instrument, "\t", topIndex.info.run, "\t", topIndex.info.flowcell
  
    except Exception as e:
      stderr.writeLine("ERROR: Unable to parse FASTX file: ", file, "\n", e.msg)
      return 1
    

when isMainModule:
  main_helper(main)
