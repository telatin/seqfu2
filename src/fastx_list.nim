import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import strformat
import stats

type
  Options = tuple
    withComments : bool

proc getListFromFile(filename: string, opts: Options) =
  for line in lines filename:
    # remove first char if it is ">"
    if line[0] == ">":
      line = line[1..]
    
    if opts.withComments:
      line = line.split("#")[0]
    
     

    let args = docopt("""
Usage: list [options] <LIST> <FASTQ>...

Print sequences that are present in a list file.

Other options:
  -v, --verbose          Verbose output
  -O, --offset INT       Quality encoding offset [default: 33]
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 

    let sequenceList = getListFromFile($args[LIST])
    
    if len(  @(args["<FASTQ>"]) ) == 0:
      stderr.writeLine("No files specified. Use '-' to read STDIN, --help for help.")

    for file in @(args["<FASTQ>"]):
      if not fileExists(file) and file != "-":
        stderr.writeLine("ERROR: File not found: ", file)
        continue
         
      for record in readfq(file):
        echo record