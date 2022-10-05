import readfq
import strformat
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils



proc fastx_head_v2(argv: var seq[string]): int =
    let args = docopt("""
Usage: head [options] [<inputfile> ...]

Select a number of sequences from the beginning of a file, allowing
to select a fraction of the reads (for example to print 100 reads,
selecting one every 10).

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  -v, --verbose          Verbose output
  --print-last           Print the name of the last sequence to STDERR (Last:NAME)
  --fatal                Exit with error if less than NUM sequences are found
  --quiet                Don't print warnings
  --help                 Show this help

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  
  """, version=version(), argv=argv)

    verbose       = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta    = bool(args["--fasta"])
    forceFastq    = bool(args["--fastq"])
    defaultQual   = parseInt($args["--fastq-qual"])
    var
      num, skip    : int
      prefix       : string
      files        : seq[string]  
      printBasename: bool 
      separator    :  string 

    let 
      printLast     = bool(args["--print-last"])
      fatalWarning  = bool(args["--fatal"])

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
        stderr.writeLine("[seqfu head] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    for filename in files:
      if not fileExists(filename) and filename != "-":
        stderr.writeLine("Skipping ", filename, ": not found")
        continue
      else:
        echoVerbose(filename, verbose)

      var 
        y = 0
        outRecord: FQRecord
        
 
      var 
        c  = 0
        printed = 0
      
      
      for record in readfq(filename):
        outRecord = record
        c += 1

        if skip > 0:
          y = c mod skip

        if printed == num:
          if verbose:
            stderr.writeLine("Stopping after ", printed, " sequences.")
          break

        if y == 0:
          printed += 1
          # Print sequence
          if len(prefix) > 0:
            outRecord.name = $prefix & separator & $printed
          if printBasename:
            outRecord.name = $getBasename(filename) & separator & outRecord.name
          printSeq(outRecord, nil)
      
        if printed == num and printLast:
          stderr.writeLine("Last:", outRecord.name)
      if (not args["--quiet"]) and printed < num:
        stderr.writeLine("WARNING\nPrinted less sequences (", printed, "/", num, ") than requested for ", filename, ". Try reducing --skip.")
        if fatalWarning:
          stderr.writeLine("Exiting with error.")
          quit(1)
   #[      
proc fastx_head_v1(argv: var seq[string]): int =
    let args = docopt("""
Usage: head [options] [<inputfile> ...]

Select a number of sequences from the beginning of a file, allowing
to select a fraction of the reads (for example to print 100 reads,
selecting one every 10).

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  -v, --verbose          Verbose output
  --print-last           Print the name of the last sequence to STDERR (Last:NAME)
  --fatal                Exit with error if less than NUM sequences are found
  --quiet                Don't print warnings
  --help                 Show this help

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  
  """, version=version(), argv=argv)

    verbose       = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta    = bool(args["--fasta"])
    forceFastq    = bool(args["--fastq"])
    defaultQual   = parseInt($args["--fastq-qual"])
    var
      num, skip    : int
      prefix       : string
      files        : seq[string]  
      printBasename: bool 
      separator    :  string 

    let 
      printLast     = bool(args["--print-last"])
      fatalWarning  = bool(args["--fatal"])

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
        stderr.writeLine("[seqfu head] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    for filename in files:
      if not fileExists(filename) and filename != "-":
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
          if verbose:
            stderr.writeLine("Stopping after ", printed, " sequences.")
          break

        if y == 0:
          printed += 1
          # Print sequence
          if len(prefix) > 0:
            r.name = $prefix & separator & $printed
          if printBasename:
            r.name = $getBasename(filename) & separator & r.name
          printSeq(r, nil)
      
        if printed == num and printLast:
          stderr.writeLine("Last:", r.name)
      if (not args["--quiet"]) and printed < num:
        stderr.writeLine("WARNING\nPrinted less sequences (", printed, "/", num, ") than requested for ", filename, ". Try reducing --skip.")
        if fatalWarning:
          stderr.writeLine("Exiting with error.")
          quit(1)
         ]#