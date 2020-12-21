import os
import re
import docopt
import klib
import ./seqfu_utils


proc fastq_deinterleave(argv: var seq[string]): int =
  let args = docopt("""
ilv: interleave FASTQ files

  Usage: dei [options] -o basename <interleaved-fastq>

  -o --output-basename "str"     save output to output_R1.fq and output_R2.fq
  -f --for-ext "R1"              extension for R1 file [default: _R1.fq]
  -r --rev-ext "R2"              extension for R2 file [default: _R2.fq]
  -c --check                     enable careful mode (check sequence names and numbers)
  -v --verbose                   print verbose output

  -s --strip-comments            skip comments
  -p --prefix "string"           rename sequences (append a progressive number)

notes:
    use "-" as input filename to read from STDIN

example:

    dei -o newfile file.fq

  """, version=version(), argv=argv)


  var
    input_file = $args["<interleaved-fastq>"]
    output_base = $args["--output-basename"]
    tag_R1   = $args["--for-ext"]
    tag_R2   = $args["--rev-ext"]
    prefix   = $args["--prefix"]
    output_1 = output_base & tag_R1
    output_2 = output_base & tag_R2

  check = args["--check"]
  stripComments = args["--strip-comments"]
  verbose = args["--verbose"]


  var
    outStream1 = open(output_1, fmWrite)
    outStream2 = open(output_2, fmWrite)

  if verbose:
    stderr.writeLine("- file:\t", input_file)
    stderr.writeLine("- output1:\t", output_1)
    stderr.writeLine("- output2:\t", output_2)
    stderr.writeLine("- stripcomm:\t", stripComments)


  if not existsFile(input_file):
    stderr.writeLine("FATAL ERROR: File ", input_file, " not found.")
    quit(1)

  # Open FASTQ files
  var fq = xopen[GzFile](input_file)
  defer: fq.close()

  var record2: FastxRecord

  var c = 0


  while fq.readFastx(record2):
    var
      record1 = record2
    fq.readFastx(record2)

    if prefix != "nil":
        record1.name = prefix & $c
        record2.name = prefix & $c
    c += 1
    print_seq(record1, outStream1)
    print_seq(record2, outStream2)






  return 0
