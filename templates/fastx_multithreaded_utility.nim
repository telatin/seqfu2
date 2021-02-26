import readfq
import docopt
import os
import posix
import threadpool
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
  

# We store the options in a single object to be easilyu passed to the threads
type
  programOptions = tuple
    minlen, maxlen: int

proc processRead(s: FQRecord, o: programOptions): FQRecord = 
  result.sequence = ""
  result.quality  = ""
  result.name     = ""
  # Core procedure to "manipulate" a single sequence
  if (len(s.sequence) < o.minlen) or (o.maxlen > 0 and len(s.sequence) > o.maxlen):    
    return
  else:
    return s

proc processReadPool(pool: seq[FQRecord], o: programOptions): string =
  # Receive a set of sequences to be processed and returns them as string to be printed
  for s in pool:
    let modifiedSeq = processRead(s, o)
    if len(modifiedSeq.sequence) > 0:
      result &= $modifiedSeq & "\n"

proc main(): int =
  let args = docopt("""
  Fastx utility

  A program to print the sequence size of each record in a FASTA/FASTQ file

  Usage: 
  fastx_utility [options] -i Input_File 

  Options:
    -i, --input-file FILE  Input FASTA/FASTQ file
    -m, --min-len INT      Minimum sequence length [default: 10]
    -x, --max-len INT      Discard sequences longer than this, 0 for unlimited [default: 0]
    -p, --pool-size INT    Number of sequences per processing thread [default: 2000]
    --verbose              Print verbose log
    --help                 Show help
  """, version=version, argv=commandLineParams())

  if args["--verbose"]:
    echo $args
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  let
    input_file = $args["--input-file"]
    poolSize = parseInt($args["--pool-size"])
  
  var
    opts : programOptions 

  try:
    opts = programOptions (minlen: parseInt($args["--min-len"]), maxlen: parseInt($args["--max-len"]) )
  except Exception:
    stderr.writeLine("Error parsing options. See --help for manual.")
    quit(1)

  # Check input file existence
  if not fileExists(input_file):
    stderr.writeLine("ERROR: Input file not found: ", input_file)
    return 1

  var readspool : seq[FQRecord]
  var responses = newSeq[FlowVar[string]]()
  var seqCounter = 0
  # Prepare the 
  # Process file read by read
  try:
    for seqObject in readfq(input_file):
      # FASTX record attributes:
      # seqObject.name
      # seqObject.comment
      # seqObject.sequence
      # seqObject.quality
      seqCounter += 1
      readspool.add(seqObject)

      if seqCounter mod poolSize == 0:
        responses.add(spawn processReadPool(readspool, opts))
        readspool.setLen(0)
    
    # Process last batch
    responses.add(spawn processReadPool(readspool, opts))

    var
      poolsCount = 0
    for resp in responses:
      poolsCount += 1
      echo ^resp
    
    if args["--verbose"]:
      stderr.writeLine(seqCounter, " sequences processed by ", poolsCount, " threads.")
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
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(1)
  except IOError:
    # Broken pipe
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(0)
  except Exception:
    stderr.writeLine( getCurrentExceptionMsg() )
    quit(2)   
