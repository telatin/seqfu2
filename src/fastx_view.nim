import klib
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import colorize


proc qualToUnicode(s: string, v: seq[int], color = false): string =
  #  1   2   3   4   5   6   7
  #  Low     Mid     Ok
  for i in s:
    let
      val = charToQual(i)
    if val <= v[0]:
      if color == true:
        result &= "▁".fgDarkGray
      else:
        result &= "▁"
    elif val <= v[1]:
      if color == true:
        result &= "▂".fgDarkGray
      else:
        result &= "▂"
    elif val <= v[2]:
      if color == true:
        result &= "▃".fgRed
      else:
        result &= "▃"
    elif val <= v[3]:
      if color == true:
        result &= "▄".fgRed
      else:
        result &= "▄"
    elif val <= v[4]:
      if color == true:
        result &= "▅".fgYellow
      else:
        result &= "▅"
    elif val <= v[5]:
      if color == true:
        result &= "▆".fgYellow
      else:
        result &= "▆"
    elif val <= v[6]:
      if color == true:
        result &= "▇".fgGreen
      else:
        result &= "▇"
    else:
      if color == true:
        result &= "█".fgGreen
      else:
        result &= "█"


proc highlight(r: string, matches: seq[seq[int]], l:int) =
  if len(matches[0]) > 0:
    for m in matches[0]:
      let 
        stop = if m >= 0: l
               else: l + m
        start = if m >= 0: m
              else: 0
      echo ' '.repeat(start) & "ᐅ".bgRed.fgWhite.repeat(stop)

  echo r

  if len(matches[1]) > 0:
    for m in matches[1]:
      let 
        stop = if m >= 0: l
               else: l + m
        start = if m >= 0: m
              else: 0
      echo ' '.repeat(start) & "ᐊ".bgBlue.fgWhite.repeat(stop)
    
proc fastx_view(argv: var seq[string]): int =
  let args = docopt("""
Usage: view [options] <inputfile>

View a FASTA/FASTQ file for manual inspection, allowing to search for
an oligonucleotide

Options:
  -o, --oligo OLIGO      Match oligo, with ambiguous IUPAC chars allowed
                         (reverse complementary search is performed)
  -q, --qual-scale STR   Quality thresholds, seven values
                         separated by columns [default: 3:15:25:28:30:35:40]

  --match-ths FLOAT      Oligo matching threshold [default: 0.75]
  --min-matches INT      Oligo minimum matches [default: 5]
  --max-mismatches INT   Oligo maxmimum mismataches [default: 2]

  -n, --nocolor          Disable colored output
  --verbose              Show extra information
  -h, --help             Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]
  let
    colorOutput = not args["--nocolor"]
    matchThs = parseFloat($args["--match-ths"])
    minMatches = parseInt($args["--min-matches"])
    maxMismatches = parseInt($args["--max-mismatches"])
  var
    thresholdValues = @[1, 10, 20, 25, 30, 35, 40]
    qualArray: seq[string]

  try:
    qualArray = split($args["--qual-scale"], ':')
  except Exception as e:
    stderr.writeLine("Error: --qual-scale is invalid. ", e.msg)
    quit(1)

  if len(qualArray) != 7:
    stderr.writeLine("Error: --qual-scale requires seven values, got ", len(qualArray), ": ", $args["--qual-scale"])
    quit(1)
  else:
    for index in 0 ..< len(qualArray):
      try:
        thresholdValues[index] = parseInt(qualArray[index])
      except Exception as e:
        stderr.writeLine("Error parsing quality value: <", qualArray[index], ">: ", e.msg)
        quit(1)

  if not fileExists($args["<inputfile>"]):
    stderr.writeLine("Error: input file not found: ", $args["<inputfile>"])
    quit(1)

  var 
    f = xopen[GzFile]($args["<inputfile>"])
    read: FastxRecord
  
  defer: f.close()
  while f.readFastx(read):
    echo "@", read.name, "\t", read.comment
    if $args["--oligo"] != "nil":
      let matches = findPrimerMatches(read.seq, $args["--oligo"], matchThs, maxMismatches, minMatches)
      highlight(read.seq, matches, len($args["--oligo"]))
    else:
      echo read.seq
    echo qualToUnicode(read.qual, thresholdValues, colorOutput)

     
  return 0



 
