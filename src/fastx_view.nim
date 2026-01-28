import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import colorize
import encodings


proc formatQualString(s: string, thresholds: seq[int], useAscii: bool, useQualChars: bool, useColor: bool): string =
  let
    unicodeGlyphs = ["_", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    asciiGlyphs =   ["x", "_", "_", "o", "o", "i", "i", "I"]
    colors = [fgDarkGray, fgDarkGray, fgRed, fgRed, fgYellow, fgYellow, fgGreen, fgGreen]

  for qChar in s:
    let val = charToQual(qChar)
    var idx = 0
    if val <= thresholds[0]:    idx = 0
    elif val <= thresholds[1]:  idx = 1
    elif val <= thresholds[2]:  idx = 2
    elif val <= thresholds[3]:  idx = 3
    elif val <= thresholds[4]:  idx = 4
    elif val <= thresholds[5]:  idx = 5
    elif val <= thresholds[6]:  idx = 6
    else:                      idx = 7
    
    var displayChar: string
    if useQualChars:
      displayChar = $qChar
    elif useAscii:
      displayChar = asciiGlyphs[idx]
    else:
      displayChar = unicodeGlyphs[idx]

    if useColor:
      result &= colors[idx](displayChar)
    else:
      result &= displayChar

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


  for read in readfq($args["<inputfile>"]):
    let isFasta = (read.quality.len == 0) # Check if it's a FASTA file

    if args["--nocolor"]:
      if isFasta:
        echo ">", read.name, "\t", read.comment
      else:
        echo "@", read.name, "\t", read.comment
    else:
      if isFasta:
        echo ">", (read.name).bold, "\t", (read.comment).fgLightGray
      else:
        echo "@", (read.name).bold, "\t", (read.comment).fgLightGray
      
    if $args["--oligo1"] != "nil":
      let matches = findPrimerMatches(read.sequence, $args["--oligo1"], matchThs, maxMismatches, minMatches)
      let forString = highlightOligoMatches(read.sequence, matches, len($args["--oligo1"]), bgBlue)
      if forString.isOnlySpaces == false:
        echo forString
    if $args["--oligo2"] != "nil":
      let matches = findPrimerMatches(read.sequence, $args["--oligo2"], matchThs, maxMismatches, minMatches)
      let revString = highlightOligoMatches(read.sequence, matches, len($args["--oligo2"]), bgRed)
      if revString.isOnlySpaces == false:
        echo revString
    echo read.sequence
    if not isFasta:
      echo formatQualString(read.quality, thresholdValues, bool(args["--ascii"]), bool(args["--qual-chars"]), colorOutput)

  if args["--verbose"]:
    stderr.writeLine("Encoding: ", ce)     
  return 0



 
