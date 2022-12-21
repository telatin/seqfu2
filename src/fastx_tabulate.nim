
import os
import zip/gzipfiles  # Import zip package
import readfq
import strutils 
import docopt
import ./seqfu_utils
 
 
proc isInterleaved(f: string): int =
  var
    c = 0
    s = newSeq[string]()
  for f in readfq(f):
    c += 1
    s.add(f.name)
    if (c == 2):
      if s[0] == s[1] and len(f.quality) > 0:
        # Read has quality (FASTQ) and same name of the previous
        return 1
      else:
        return 0
  # Not a FASTA/FASTQ file
  return -1

proc fieldToSeq(f: seq[string]): seq[int] =
  result = newSeq[int](8)
  for i, v in f:
    result[i] = len(v)

proc tot(s: seq[int]): int =
  result = 0
  for i, v in s:
    if v > 0:
      result = i

proc fastx_tabulate(argv: var seq[string]): int =
  let args = docopt("""
Usage: tabulate [options] [<file>]

Convert FASTQ to TSV and viceversa. Single end is a 4 columns table (name, comment, seq, qual),
paired end have 4 columns for the R1 and 4 columns for the R2. 
Paired end reads need to be supplied as interleaved.
 

Options:
  -i, --interleaved        Input is interleaved (paired-end)
  -d, --detabulate         Convert TSV to FASTQ (if reading from file is autodetected) 
  -c, --comment-sep CHAR   Separator between name and comment (default: tab)
  -s, --field-sep CHAR     Field separator when deinterleaving (default: tab)
  -v, --verbose            Verbose output
  -h, --help               Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]

  var 
    commentSeparator = if  $args["--comment-sep"] != "nil": $args["--comment-sep"]
                        else: "\t"
    fieldSeparator = if  $args["--field-sep"] != "nil": $args["--field-sep"]
                        else: "\t"
    inputFile      = if  $args["<file>"] != "nil": $args["<file>"]
                     else: "-"
    interleaved = if args["--interleaved"]: true 
                  else: false
    detabulate  = if args["--detabulate"]: true
                  else: false

  if verbose:
    stderr.writeLine("# [Seqfu tab] Reading from: ", inputFile)
    stderr.writeLine("# Field separator: \"", fieldSeparator, "\"")
    stderr.writeLine("# Comment separator: \"", commentSeparator, "\"")
    
  if inputFile != "-":
    if not fileExists(inputFile):
      stderr.writeLine("ERROR: File not found: ", inputFile)
      quit(1)
    else:
      let 
        inputFormat = isInterleaved(inputFile)
      if inputFormat < 0:
        if verbose:
          stderr.writeLine("# Autodetecting: tabulated")
        detabulate = true
      if inputFormat == 1:
        if verbose:
          stderr.writeLine("# Autodetecting: interleaved")
        interleaved = true

    


  if detabulate:
    # convert TSV to FASTQ (autodetect pairs)
    if inputFile == "-":
      inputFile = "/dev/stdin"
    if verbose:
      stderr.writeLine("[Detabulate] Importing tabular file: ", inputFile)
    let file = newGzFileStream(inputFile)
    defer: file.close()
    var 
      line: string  # Declare line variable
      c = 0
    while not file.atEnd():
      c += 1
      line = file.readLine()
      let
        fields = line.split(fieldSeparator)
        tot = len(fields)
        lens = fieldToSeq(fields)
      if verbose and c < 3:
        stderr.writeLine("Line ", c, ": ", tot, " fields:", lens, "[tot=", lens.tot, "]")
        
      # FASTA [Name, Comment/?, sequence]
      if lens.tot == 2 or (lens[3] == 0):
        # FASTA: Name, comment, sequence
        let
          name = fields[0]
          comment = if len(fields[1]) > 0 : commentSeparator & fields[1]
                    else: ""
          sequence = fields[2]
        echo '>', name, comment, "\n", sequence
      # FASTQ Single [Name, Comment, Sequence, Quality]
      elif (lens.tot == 3 ) and (lens[4] == 0):
        # FASTQ-se
        let
          name = fields[0]
          comment = if len(fields[1]) > 0 : commentSeparator & fields[1]
                    else: ""
          sequence = fields[2]
          quality  = fields[3]
        if len(sequence) != len(quality):
          stderr.writeLine("ERROR: Sequence and quality are not the same length at ", name)
          quit(1)
        echo '@', name, comment, "\n", sequence, "\n+\n", quality
      elif lens.tot == 7 and lens[7] > 0:
        # FASTQ-PE [R1 Name, R1 Comment, R1 Sequence, R1 Quality, R2 Name, R2 Comment, R2 Sequence, R2 Quality]
        let
          name1 = fields[0]
          comm1 = if len(fields[1]) > 0: commentSeparator & fields[1]
                  else: ""
          seq1  = fields[2]
          qual1 = fields[3]
          name2 = fields[4]
          comm2 = if len(fields[5]) > 0: commentSeparator & fields[5]
                  else: ""
          seq2  = fields[6]
          qual2 = fields[7]
        
        if  len(qual1) != len(seq1) or len(qual2) != len(seq2):
          # 1.10.1 - relaxed if: paired ends can be of different lengths
          stderr.writeLine("ERROR: Unequal sequence/quality lengths for paired reads:" , name1, " and ", name2)
          quit(1)
        else:
          echo '@', name1, comm1, "\n", seq1, "\n+\n", qual1, "\n@", name2, comm2, "\n", seq1, "\n+\n", qual2
      else:
        stderr.writeLine("ERROR: Unrecognized format: ", line)
        stderr.writeLine("Tot: ", lens.tot, " len[7]:", lens[7])
        quit(1)


  else:
     # [TABULATE] Convert to table
    if verbose:
      stderr.writeLine("Tabulating sequence file: ", inputFile, " (", interleaved, ")")
   
    if not interleaved:
      ## Single End = not interleaved
      for record in readfq(inputFile):
        let
          comment = (record.comment).multiReplace({"\t": " "})
        echo record.name, fieldSeparator, comment, fieldSeparator, record.sequence, fieldSeparator, record.quality
    else:
      ## Interleaved
      var
        c = 0
        R1: FQRecord
      for R2 in readfq(inputFile):
        
        let
          r2comment = (R2.comment).multiReplace({"\t": " "})        
        c += 1
        if (c mod 2) == 0:
          echo R1.name, fieldSeparator, R1.comment, fieldSeparator, R1.sequence, fieldSeparator, R1.quality, fieldSeparator, R2.name, fieldSeparator, R2.comment, fieldSeparator, R2.sequence, fieldSeparator, R2.quality

        # Assign current read to "previous" read, incl comment
        R1 = R2
        R1.comment = r2comment
