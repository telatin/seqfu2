import readfq
import docopt
import os
import posix
import strutils
signal(SIG_PIPE, SIG_IGN)

let version = "1.0"

# Handle Ctrl+C interruptions and pipe breaks
type EKeyboardInterrupt = object of CatchableError
proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
setControlCHook(handler)

proc `$`*(s: FQRecord): string = 
  # Procedure to convert a sequence to string
  if len(s.sequence) == 0:
    return ""

  let
    cmnt = if len(s.comment) > 0: " " & s.comment
           else: ""

  if len(s.quality) > 0:
    "@" & s.name & cmnt & "\n" & s.sequence & "\n+\n" & s.quality
  else:
    ">" & s.name & cmnt & "\n" & s.sequence
  

proc processRead(s: FQRecord, minlen, maxlen: int): FQRecord = 
  result.sequence = ""
  result.quality  = ""
  result.name     = ""
  # Core procedure to "manipulate" a single sequenc
  if (len(s.sequence) < minlen) or (maxlen > 0 and len(s.sequence) > maxlen):    
    return
  else:
    return s

proc main(): int =
  let args = docopt("""
  Fastx utility

  A program to print the sequence size of each record in a FASTA/FASTQ file

  Usage: 
  fastx_utility [options] -i Input_File 

  Options:
    -i, --input-file FILE      FASTA or FASTQ file
    -m, --min-len INT      Minimum sequence length [default: 10]
    -x, --max-len INT      Discard sequences longer than this, 0 for unlimited [default: 0]
    -s, --separator STRING     Separator between sequence name and size [default: TAB]
  
  """, version=version, argv=commandLineParams())

  
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  let
    input_file = $args["--input-file"]
    separator  = if $args["--separator"] == "TAB": "\t"
                 else: $args["--separator"]

    minlen = parseInt($args["--min-len"])
    maxlen = parseInt($args["--max-len"])

  # Check input file existence
  if not fileExists(input_file):
    stderr.writeLine("ERROR: Input file not found: ", input_file)
    return 1

  # Process file read by read
  try:
    for seqObject in readfq(input_file):
      # FASTX record attributes:
      # seqObject.name
      # seqObject.comment
      # seqObject.sequence
      # seqObject.quality
      let filtered = processRead(seqObject, minlen, maxlen)
      if len(filtered.sequence) > 0:
        echo filtered
  except Exception as e:
    stderr.writeLine("ERROR: Unable to parse FASTX file: ", input_file, "\n", e.msg)
    return 1
  

when isMainModule:
  # Handle "Ctrl+C" intterruption
  try:
    let exitStatus = main()
    quit(exitStatus)
  except EKeyboardInterrupt:
    # Ctrl+C
    quit(1)
  except IOError:
    # Broken pipe
    quit(0)
  except Exception:
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(2)   
