import readfq
import docopt
import os
import posix
signal(SIG_PIPE, SIG_IGN)

let version = "1.0"

# Handle Ctrl+C interruptions and pipe breaks
type EKeyboardInterrupt = object of CatchableError
proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
setControlCHook(handler)

proc main(): int =
  let args = docopt("""
  Fastx utility

  A program to print the sequence size of each record in a FASTA/FASTQ file

  Usage: 
  fastx_utility [options] -i Input_File 

  Options:
    -i, --input-file FILE      FASTA or FASTQ file
    -s, --separator STRING     Separator between sequence name and size [default: TAB]
  
  """, version=version, argv=commandLineParams())

  
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  let
    input_file = $args["--input-file"]
    separator  = if $args["--separator"] == "TAB": "\t"
                 else: $args["--separator"]

  # Check input file existence
  if not fileExists(input_file):
    stderr.writeLine("ERROR: Input file not found: ", input_file)
    return 1

  # Process file read by read
  for seqObject in readfq(input_file):
    # FASTX record attributes:
    # seqObject.name
    # seqObject.comment
    # seqObject.sequence
    # seqObject.quality
    stdout.writeLine(seqObject.name, separator, len(seqObject.sequence))
  

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
