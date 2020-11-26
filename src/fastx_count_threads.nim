import klib
import re
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils

import threadpool


type
  Stats = ref object
    filename: string
    sample: string
    reads: int
    strand: string

proc newStats(): Stats =
  Stats(filename: "", strand: "", reads: 0)


proc countReads(niceFilename, sample, filename, strand: string): Stats =
   
  # Count sequences file by file
  result = newStats()
  var f = xopen[GzFile](filename)
  defer: f.close()
  var 
    r: FastxRecord
    c = 0
  while f.readFastx(r):
    c+=1
  
  result = Stats(filename: niceFilename, sample: sample, strand: strand, reads: c)
   
  
    
proc fastx_count(argv: var seq[string]): int =
    let args = docopt("""
Usage: count [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -t, --threads INT      Working threads [default: 1]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]

    var 
      files    : seq[string]

    let
      threads  = parseInt($args["--threads"])
      abspath  = args["--abs-path"]
      basename = args["--basename"]
      unpaired = args["--unpair"]
      pattern1 = $args["--for-tag"]
      pattern2 = $args["--rev-tag"]
      
   
 
    
    if args["<inputfile>"].len() == 0:
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)

    # pre scan files
    var 
      fileTable = initTable[string, initTable[string, string]() ]() 
      errors    = 0
      responses = newSeq[FlowVar[Stats]]()
   
    # Scan all filenames
    for filename in sorted(files):
      echoVerbose(filename, verbose)
      var
        printedFilename = filename

      if filename != "-" and not existsFile(filename):
        stderr.writeLine("WARNING: File ", filename, " not found.")
      
      let
        (dir, filenameNoExt, extension) = splitFile(filename)
        (sampleId, direction) = extractTag(filenameNoExt, pattern1, pattern2)
        
   
      if abspath:
        printedFilename = absolutePath(filename)
      elif basename:
        printedFilename = filenameNoExt & extension
 
      #responses.add(spawn countReads(printedFilename, direction)) 


      responses.add(spawn countReads(filename, sampleId, printedFilename, direction)) 


    # Collect results
    for resp in responses: # Iterates through each response
      #Blocks the main thread until the response can be read and then saves the response value in the statistics variable
      let statistic = ^resp
      if not ( statistic.sample in fileTable ):
        fileTable[statistic.sample] = initTable[string, string]()
      fileTable[statistic.sample][statistic.strand] = $statistic.reads
      fileTable[statistic.sample]["filename_" & statistic.strand] = statistic.filename


        # Populate counts table table[SampleID][R1/R2/Se] = counts
        #
        #  fileTable[statistic.filename] = initTable[string, string]()

        #fileTable[statistic.filename][statistic.strand] = statistic.reads
        #
    

    for id, counts in fileTable:

      if "SE" in counts:
        echo counts["filename_SE"], "\t", counts["SE"]
      else:
  
        if counts["R1"] == counts["R2"]:
          echo counts["filename_R1"], "\t", counts["R1"]
          if (unpaired):
            echo counts["filename_R2"], "\t", counts["R2"]
        
        else:
          errors += 1
          stderr.writeLine("ERROR: Different counts in ", counts["filename_R1"], " and ", counts["filename_R2"] )
          stderr.writeLine("# ", counts["filename_R1"], ": ", counts["R1"] )
          stderr.writeLine("# ", counts["filename_R2"], ": ", counts["R2"] )

    if errors > 0:
      stderr.writeLine(errors, " errors found.")
      quit(1)


 
