import klib
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import colorize
import encodings


proc qualToAscii*(s: string, v: seq[int], color = false): string =
  #  1   2   3   4   5   6   7
  #  Low     Mid     Ok
  for i in s:
    let
      val = charToQual(i)
    if val <= v[0]:
      if color == true:
        result &= "x".fgDarkGray
      else:
        result &= "x"
    elif val <= v[1]:
      if color == true:
        result &= "_".fgDarkGray
      else:
        result &= "_"
    elif val <= v[2]:
      if color == true:
        result &= "_".fgRed
      else:
        result &= "_"
    elif val <= v[3]:
      if color == true:
        result &= "o".fgRed
      else:
        result &= "o"
    elif val <= v[4]:
      if color == true:
        result &= "o".fgYellow
      else:
        result &= "o"
    elif val <= v[5]:
      if color == true:
        result &= "i".fgYellow
      else:
        result &= "i"
    elif val <= v[6]:
      if color == true:
        result &= "i".fgGreen
      else:
        result &= "i"
    else:
      if color == true:
        result &= "I".fgGreen
      else:
        result &= "I"


proc qualToUnicode*(s: string, v: seq[int], color = false): string =
  #  1   2   3   4   5   6   7
  #  Low     Mid     Ok
  for i in s:
    let
      val = charToQual(i)
    if val <= v[0]:
      if color == true:
        result &= "_".fgDarkGray
      else:
        result &= "_"
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

proc qualToColor(s: string, v: seq[int], color = false): string =
  #  1   2   3   4   5   6   7
  #  Low     Mid     Ok
  for i in s:
    let
      val = charToQual(i)
    if val <= v[0]:
      if color == true:
        result &= fgDarkGray($i)
      else:
        result &= i
    elif val <= v[1]:
      if color == true:
        result &= fgDarkGray($i)
      else:
        result &= i
    elif val <= v[2]:
      if color == true:
        result &= fgRed($i)
      else:
        result &= i
    elif val <= v[3]:
      if color == true:
        result &= fgRed($i)
      else:
        result &= i
    elif val <= v[4]:
      if color == true:
        result &= fgYellow($i)
      else:
        result &= i
    elif val <= v[5]:
      if color == true:
        result &= fgYellow($i)
      else:
        result &= i
    elif val <= v[6]:
      if color == true:
        result &= fgGreen($i)
      else:
        result &= i
    else:
      if color == true:
        result &= fgGreen($i)
      else:
        result &= i

proc isOnlySpaces(s: string): bool =
  for c in s:
    if c != ' ':
      return false
  return true

proc highlightOligoMatches(r: string, matches: seq[seq[int]], oligo_length:int, color: proc): string =
  var
    glyphs = newSeq[string](len(r))
  
  for i in 0 ..< len(r):
    glyphs[i] = " "


  if len(matches[0]) > 0:
    for m in matches[0]:
      let 
        stop = if m >= 0: oligo_length
               else: oligo_length + m
        start = if m >= 0: m
              else: 0
      for i in start ..< start+stop:
        if i < len(glyphs):
          glyphs[i] = ">".color.fgWhite # was ᐅ

  #echo r
  if len(matches[1]) > 0:
    for m in matches[1]:
      let 
        stop = if m >= 0: oligo_length
               else: oligo_length + m
        start = if m >= 0: m
              else: 0
              
      for i in start ..< start+stop:
        if i < len(glyphs):
          glyphs[i] = "<".color.fgWhite # was ᐅ
  
  return glyphs.join("")

proc fastx_view(argv: var seq[string]): int =
  let args = docopt("""
Usage: view [options] <inputfile> [<input_reverse>]

View a FASTA/FASTQ file for manual inspection, allowing to search for
an oligonucleotide.

Options:
  -o, --oligo1 OLIGO     Match oligo, with ambiguous IUPAC chars allowed
                         (rev. compl. search is performed), color blue
  -r, --oligo2 OLIGO     Second oligo to be scanned for, color red
  -q, --qual-scale STR   Quality thresholds, seven values
                         separated by columns [default: 3:15:25:28:30:35:40]

  --match-ths FLOAT      Oligo matching threshold [default: 0.75]
  --min-matches INT      Oligo minimum matches [default: 5]
  --max-mismatches INT   Oligo maxmimum mismataches [default: 2]
  --ascii                Encode the quality as ASCII chars (when UNICODE is
                         not available)
  -Q, --qual-chars       Show quality characters instead of bars
  -n, --nocolor          Disable colored output
  --verbose              Show extra information
  -h, --help             Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]
  let
    ce = getCurrentEncoding()
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
    # Print seq name
    if args["--nocolor"]:
      echo "@", read.name, "\t", read.comment
    else:
      echo "@", (read.name).bold, "\t", (read.comment).fgLightGray
      
    if $args["--oligo1"] != "nil":
      let matches = findPrimerMatches(read.seq, $args["--oligo1"], matchThs, maxMismatches, minMatches)
      let forString = highlightOligoMatches(read.seq, matches, len($args["--oligo1"]), bgBlue)
      if forString.isOnlySpaces == false:
        echo forString
    if $args["--oligo2"] != "nil":
      let matches = findPrimerMatches(read.seq, $args["--oligo2"], matchThs, maxMismatches, minMatches)
      let revString = highlightOligoMatches(read.seq, matches, len($args["--oligo2"]), bgRed)
      if revString.isOnlySpaces == false:
        echo revString
    echo read.seq
    if args["--qual-chars"]:
      echo qualToColor(read.qual, thresholdValues, colorOutput)
    else:
      if args["--ascii"]:
        echo qualToAscii(read.qual, thresholdValues, colorOutput)
      else:
        echo qualToUnicode(read.qual, thresholdValues, colorOutput)

  if args["--verbose"]:
    stderr.writeLine("Encoding: ", ce)     
  return 0



 
