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

Sequence name:
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -z, --strip-name       Remove the original sequence name
  -a, --append STRING    Append this string to the sequence name [default: ]
  --sep STRING           Sequence name fields separator [default: _]

  -b, --basename         Prepend file basename to the sequence name (before prefix)
  --split CHAR           Split basename at this char [default: .]
  --part INT             After splitting the basename, take this part [default: 1]
  --basename-sep STRING  Separate basename from the rest with this [default: _]

Sequence comments:
  -s, --strip-comments   Remove original sequence comments
  --comment-sep CHAR     Comment separator [default:  ]
  --add-len              Add 'len=LENGTH' to the comments
  --add-initial-len      Add 'original_len=LENGTH' to the comments
  --add-gc               Add 'gc=%GC' to the comments
  --add-initial-gc       Add 'original_gc=%GC' to the comments
  --add-name             Add 'original_name=INITIAL_NAME' to the comments

Filtering:
  -m, --min-len INT      Discard sequences shorter than INT [default: 1]
  -x, --max-len INT      Discard sequences longer than INT, 0 to ignore [default: 0]
  --trim-front INT       Trim INT base from the start of the sequence [default: 0]
  --trim-tail INT        Trim INT base from the end of the sequence [default: 0]
  --truncate INT         Keep only the first INT bases, 0 to ignore  [default: 0]
                         Negative values to print the last INT bases

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --list                 Output a list of sequence names 
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta = args["--fasta"]
    forceFastq = args["--fastq"]
    defaultQual = parseInt($args["--fastq-qual"])

    let
      GC_DECIMAL_DIGITS = 2

    var
      appendToName: string
      appendSuffixToName: bool
      formatList: bool
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
      basenameSeparatorString: string

    try:
      appendToName = $args["--append"]
      appendSuffixToName = if len(appendToName) > 0: true
                           else: false
      basenameSeparatorString = $args["--basename-sep"]
      formatList = args["--list"]
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

    if args["--strip-name"] and not args["--prefix"] and not args["--basename"]:
      stderr.writeLine("WARNING: Suppressing names is not recommended.")
      
    if args["--prefix"]:
      prefix = $args["--prefix"]

    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu cat] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
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

        # Skip sequences [store in y==0 the ok to print]
        if skip > 0:
          y = currentSeqCount mod skip

        if y == 0:
          # Print sequence
          currentPrintedSeqs += 1
          
          let 
            original_name = r.name

          # Remove comments
          if stripComments:
            r.comment = ""

          # Add comments if needed
          if args["--add-initial-len"]:
            r.comment &= $args["--comment-sep"] & "initial_len=" & $(len(r.seq))
          if args["--add-initial-gc"]:
            r.comment &= $args["--comment-sep"] & "initial_gc=" & get_gc(r.seq).formatFloat(ffDecimal, GC_DECIMAL_DIGITS)

          ## TRIM FRONT / TAIL
          if trimFront > 0 or trimEnd > 0:
            r.seq = r.seq[trimFront .. ^trimEnd]
            if len(r.qual) > 0:
              r.qual = r.qual[trimFront .. ^trimEnd]
          
          ## TRUNCATE
          if truncate > 0:
            r.seq = r.seq[0 .. truncate-1]
            if len(r.qual) > 0:
              r.qual = r.qual[0 .. truncate-1]
          elif truncate < 0:
            r.seq = r.seq[^(truncate * -1) .. ^1]
            if len(r.qual) > 0:
              r.qual = r.qual[^(truncate * -1) .. ^1]

          ## DISCARD BY LEN [after trimming/truncating]  
          if len(r.seq) < minSeqLen or (maxSeqLen > 0 and len(r.seq) > maxSeqLen):
            wrongLenCount += 1
            continue 
          
          # Checkpoint: sequence survived
          totalPrintedSeqs   += 1

          ## SEQUENCE NAME
          var
            newName = ""
            baseNamePrefix = ""
            seqNumber = ""
 
          # Rename prefix, counter, ...
          # [ Basename ] [ prefix ] [ realname ] [ counter ]

          # Sequence name:
          #   -p, --prefix STRING    Rename sequences with prefix + incremental number
          #   -z, --strip-name       Remove the original sequence name
          #   -a, --append STRING    Append this string to the sequence name [default: ]
          #   --sep STRING           Sequence name fields separator [default: _]

          #   -b, --basename         Prepend file basename to the sequence name
          #   --split CHAR           Split basename at this char [default: .]
          #   --part INT             After splitting the basename, take this part [default: 1]
          #   --basename-sep STRING  Separate basename from the rest with this [default: _]

          # Sequence comments:
          #   -s, --strip-comments   Remove original sequence comments 

          # Prepend basename if required
          if printBasename:
            if len(splitChar) > 0:
              baseNamePrefix = lastPathPart(filename).split(splitChar)[splitPart]  
            else:
              baseNamePrefix = lastPathPart(filename)  

            if not args["--strip-name"] or prefix != "":
              baseNamePrefix &= basenameSeparatorString
            newName = baseNamePrefix 

          # Prepare sequence name
          if prefix != "":
            # PREFIX to be added 
            if printBasename:
              seqNumber = $currentPrintedSeqs
            else:
              seqNumber = $totalPrintedSeqs

            if args["--strip-name"]:
              newName &= prefix & separator & seqNumber
            else:
              newName &= prefix & separator & original_name #& separator & seqNumber
          else:
              if printBasename:
                if not args["--strip-name"]:
                  newName &= original_name
                else:
                  # add suffix if you strip basename
                  newName &= separator & seqNumber
              else:
                newName = original_name 

          # Append suffix to name
          if appendSuffixToName:
            newName &= appendToName

          # Replace name if needed
          r.name = newName

          ## COMMENTS AFTER TRIMMING
          if args["--add-len"]:
            r.comment &= $args["--comment-sep"] & "len=" & $len(r.seq)

          if args["--add-gc"]:
            r.comment &= $args["--comment-sep"] & "gc=" & get_gc(r.seq).formatFloat(ffDecimal, GC_DECIMAL_DIGITS)

          if args["--add-name"]:
            r.comment &= $args["--comment-sep"] & "original_name=" & original_name

          # Print output
          if formatList:
            echo r.name
            continue
          elif len(r.qual) > 0:
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

      
 