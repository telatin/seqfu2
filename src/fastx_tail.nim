import readfq
import strformat
import tables, strutils
from os import fileExists, getEnv
import docopt
import ./seqfu_utils

proc keepSeq(pool: var seq, sequence: FQRecord, max: int): bool {.discardable.} = 
  if pool.len >= max:
    pool.delete(0)
  pool.add(sequence)
  return true
#[
proc keepSeq_v1(pool: var seq, sequence: FastxRecord, max: int): bool {.discardable.} = 
  if pool.len >= max:
    pool.delete(0)
  pool.add(sequence)
  return true
]#
proc fastx_tail_v2(argv: var seq[string]): int =
    let args = docopt("""
Usage: tail [options] [<inputfile> ...]

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta = args["--fasta"]
    forceFastq = args["--fastq"]
    defaultQual = parseInt($args["--fastq-qual"])
    var
      num, skip : int
      prefix : string
      files : seq[string]  
      printBasename: bool 
      separator:  string 
      #lastSequences: seq[FastxRecord]
      lastSequences = newSeq[FQRecord](0)


    try:
      num =  parseInt($args["--num"])
      skip =  parseInt($args["--skip"])
      printBasename = args["--basename"] 
      separator = $args["--sep"]
    except:
      stderr.writeLine("Error: Wrong parameters!")
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu tail] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    for filename in files:
      echoVerbose(filename, verbose)
      var
        y = 0
 
      var 
        c  = 0
        printed = 0
      
      
      for record in readfq(filename):
        var
          outRecord : FQRecord = record
        c += 1

        if skip > 0:
          y = c mod skip

        if y == 0:
          if len(prefix) > 0:
            outRecord.name = $prefix & separator & $printed
          if printBasename:
            outRecord.name = $getBasename(filename) & separator & record.name
          #printSeq(r, nil)
          lastSequences.keepSeq(outRecord, num)
      
      for tailSeq in lastSequences:
        printSeq(tailSeq, nil)

#[
import klib
proc fastx_tail(argv: var seq[string]): int =
    let args = docopt("""
Usage: tail [options] [<inputfile> ...]

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING       Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta = args["--fasta"]
    forceFastq = args["--fastq"]
    defaultQual = parseInt($args["--fastq-qual"])
    var
      num, skip : int
      prefix : string
      files : seq[string]  
      printBasename: bool 
      separator:  string 
      #lastSequences: seq[FastxRecord]
      lastSequences = newSeq[FastxRecord](0)


    try:
      num =  parseInt($args["--num"])
      skip =  parseInt($args["--skip"])
      printBasename = args["--basename"] 
      separator = $args["--sep"]
    except:
      stderr.writeLine("Error: Wrong parameters!")
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu tail] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    for filename in files:
      echoVerbose(filename, verbose)
      var 
        f = xopen[GzFile](filename)
        y = 0
        r: FastxRecord
        
      defer: f.close()
      var 
        c  = 0
        printed = 0
      
      
      while f.readFastx(r):
        c += 1

        if skip > 0:
          y = c mod skip

        if y == 0:
          if len(prefix) > 0:
            r.name = $prefix & separator & $printed
          if printBasename:
            r.name = $getBasename(filename) & separator & r.name
          #printSeq(r, nil)
          lastSequences.keepSeq(r, num)
      
      for tailSeq in lastSequences:
        printSeq(tailSeq, nil)

]#