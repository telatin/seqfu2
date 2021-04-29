import klib
import tables, strutils
from os import fileExists, lastPathPart
import docopt
import ./seqfu_utils


proc fastx_cat(argv: var seq[string]): int =
    let args = docopt("""
Usage: cat [options] [<inputfile> ...]

Concatenate multiple FASTA or FASTQ files.

Options:
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
      skip   : int
      prefix : string
      files  : seq[string]  
      printBasename: bool 
      separator:  string 
  
    try:
      skip =  parseInt($args["--skip"])
      printBasename = args["--basename"] 
      separator = $args["--sep"]
    except:
      stderr.writeLine("Error: Wrong parameters!")
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    if args["<inputfile>"].len() == 0:
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    var
      totalPrintedSeqs = 0

    for filename in files:
      echoVerbose(filename, verbose)

      if filename != "-" and not fileExists(filename):
        stderr.writeLine("Skipping <", filename, ">: not found")
        continue

      var 
        f = xopen[GzFile](filename)
        y = 0
        r: FastxRecord
        
      defer: f.close()
      var 
        currentSeqCount    = 0
        currentPrintedSeqs = 0
      
      
      while f.readFastx(r):
        currentSeqCount += 1

        if skip > 0:
          y = currentSeqCount mod skip

        if y == 0:
          # Print sequence
          currentPrintedSeqs += 1
          totalPrintedSeqs   += 1
          
          var
            newName = ""

          # Prepend basename if required
          if printBasename:
            newName =  lastPathPart(filename) & separator
          
          # rename with prefix + counter
          if prefix != "":
            newName &= prefix & separator
            if printBasename:
              newName &= $currentPrintedSeqs
            else:
              newName &= $totalPrintedSeqs
          else:
            newName &= r.name
          
          r.name = newName

          if not args["--strip-comments"]:
            newName &= "\t" & r.comment
          
          if len(r.qual) > 0:
            # Record is FASTQ
            if args["--fasta"]:
              # Force FASTA
              r.qual = ""
          else:
            # Record is FASTA
            if args["--fastq"]:
              r.qual = repeat(qualToChar(defaultQual), len(r.seq))

          echo printFastxRecord(r)

      # File parsed
      if verbose:
        stderr.writeLine(currentPrintedSeqs, "/", currentSeqCount, " sequences printed")

      
 