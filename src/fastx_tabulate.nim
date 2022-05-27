
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
  -s, --field-sep CHAR     Field separator (default: tab)
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

    
  if verbose:
    stderr.writeLine("# Reading from: ", inputFile)
    stderr.writeLine("# Field separator: \"", fieldSeparator, "\"")
    stderr.writeLine("# Comment separator: \"", commentSeparator, "\"")

  if detabulate:
    # convert TSV to FASTQ (autodetect pairs)
    if inputFile == "-":
      inputFile = "/dev/stdin"
    if verbose:
      stderr.writeLine("Importing tabular file: ", inputFile)
    let file = newGzFileStream(inputFile)
    defer: file.close()
    var line: string  # Declare line variable
    while not file.atEnd():
      line = file.readLine()
      let fields = line.split(fieldSeparator)
      if len(fields) == 3:
        # FASTA: Name, comment, sequence
        let
          name = fields[0]
          comment = if len(fields[1]) > 0 : commentSeparator & fields[1]
                    else: ""
          sequence = fields[2]
        echo '>', name, comment, "\n", sequence
      elif len(fields) == 4:
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
      elif len(fields) == 8:
        # FASTQ-PE
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
        stderr.writeLine("Unsupported format: ", len(fields), " columns found. Expecting 3, 4 or 8.")
        stderr.writeLine("Line: ", line)
        if len(fields) == 1:
          stderr.writeLine("Are you using the correct field separator? <", fieldSeparator, ">")
        quit(1)

  else:
    if verbose:
      stderr.writeLine("Tabulating sequence file: ", inputFile)
    # Convert to table
    if not interleaved:
      for record in readfq(inputFile):
        echo record.name, fieldSeparator, record.comment, fieldSeparator, record.sequence, fieldSeparator, record.quality
    else:
      var
        c = 0
        R1: FQRecord
      for R2 in readfq(inputFile):
        c += 1
        if (c mod 2) == 0:
          echo R1.name, fieldSeparator, R1.comment, fieldSeparator, R1.sequence, fieldSeparator, R1.quality, fieldSeparator, R2.name, fieldSeparator, R2.comment, fieldSeparator, R2.sequence, fieldSeparator, R2.quality
        R1 = R2
