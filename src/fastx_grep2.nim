import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import regex except re, match, replace, Regex

proc isWordMatch(text, word: string): bool =
  var pos = 0
  while pos < text.len:
    let idx = text.find(word, pos)
    if idx < 0:
      return false
    let before = if idx == 0: true else: not text[idx-1].isAlphaNumeric()
    let after = if idx + word.len >= text.len: true else: not text[idx + word.len].isAlphaNumeric()
    if before and after:
      return true
    pos = idx + 1
  return false

proc fastx_grep2(argv: var seq[string]): int =
    let args = docopt("""
Usage: grep [options] [<inputfile> ...]

Print sequences selected if they match patterns or contain oligonucleotides
using regular expressions.

Name and comment search:
  -n, --name STRING      String required inside the sequence name (see -f)
  -r, --regex PATTERN    Pattern to be matched in sequence name
  -c, --comment          Also search -n and -r in the comment
  -f, --full             The string or pattern covers the whole name
                         (mainly used without -c)
  -w, --word             The string or pattern is a whole word
  -i, --ignore-case      Ignore case when matching names (is already enabled with regexes)

Sequence search:
  -o, --oligo IUPAC      Oligonucleotide required in the sequence,
                         using ambiguous bases and reverse complement
  -A, --append-pos       Append matching positions to the sequence comment
  --max-mismatches INT   Maximum mismatches allowed [default: 0]
  --min-matches INT      Minimum number of matches [default: oligo-length]

General options:
  -v, --invert-match     Invert match (print sequences that do not match)
  --verbose              Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = bool(args["--verbose"])
  
    var
      files        : seq[string]  
      matchThs = 1.0
      maxMismatches = 0
      minMatches = 2
    let
      matchIgnoreCase = bool(args["--ignore-case"])
      optRegexString = $args["--regex"]
      optQueryString = if matchIgnoreCase: ($args["--name"]).toUpperAscii()
                       else: $args["--name"]
      
      invertMatch = bool(args["--invert-match"])
      matchComment = bool(args["--comment"])
      matchWord = bool(args["--word"])
      matchFull = bool(args["--full"])

    
    try:
      maxMismatches = parseInt($args["--max-mismatches"])
      if $args["--min-matches"] == "oligo-length":
        if $args["--oligo"] != "nil":
          minMatches = len($args["--oligo"])
      else:
        minMatches =  parseInt($args["--min-matches"])
    except Exception as e:
      stderr.writeLine("Error parsing parameters: oligo matches are Integer. ", e.msg)
      quit(1)

    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu grep] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    if args["--append-pos"] and $args["--oligo"] == "nil":
      stderr.writeLine("Error: --append-pos requires --oligo")
      quit(1)
    
    for filename in files:
      if filename != "-"  and not fileExists(filename):
        stderr.writeLine("ERROR: ", filename, ": not found (skipping)")
        continue
      else:
        echoVerbose(filename, verbose)

      var 
        compiledRegex: regex.Regex2
        hasRegex = false
      
      if optRegexString != "nil":
        let pattern = if matchFull: optRegexString
                      elif matchWord: "\\b" & optRegexString & "\\b"
                      else: ".*" & optRegexString & ".*"
        compiledRegex = regex.re2("(?i)" & pattern)
        hasRegex = true
      
      if args["--verbose"]:
        if optQueryString != "nil":
          stderr.writeLine("Name contains: ", optQueryString)
        
        if hasRegex:
          stderr.writeLine("Name matches: ", optRegexString)

      for fqRead in readfq(filename):
        var
          print_this_sequence = not invertMatch

        let
          readNameOnly = if matchIgnoreCase: (fqRead.name).toUpperAscii()
                       else: fqRead.name
        
          readCommentOnly = if matchIgnoreCase: (fqRead.comment).toUpperAscii()
                          else: fqRead.comment

          readSequence = if matchIgnoreCase: (fqRead.sequence).toUpperAscii()
                         else: fqRead.sequence
        

        ### -n STRING [-c, -w, -f]
        if optQueryString != "nil":
          # Also search in comment
          if matchComment:
            if matchFull:
              # the string should be equal to the whole name (-c useless?) or the comment (weird but ok)
              if optQueryString != readNameOnly and optQueryString != readCommentOnly:
                print_this_sequence = invertMatch
            elif matchWord:
              # Check a word inside the comment, or the whole name (cant have spaces)
              if optQueryString != readNameOnly and not isWordMatch(readCommentOnly, optQueryString):
                print_this_sequence = invertMatch
            else:
              # Check for a string inside read name or comment
              if rfind(readNameOnly, optQueryString) < 0 and rfind(readCommentOnly, optQueryString) < 0:
                print_this_sequence = invertMatch
          
          # Search only in name
          else:
            if matchFull or matchWord:
              # the string should be equal to the whole name
              if optQueryString != readNameOnly:
                print_this_sequence = invertMatch
            else:
              # Check for a string inside read name (word or not does not change here)
              if rfind(readNameOnly, optQueryString) < 0:
                print_this_sequence = invertMatch
          
            
        ## REGEX
        if hasRegex:
          if matchComment:
            if not regex.match(readNameOnly, compiledRegex) and not regex.match(readCommentOnly, compiledRegex):
              print_this_sequence = invertMatch
          elif not regex.match(readNameOnly, compiledRegex):
            print_this_sequence = invertMatch

        var outRecord: FQRecord
        
        if $args["--oligo"] != "nil":
          outRecord = fqRead
          let oligos = findPrimerMatches(readSequence, $args["--oligo"], matchThs, maxMismatches, minMatches)
          if len(oligos[0]) == 0 and len(oligos[1]) == 0:
            print_this_sequence = invertMatch
          else:
            if args["--append-pos"]:
              outRecord.comment &= " for-matches=" & strutils.join(oligos[0], ",")
              outRecord.comment &= ":rev-matches=" & strutils.join(oligos[1], ",")
        
        if print_this_sequence:
          if $args["--oligo"] != "nil":
            print_seq(outRecord, nil)
          else:
            print_seq(fqRead, nil)
          
