import klib
import strformat
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils


proc fastx_head(argv: var seq[string]): int =
    let args = docopt("""
Usage: head [options] [<inputfile> ...]

Select a number of sequences from the beginning of a file, allowing
to select

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
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta    = args["--fasta"]
    forceFastq    = args["--fastq"]
    defaultQual   = parseInt($args["--fastq-qual"])
    var
      num, skip    : int
      prefix       : string
      files        : seq[string]  
      printBasename: bool 
      separator    :  string 


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
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    for filename in files:
      if not fileExists(filename):
        stderr.writeLine("Skipping ", filename, ": not found")
        continue
      else:
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

        if printed == num:
          break

        if y == 0:
          printed += 1
          # Print sequence
          if len(prefix) > 0:
            r.name = $prefix & separator & $printed
          if printBasename:
            r.name = $getBasename(filename) & separator & r.name
          printSeq(r, nil)
      
      if printed < num:
        stderr.writeLine("WARNING\nPrinted less sequences (", printed, "/", num, ") than requested for ", filename, ". Try reducing --skip.")
        