import klib
import re
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils





proc fastx_count(argv: var seq[string]): int =
    let args = docopt("""
Usage: count [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]

    var 
      files    : seq[string]
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

    # Scan all filenames
    for filename in sorted(files):
      var
        printedFilename = filename

      if filename != "-" and not fileExists(filename):
        if dirExists(filename):
          stderr.writeLine("WARNING: Directories as not supported. Skipping ", filename)
        else:
          stderr.writeLine("WARNING: File ", filename, " not found.")
        continue
      
      let
        (dir, filenameNoExt, extension) = splitFile(filename)
        (sampleId, direction) = extractTag(filenameNoExt, pattern1, pattern2)
        
   
      if abspath:
        printedFilename = absolutePath(filename)
      elif basename:
        printedFilename = filenameNoExt & extension

      # Count sequences file by file
      var f = xopen[GzFile](filename)
      defer: f.close()
      var 
        r: FastxRecord
        c = 0
      while f.readFastx(r):
        c+=1
      echoVerbose(filename & " (" & direction & "): " & $c, verbose)
      
      # Populate counts table table[SampleID][R1/R2/Se] = counts
      if not ( sampleId in fileTable ):
        fileTable[sampleId] = initTable[string, string]()

      fileTable[sampleId][direction] = $c
      fileTable[sampleId]["filename_" & direction] = printedFilename
    
    
    for id, counts in fileTable:
      if "SE" in counts:
        echo counts["filename_SE"], "\t", counts["SE"], "\tSE"
      else:
        if "R2" in counts:
          if counts["R1"] == counts["R2"]:
            echo counts["filename_R1"], "\t", counts["R1"], "\tPaired"
            if (unpaired):
              echo counts["filename_R2"], "\t", counts["R2"], "\tPaired:R2"
          else:
            errors += 1
            stderr.writeLine("ERROR: Different counts in ", counts["filename_R1"], " and ", counts["filename_R2"] )
            stderr.writeLine("# ", counts["filename_R1"], ": ", counts["R1"] )
            stderr.writeLine("# ", counts["filename_R2"], ": ", counts["R2"] )
        else:
          echo counts["filename_R1"], "\t", counts["R1"], "\tSE"
        
    
    if errors > 0:
      stderr.writeLine(errors, " errors found.")
      quit(1)


 
