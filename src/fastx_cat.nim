import klib
import tables, strutils
from os import fileExists, lastPathPart
import docopt
import ./seqfu_utils


proc fastx_cat(argv: var seq[string]): int =
    let args = docopt("""
Usage: cat [options] [<inputfile> ...]

Concatenate multiple FASTA or FASTQ files.

Options:
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]

  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -z, --strip-name       Remove name
  -b, --basename         Prepend file basename to the sequence name
  --split CHAR           Split basename at this char [default: .]
  --part INT             After splitting the basename, take this part [default: 1]

  -m, --min-len INT      Discard sequences shorter than INT [default: 1]
  -x, --max-len INT      Discard sequences longer than INT, 0 to ignore [default: 0]
  --trim-front INT       Trim INT base from the start of the sequence [default: 0]
  --trim-tail INT        Trim INT base from the end of the sequence [default: 0]
  --truncate INT         Keep only the first INT bases, 0 to ignore  [default: 0]

  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta = args["--fasta"]
    forceFastq = args["--fastq"]
    defaultQual = parseInt($args["--fastq-qual"])
    var
      skip   : int
      prefix : string
      files  : seq[string]  
      printBasename: bool 
      splitChar : string
      splitPart : int
      separator:  string 
      minSeqLen,maxSeqLen: int
      trimFront, trimEnd: int
      truncate: int

    try:
      skip =  parseInt($args["--skip"])
      printBasename = args["--basename"] 
      separator = $args["--sep"]
      minSeqLen = parseInt($args["--min-len"])
      maxSeqLen = parseInt($args["--max-len"])
      trimFront = parseInt($args["--trim-front"])
      trimEnd   = parseInt($args["--trim-tail"]) + 1
      truncate  = parseInt($args["--truncate"])
      splitChar = $args["--split"]
      splitPart = parseInt($args["--part"]) - 1

    except Exception as e:
      stderr.writeLine("Error: unexpected parameter value. ", e.msg)
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    if args["<inputfile>"].len() == 0:
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    var
      totalPrintedSeqs = 0
      wrongLenCount = 0
    for filename in files:
      echoVerbose(filename, verbose)

      if filename != "-" and not fileExists(filename):
        stderr.writeLine("Skipping <", filename, ">: not found")
        continue

      var 
        f = xopen[GzFile](filename)
        y = 0
        r: FastxRecord
        
      defer: f.close()
      var 
        currentSeqCount    = 0
        currentPrintedSeqs = 0
      
      
      while f.readFastx(r):
        currentSeqCount += 1

        if skip > 0:
          y = currentSeqCount mod skip

        if y == 0:
          # Print sequence
          currentPrintedSeqs += 1
          
          

          ## TRIM FRONT / TAIL
          if trimFront > 0 or trimEnd > 0:
            r.seq = r.seq[trimFront .. ^trimEnd]
            if len(r.qual) > 0:
              r.qual = r.qual[trimFront .. ^trimEnd]
          
          ## TRUNCATE
          if truncate > 0:
            r.seq = r.seq[0 .. truncate-1]
            if len(r.qual) > 0:
              r.qual = r.qual[trimFront .. ^trimEnd]

          ## DISCARD BY LEN           
          if len(r.seq) < minSeqLen or (maxSeqLen > 0 and len(r.seq) > maxSeqLen):
            wrongLenCount += 1
            continue 
          
          # Checkpoint: sequence survived
          totalPrintedSeqs   += 1

          ## SEQUENCE NAME
          var
            newName = ""

          # Prepend basename if required
          if printBasename:
            var bn: string
            if len(splitChar) > 0:
              bn = lastPathPart(filename).split(splitChar)[splitPart]
            else:
              bn = lastPathPart(filename)
            newName =  bn & separator
          
          # rename with prefix + counter
          if prefix != "":
            newName &= prefix & separator
            if printBasename:
              newName &= $currentPrintedSeqs
            else:
              newName &= $totalPrintedSeqs
          else:
            if not args["--strip-name"]:
              newName &= r.name
          
          r.name = newName

          if not args["--strip-comments"]:
            newName &= "\t" & r.comment
          
          if len(r.qual) > 0:
            # Record is FASTQ
            if args["--fasta"]:
              # Force FASTA
              r.qual = ""
          else:
            # Record is FASTA
            if args["--fastq"]:
              r.qual = repeat(qualToChar(defaultQual), len(r.seq))

          
          echo printFastxRecord(r)

      # File parsed
      if verbose:
        stderr.writeLine(currentPrintedSeqs, "/", currentSeqCount, " sequences printed. ", wrongLenCount, " wrong length.")

      
 