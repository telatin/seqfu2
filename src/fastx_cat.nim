import klib
import tables, strutils
from os import fileExists, lastPathPart
import docopt
import ./seqfu_utils
import math

type outputFormat = enum
  sINIT # First value is the default
  sFASTQ
  sFASTA

proc get_ee(s: string): float =
  
  # Requires math
  for c in s:
    let
      Q = charToQual(c)
      P = pow(10, ((-1 * Q) / 10))
    result += P


proc addZeros(n: string, digits: int): string =
  result = $n
  while result.len() < digits:
    result = "0" & result

proc fastx_cat(argv: var seq[string]): int =
    let args = docopt("""
Usage: cat [options] [<inputfile> ...]

Concatenate multiple FASTA or FASTQ files.

Options:
  -k, --skip STEP        Print one sequence every STEP [default: 0]
  --skip-first INT       Skip the first INT records [default: -1]
  --jump-to STR          Start from the record after the one named STR
                         (overrides --skip-first)
  --print-last           Print the name of the last sequence to STDERR (Last:NAME)

Sequence name:
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -z, --strip-name       Remove the original sequence name
  -a, --append STRING    Append this string to the sequence name [default: ]
  --sep STRING           Sequence name fields separator [default: _]

  -b, --basename         Prepend file basename to the sequence name (before prefix)
  --split CHAR           Split basename at this char [default: .]
  --part INT             After splitting the basename, take this part [default: 1]
  --basename-sep STRING  Separate basename from the rest with this [default: _]
  --zero-pad INT         Zero pad the counter to INT digits [default: 0]

Sequence comments:
  -s, --strip-comments   Remove original sequence comments
  --comment-sep CHAR     Comment separator [default:  ]
  --add-len              Add 'len=LENGTH' to the comments
  --add-initial-len      Add 'original_len=LENGTH' to the comments
  --add-gc               Add 'gc=%GC' to the comments
  --add-initial-gc       Add 'original_gc=%GC' to the comments
  --add-name             Add 'original_name=INITIAL_NAME' to the comments
  --add-ee               Add 'ee=EXPECTED_ERROR' to the comments
  --add-initial-ee       Add 'original_ee=EXPECTED_ERROR' to the comments

Filtering:
  -n, --max-ns INT       Discard sequences with more than INT Ns [default: -1]
  -m, --min-len INT      Discard sequences shorter than INT [default: 1]
  -x, --max-len INT      Discard sequences longer than INT, 0 to ignore [default: 0]
  --max-ee FLOAT         Discard sequences with higher than FLOAT expected error [default: -1.0]
  --trim-front INT       Trim INT base from the start of the sequence [default: 0]
  --trim-tail INT        Trim INT base from the end of the sequence [default: 0]
  --truncate INT         Keep only the first INT bases, 0 to ignore  [default: 0]
                         Negative values to print the last INT bases
  --max-bp INT           Stop printing after INT bases [default: 0]

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --report FILE          Save a report to FILE (original name, new name)
  --list                 Output a list of sequence names 
  --anvio                Output in Anvio format (-p c_ -s -z --zeropad 12 --report rename_report.txt)
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  --debug                Debug output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = bool(args["--verbose"])
    stripComments = bool(args["--strip-comments"])
    stripName = bool(args["--strip-name"])
    forceFasta = bool(args["--fasta"])
    forceFastq = bool(args["--fastq"])
    defaultQual = parseInt($args["--fastq-qual"])

    let
      GC_DECIMAL_DIGITS = 2
      EE_DECIMAL_DIGITS = 4
      printLast = bool(args["--print-last"])


    var
      outputFormat : outputFormat # added: 1.18
      reportFileName: string
      renameReport : string = ""
      newMod = 0
      appendToName: string
      appendSuffixToName: bool
      formatList: bool
      maxBp: int
      skip   : int
      skip_first : int
      jump_to: string
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
      maxNs: int
      maxEe: float
      debug: bool
      zeropad: int
    try:
      #stripName = bool(args["--strip-name"])
      reportFileName = $args["--report"]
      zeropad = parseInt($args["--zero-pad"])
      debug = bool(args["--debug"])
      appendToName = $args["--append"]
      appendSuffixToName = if len(appendToName) > 0: true
                           else: false
      basenameSeparatorString = $args["--basename-sep"]
      formatList = args["--list"]
      skip =  parseInt($args["--skip"])
      skip_first = parseInt($args["--skip-first"])
      maxBp = parseint($args["--max-bp"])
      jump_to = if args["--jump-to"]: $args["--jump-to"]
                else: ""
      printBasename = args["--basename"] 
      separator = $args["--sep"]
      minSeqLen = parseInt($args["--min-len"])
      maxSeqLen = parseInt($args["--max-len"])
      trimFront = parseInt($args["--trim-front"])
      trimEnd   = parseInt($args["--trim-tail"]) + 1
      truncate  = parseInt($args["--truncate"])
      splitChar = $args["--split"]
      splitPart = parseInt($args["--part"]) - 1
      maxNs = parseInt($args["--max-ns"])
      maxEe = parseFloat($args["--max-ee"])
      prefix = if $args["--prefix"] != "nil": $args["--prefix"]
               else: ""
    except Exception as e:
      stderr.writeLine("Error: unexpected parameter value. ", e.msg)
      quit(1)




    if stripName and not args["--prefix"] and not args["--basename"]:
      stderr.writeLine("WARNING: Suppressing names is not recommended.")
      
    if args["--prefix"]:
      prefix = $args["--prefix"]

    # ANVIO
    if bool(args["--anvio"]):
      # Report name if not set
      if $args["--report"] == "nil":
        reportFileName = "rename_report.txt"

      # Set parameters
      stripName = true
      stripComments = true
      prefix = "c_"
      zeropad = 12
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu cat] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    if bool(args["--fasta"]):
      outputFormat = sFASTA
    elif bool(args["--fastq"]):
      outputFormat = sFASTQ

    var
      totalPrintedSeqs = 0
      wrongLenCount = 0
      lastName = ""
    for filename in files:

      echoVerbose(filename, verbose)

      if filename != "-" and not fileExists(filename):
        stderr.writeLine("Skipping <", filename, ">: not found")
        continue

      var 
        f = xopen[GzFile](filename)
        r: FastxRecord
        y = 0
        
      defer: f.close()
      var 
        
        currentSeqCount    = 0
        currentPrintedSeqs = 0
        totBp              = 0
      

      if len(jump_to) > 0:
        while f.readFastx(r):
          if r.name == jump_to:
            break
      elif skip_first >= 0:
        # Before introducing --skip-first the first, when using --skip, the first record was skipped.
        # This is no longer ideal, but to allow backwards compatibility, we default --skip-first -1
        # to have the old behavior, any other value will be used as the new behaviour o starting from
        # the first record when --skip-first 0 and --skip INT>0 is used.
        newMod = 1
        y = 1
        if skip_first > 0:
          var j = 0
          while f.readFastx(r):
            j += 1
            if j >= skip_first:
                break
            

            
      while f.readFastx(r):


        currentSeqCount += 1

        #if currentSeqCount < 0:
        #  continue
        # Skip sequences [store in y==0 the ok to print]
        if skip > 0:
          y = currentSeqCount mod skip

        if y == newMod:
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
          if args["--add-initial-ee"]:
            r.comment &= $args["--comment-sep"] & "initial_ee=" & get_ee(r.qual).formatFloat(ffDecimal, EE_DECIMAL_DIGITS)

          ## TRIM FRONT / TAIL
          if trimFront > 0 or trimEnd > 0:
            try:
              r.seq = r.seq[trimFront .. ^trimEnd]
              if len(r.qual) > 0:
                r.qual = r.qual[trimFront .. ^trimEnd]
            except Exception:
              if verbose:
                stderr.writeLine("WARNING: Trimming sequence failed: ", r.name, " len=", len(r.seq))
              continue
          
          ## TRUNCATE
          ## Keep only the first INT bases, 0 to ignore 
          if truncate > 0 and abs(truncate) <= len(r.seq):
            try:
              r.seq = r.seq[0 .. truncate-1]
              if len(r.qual) > 0:
                r.qual = r.qual[0 .. truncate-1]
            except Exception:
              if verbose:
                stderr.writeLine("WARNING: Truncating sequence failed: ", r.name, " len=", len(r.seq))
              continue
          elif truncate < 0 and abs(truncate) <= len(r.seq):
            try:
              r.seq = r.seq[^(truncate * -1) .. ^1]
              if len(r.qual) > 0:
                r.qual = r.qual[^(truncate * -1) .. ^1]
            except Exception:
              if verbose:
                stderr.writeLine("WARNING: Truncating sequence failed: ", r.name, " len=", len(r.seq))
              continue

          ## DISCARD BY LEN [after trimming/truncating]  
          if len(r.seq) < minSeqLen or (maxSeqLen > 0 and len(r.seq) > maxSeqLen):
            wrongLenCount += 1
            continue 
          
          ## Check for Ns
          if maxNs >= 0 and r.seq.count("N") >= maxNs:
            continue

          ## Check for EEs
          if maxEe >= 0.0 and get_ee(r.qual) > maxEe:
            continue

          totBp += len(r.seq)
          if maxBp > 0 and totBp > maxBp:
            if debug:
              stderr.writeLine("Stopping at maxBp: ", totBp, ">", maxBp)
            break

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

            #if not stripName:
            baseNamePrefix &= basenameSeparatorString
            newName = baseNamePrefix 


          # Prepare sequence name
          if prefix != "" or (stripName and not args["--prefix"]):
            # PREFIX to be added 
            if printBasename:
              seqNumber = $currentPrintedSeqs
            else:
              seqNumber = $totalPrintedSeqs

            if zeropad > 0:
              seqNumber = addZeros(seqNumber, zeropad)

            if stripName:
              #if len(prefix) > 0:
              #  prefix &= separator
              newName &= prefix & seqNumber
            else:
              #if len(prefix) > 0:
              #  prefix &= separator
              newName &= prefix & original_name #& separator & seqNumber
          else:
              if printBasename:
                if not stripName:
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

          if args["--add-ee"]:
            r.comment &= $args["--comment-sep"] & "ee=" & get_ee(r.qual).formatFloat(ffDecimal, EE_DECIMAL_DIGITS)


          lastName = r.name

          # Set output format
          if outputFormat == sINIT:
            if len(r.qual) > 0:
              outputFormat = sFASTQ
            else:
              outputFormat = sFASTA

          # Print output
          if formatList:
            echo r.name
            continue

          if outputFormat == sFASTA and len(r.qual) > 0:
              r.qual = ""
          elif outputFormat == sFASTQ and len(r.qual) == 0:
            if args["--fastq"]:
              r.qual = repeat(qualToChar(defaultQual), len(r.seq))
            else:
              stderr.writeLine("WARNING: found a record without quality (", r.name, "), but you didnt specify --fasta")
              quit(1)

          # REPORT: original_name\t r.name
          if $args["--report"] != "nil":
            renameReport &= r.name & "\t" & original_name & "\n"
          echo printFastxRecord(r)

      # File parsed
      if verbose:
        stderr.writeLine(currentPrintedSeqs, "/", currentSeqCount, " sequences printed. ", wrongLenCount, " wrong length.")
      if printLast:
        stderr.writeLine("Last:", lastName)
      
    if reportFileName != "nil":
      try:
        var f = open(reportFileName, fmWrite)
        defer: f.close()
        f.write(renameReport)
      except Exception:
        stderr.writeLine("Unable to write MultiQC report to ", $args["--multiqc"],": printing to STDOUT instead.")
        echo renameReport
 