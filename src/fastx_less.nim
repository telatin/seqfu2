import readfq
import strformat
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils



proc fastx_head_v2(argv: var seq[string]): int =
    let args = docopt("""
Usage: less [options] <file_1> [<file_2>]

View a single FASTQ file or paired-end FASTQ dataset.

Options:
  -i, --interleaved      Input is interleaved paired-end FASTQ
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


  
  """, version=version(), argv=argv)
 
    var
      num, skip    : int
      prefix       : string
      files        : seq[string]  
      printBasename: bool 
      separator    :  string 

    let 
      printLast     = bool(args["--print-last"])
      fatalWarning  = bool(args["--fatal"])


    if args["<file_1>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu head] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    
