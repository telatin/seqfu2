import readfq
import docopt
import os
import kmer
import parseutils
import threadpool
import strutils, strformat
import tables, algorithm
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const version = if NimblePkgVersion == "undef": "1.0"
                else: NimblePkgVersion


type 
  kmerDb = object
    kmers: seq[uint64]
    size: int
    dict: Table[uint64, string]

type
  makeDbOptions = object
    outfile: string
    kmerSize: int
    windowSize: int
    subsample : float
    keepMulti : int
    keepSingle : bool
    verbose: bool

type
  scanOptions = object
    kmerSize: int
    windowSize: int
    verbose: bool
    stepSize: int
    minCount: int
    poolSize: int

proc makeDb(inputfile: string, options: makeDbOptions): int =
  let
    MultiQuery = 4
    MaxQuery   = 10
  var
    kTable = initTable[uint64, seq[string] ]()
  for read in  readfq(inputfile):
    let sequence = compressHomopolymers(read.sequence)
    #for i in 0 ..< (len(sequence) - options.kmerSize):
    for kmer in sequence.slide(options.kmerSize):
      
  
      if kmer[0] notin kTable:
        kTable[kmer[0]] = @[read.name]
      else:
        if  read.name notin kTable[kmer[0]]:
          kTable[kmer[0]].add(read.name)
  
  let
    total = len(kTable)
    modulo = int(100.0 / options.subsample)
  
  var
    c = 0
  for k, query in kTable.pairs():
    var kmer = newString(options.kmerSize)
    c = c + 1
    let keep = if len(query) > options.keepMulti: true
               elif len(query) == 1 and options.keepSingle: true
               else: false

    if keep or c mod modulo == 0:      
      decode(k, kmer)
      echo k, "\t", kmer, "\t", len(query), "\t", if len(query) > MaxQuery: query[0] & "..." & query[^1]
                     else: query.join(";")

  return 0



proc oldloadKmerList(filename: string, kmerSize: int): seq[string] =
  for line in lines filename:
    if len(line) != kmerSize:
      stderr.writeLine("Malformed line [exp ", kmerSize, "-mer, found ", len(line), "-mer]: \n", line)
      quit(1)
    result.add(line)

proc loadKmerList(filename: string, kmerSize: int): kmerDb =
  var s = newSeq[uint64]()
  for line in lines filename:
    # split on tab @[umer, kmer, counts, query
    let record = line.split("\t")
    if len(record) != 4:
      stderr.writeLine("Malformed line: 4 fields expected, found ", len(record), ": \n", line)
      quit(1)
    if result.size == 0:
      result.size = len(record[1])
    else:
      if result.size != len(record[1]):
        stderr.writeLine("Malformed line: ", result.size, "-mer expected, found ", len(record[1]), ": \n", line)
        quit(1)
    
    var umer : uint64 
    umer = record[0].parseUInt()
    result.kmers.add(umer)
  


proc scanRead(read: FQRecord, db: kmerDb, options: scanOptions): bool =
  let sequence = compressHomopolymers(read.sequence)
  for j in countup(0, len(sequence) - options.windowSize, options.stepSize):
          var hits = 0
          let window = sequence[j ..< j + options.windowSize]
          for kmer in window.slide(options.kmerSize):
             
            if (db.kmers).contains(kmer[0]):
              hits += 1
          if hits >= options.minCount:
            return true
  return false

proc processReadPool(pool: seq[FQRecord], db: kmerDb, o: scanOptions): seq[FQRecord] =
  # Receive a set of sequences to be processed and returns them as string to be printed
  for read in pool:
     if scanRead(read, db, o):
       result.add(read)

proc main(argv: var seq[string]): int =
  let args = docopt("""
  Compressed-mers

  A program to select long reads based on a compressed-mers dictionary

  Usage: 
  cmers scan [options] <DB> <FASTQ>...
  cmers make [options] <DB> 

  Make db options:
    -k, --kmer-size INT    K-mer size [default: 15]
    -o, --output-file STR  Output file [default: stdout]
    --subsample FLOAT  Keep only FLOAT% kmers [default: 100.0]
    --keep-multi INT       Keep kmers with multiple more than INT hits (when subsampling) [default: 0]
    --keep-single          Keep all kmers with single hit (when subsampling)

  Scanning options:
    -w, --window-size INT  Window size [default: 1500]
    -s, --step INT         Step size [default: 350]
    --min-len INT          Discard reads shorter than INT [default: 500]
    --min-hits INT         Minimum number of hits per windows [default: 50]
  
  Multithreading options:
    --pool-size INT        Number of sequences per thread pool [default: 1000]
    --max-threads INT      Maximum number of threads [default: 64]
    
    --verbose              Print verbose log
    --help                 Show help
  """, version=version, argv=argv)
 


    
  if args["make"]:
    let makeOpts = makeDbOptions(
      outfile    : $args["--output-file"],
      kmerSize   : parseInt($args["--kmer-size"]),
      windowSize : parseInt($args["--window-size"]),
      subsample  : parseFloat($args["--subsample"]),
      keepMulti  : parseInt($args["--keep-multi"]),
      keepSingle : args["--keep-single"],
      verbose    : args["--verbose"]
    )
 
    quit(makeDb($args["<DB>"], makeOpts))

  # Scan
  setMaxPoolSize(parseInt($args["--max-threads"]) )
    
  # Prepare options
  let opts = scanOptions(
    kmerSize: parseInt($(args["--kmer-size"])),
    windowSize: parseInt($(args["--window-size"])),
    verbose: args["--verbose"],
    stepSize: parseInt($(args["--step"])),
    minCount: parseInt($(args["--min-hits"])),
    poolSize: parseInt($(args["--pool-size"])),
  )

  let minReadLen = parseInt($(args["--min-len"]))

  # Prepare the database
  let db = loadKmerList($args["<DB>"], parseInt($(args["--kmer-size"])) )
  if opts.verbose:
    stderr.writeLine "Loaded ", len(db.kmers), " ", db.size, "-mers"

  # Process file read by read
  for file in @(args["<FASTQ>"]):
    var outputSeqs = newSeq[FlowVar[seq[FQRecord]]]()
    var readspool : seq[FQRecord]
    var seqCounter = 0

    if not fileExists(file):
      stderr.writeLine("ERROR: File <", file, "> not found. Skipping.")
      continue

    try:
      # Process input file
      for seqObject in readfq(file):

        if len(seqObject.sequence) < minReadLen:
          continue

        seqCounter += 1
        readspool.add(seqObject)
 
        if len(readspool) >= opts.poolSize:
          outputSeqs.add(spawn processReadPool(readspool, db, opts))
          readspool.setLen(0)
    

      

    except Exception as e:
      stderr.writeLine("ERROR: Unable to parse FASTX file: ", file, "\n", e.msg)
      return 1
    
    # Last reads
    if len(readspool) > 0:
      outputSeqs.add(spawn processReadPool(readspool, db, opts))

    # Collect results
    var
      poolId = 0 
      printedSeqs = 0

    for resp in outputSeqs:
      let
        filteredReads = ^resp
        totFiltCurrentPool = len(filteredReads)

      printedSeqs += totFiltCurrentPool
      poolId += 1
      if opts.verbose and totFiltCurrentPool > 0:
        stderr.writeLine poolId, ": printing ", totFiltCurrentPool, " sequences."
      for read in filteredReads:
        echo read

    if opts.verbose:
      stderr.writeLine "Total printed sequences: ", printedSeqs
  

when isMainModule:
  main_helper(main)