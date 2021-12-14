import klib
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import re

proc fastx_grep(argv: var seq[string]): int =
    let args = docopt("""
Usage: grep [options] [<inputfile> ...]

Print sequences selected if they match patterns or contain oligonucleotides

Options:
  -n, --name STRING      String required in the sequence name
  -r, --regex PATTERN    Pattern to be matched in sequence name
  -c, --comment          Also search -n and -r in the comment
  -f, --full             The string or pattern covers the whole name
                         (mainly used without -c)
  -w, --word             The string or pattern is a whole word
                         (only effective with -c, as names do not contain spaces)
  -i, --ignore-case      Ignore case when matching names (is already enabled with regexes)
  -o, --oligo IUPAC      Oligonucleotide required in the sequence,
                         using ambiguous bases and reverse complement
  -A, --append-pos       Append matching positions to the sequence comment
  --max-mismatches INT   Maximum mismatches allowed [default: 0]
  --min-matches INT      Minimum number of matches [default: oligo-length]
  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
  
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
    
    
    for filename in files:
      if filename != "-"  and not fileExists(filename):
        stderr.writeLine("Skipping ", filename, ": not found")
        continue
      else:
        echoVerbose(filename, verbose)

      var 
        f = xopen[GzFile](filename)
        r: FastxRecord
        pattern = if matchFull: optRegexString
                  elif matchWord: "\\b" & optRegexString & "\\b"
                  else: ".*" & optRegexString & ".*"
        
      defer: f.close()
      
      if args["--verbose"]:
        if optQueryString != "nil":
          stderr.writeLine("Name contains: ", optQueryString)
        
        if optRegexString != "nil":
          stderr.writeLine("Name matches: ", optRegexString)

      while f.readFastx(r):
        var pass = 1
        var matches : seq[string]

        let readName = if matchIgnoreCase: (r.name).toUpperAscii()
                       else: r.name
        
        let readComment = if matchIgnoreCase: (r.comment).toUpperAscii()
                          else: r.comment
      
        let qualifiedName = if matchComment: readName & "\t" & readComment
                            else: readName
        

        ### -n STRING [-c, -w, -f]
        if optQueryString != "nil":
          # Also search in comment
          if matchComment:
            if matchFull:
              # the string should be equal to the whole name (-c useless?) or the comment (weird but ok)
              if optQueryString != readName and optQueryString != readComment:
                pass = 0
            elif matchWord:
              # Check a word inside the comment, or the whole name (cant have spaces)
              if optQueryString != readName and rfind(readComment, optQueryString) < 0:
                pass = 0
            else:
              # Check for a string inside read name or comment
              if rfind(readName, optQueryString) < 0 and rfind(readComment, optQueryString) < 0:
                pass = 0
          
          # Search only in name
          else:
            if matchFull:
              # the string should be equal to the whole name
              if optQueryString != readName:
                pass = 0
            else:
              # Check for a string inside read name (word or not does not change here)
              if rfind(readName, optQueryString) < 0:
                pass = 0
          
            
        ## REGEX
        if optRegexString != "nil" and not match(readName, re(pattern, flags={reIgnoreCase}), matches):
          pass = 0

        if $args["--oligo"] != "nil":
          # Search for oligo in the sequence
          let oligos = findPrimerMatches(r.seq, $args["--oligo"], matchThs, maxMismatches, minMatches)
          if len(oligos[0]) == 0 and len(oligos[1]) == 0:
            pass = 0
          else:
            if args["--append-pos"]:
              r.comment &= " for-matches=" & strutils.join(oligos[0], ",")
              r.comment &= ":rev-matches=" & strutils.join(oligos[0], ",")
        if pass == 1:
          print_seq(r, nil)
          

