import readfq

import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils




type
  Stats = ref object
    filename: string
    sample: string
    reads: int
    strand: string

type
  seqfuCount = ref object
    key: string
    forward, reverse: Stats

proc newStats(): Stats =
  Stats(filename: "", sample: "", strand: "", reads: 0)

proc `$`(s: Stats): string =
  "Stats: " & s.strand & "\t" & s.filename & "\tsample=" & s.sample & "\t" & $s.reads

proc newSeqfuCount(key = ""): seqfuCount =
  seqfuCount(key: key,  forward: newStats(), reverse: newStats())

proc countReads(niceFilename, sample, filename, strand: string): Stats =
  
  try:
    var c = 0
    for r in readfq(filename):
      c += 1
    result = Stats(filename: niceFilename, sample: sample, strand: strand, reads: c)
  except Exception as e:
    result.filename = "Error " & e.msg
    result.reads = -1
  
   
  
    
proc fastx_count_threads_off(argv: var seq[string]): int =
    let args = docopt("""
Usage: count [options] [<inputfile> ...]

Count sequences in paired-end aware format

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -t, --threads INT      Working threads [default: 4]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]

    var 
      files    : seq[string]

    let
      #threads  = parseInt($args["--threads"])
      abspath  = args["--abs-path"]
      basename = args["--basename"]
      unpaired = args["--unpair"]
      pattern1 = $args["--for-tag"]
      pattern2 = $args["--rev-tag"]
      legacy   = {"for" : "Paired", "rev": "Paired:R2", "unknown": "SE"}.toTable

 
    
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu count] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        if fileExists(file) or file == "-":
          if abspath:
            files.add(absolutePath(file))
          else:
            files.add(file)
        else:
          stderr.writeLine("WARNING: File not found, skipping: ", file)

    var
      responses = newSeq[Stats]()
      list = newSeq[Stats]()
      test = newTable[string, seqfuCount]()

    for file in files:
      let filename = getStrandFromFilename(file, forPattern=pattern1, revPattern=pattern2)
      if verbose:
        stderr.writeLine("Processing: ", file, " as ", filename.strand)
      responses.add(countReads(file, filename.splittedFile, file, filename.strand))
    
    for stats in responses:
      if verbose:
        stderr.writeLine("Got counts for ", stats.filename, ": ", stats.reads)
      if unpaired:
        let key = if abspath: absolutePath(stats.filename)
                  elif basename: extractFilename(stats.filename)
                  else: stats.filename
        echo key, "\t", stats.reads, "\t", legacy[getStrandFromFilename(stats.filename).strand]
      else:
        list.add(stats)

    if not unpaired:
      for i in list:
        let key = if len(i.sample) > 0: i.sample
                  else: i.filename
        if key == "":
          continue
        if key notin test:
          test[key] = newSeqfuCount()
        if i.strand == "rev":
          test[key].reverse = i
        else:
          test[key].forward = i

      var e = 0
      for key, j in test:
        let printFileName = if basename: extractFileName(j.forward.filename)
                            else: j.forward.filename
        if (j.forward).reads == (j.reverse).reads:
          echo printFileName, "\t", (j.forward).reads, "\tPaired"
        elif (j.reverse).reads == 0:
          echo printFileName, "\t", (j.forward).reads, "\tSE"
        else:
          stderr.writeLine("ERROR: Counts in R1 and R2 files do not match for ", printFileName)
          e += 1
          echo printFileName, "\t" , (j.forward).reads, "\t<Error:R1>"
          echo printFileName, "\t" , (j.reverse).reads, "\t<Error:R2>"
      if e > 0:
        quit(1)