import os
import re

#[
import sequtils
import strutils
import tables
import algorithm
]#
import docopt
import klib
import ./seqfu_utils
 
 

proc fastq_interleave(argv: var seq[string]): int =
  let args = docopt("""
ilv: interleave FASTQ files

  Usage: ilv [options] -1 <forward-pair> [-2 <reverse-pair>]

  -f --for-tag <tag-1>       string identifying forward files [default: auto]
  -r --rev-tag <tag-2>       string identifying reverse files [default: auto]
  -o --output <outputfile>   save file to <out-file> instead of STDOUT
  -c --check                 enable careful mode (check sequence names and numbers)
  -v --verbose               print verbose output

  -s --strip-comments        skip comments
  -p --prefix "string"       rename sequences (append a progressive number)

guessing second file:
  by default <forward-pair> is scanned for _R1. and substitute with _R2.
  if this fails, the patterns _1. and _2. are tested.

example:

    ilv -1 file_R1.fq > interleaved.fq
  
  """, version=version(), argv=argv)
  

  var
    file_R1 = $args["<forward-pair>"]
    file_R2: string
    pattern_R1  = $args["--for-tag"]
    pattern_R2  = $args["--rev-tag"]
    output_file = $args["--output"]
    prefix      = $args["--prefix"]

  # Common settings
  check = args["--check"]
  stripComments = args["--strip-comments"]
  verbose = args["--verbose"]
    
  if args["<reverse-pair>"]:
    file_R2 = $args["<reverse-pair>"]

  if file_R2 == "":
    # autodetecting R2 file

    if pattern_R1 == "auto" and pattern_R2 == "auto":
        # automatic guess
        if match(file_R1, re".+_R1\..+"):           
            file_R2 = file_R1.replace(re"_R1\.", "_R2.")
        elif match(file_R1, re".+_1\..+"):            
            file_R2 = file_R1.replace(re"_1\.", "_2.")
        else:
            echo "Unable to detect --for-tag (_R1. or _1.) in <", file_R1, ">"
            quit(1)
    else:
        # user defined patterns
        if match(file_R1, re(".+" & pattern_R1 & ".+") ):
            file_R2 = file_R1.replace(re(pattern_R1), pattern_R2)
        else:
            echo "Unable to find pattern <", pattern_R1, "> in file <", file_R1, ">"
            quit(1)


  var outFile: File
  if output_file != "nil":
      outFile = open(output_file, fmWrite)
      
  if verbose:
    stderr.writeLine("- file1:\t", file_R1)
    stderr.writeLine("- file2:\t", file_R2)
    stderr.writeLine("- patterns:\t", pattern_R1,';',pattern_R2)
    if output_file != "nil":
        stderr.writeLine("- output:\t", output_file)


  if file_R1 == file_R2:
    echo "FATAL ERROR: First file and second file are equal."
    quit(1)

  if not fileExists(file_R1):
    echo "FATAL ERROR: First pair (", file_R1 , ") not found."
    quit(1)

  if not fileExists(file_R2):
    echo "FATAL ERROR: First pair (", file_R2 , ") not found."
    quit(1)

  # Open FASTQ files
  var fq1 = xopen[GzFile](file_R1)
  defer: fq1.close()
  var fq2 = xopen[GzFile](file_R2)
  defer: fq2.close()

  var R1: FastxRecord
  var R2: FastxRecord
  var c = 0

  while fq1.readFastx(R1):
    c += 1
    if not fq2.readFastx(R2):
      stderr.writeLine("File R2 ended prematurely after ", c, " sequences.")
      if check:
        quit(1)
      else: 
        quit(0)

    if check and R1.name != R2.name:
        echo "Sequence error [seq ", c, "], name mismatch"
        echo R1.name, " != ", R2.name
        quit(3)

    if prefix != "nil":
        R1.name = prefix & $c
        R2.name = prefix & $c
    print_seq(R1, outFile)
    print_seq(R2, outFile)


  if fq2.readFastx(R2):
    stderr.writeLine("File R1 ended prematurely after ", c, " sequences.")
    if check:
      quit(1)
    else: 
      quit(0)

  if verbose:
    echo "printed ", c, " sequences from ", file_R1, " and ", file_R2

  if output_file != "nil":
    outFile.close()
  return 0
