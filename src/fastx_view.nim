import klib
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils

proc fastx_view(argv: var seq[string]): int =
  let args = docopt("""
Usage: view [options] [<inputfile> ...]

Options:
  -h, --head INT         Print the first INT sequences
  -t, --tail INT         Print the last INT sequences
  -s, --strip-comments   Do not print sequence comments
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]



 
