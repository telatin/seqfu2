import docopt
import readfq
import strformat
import os, strutils, sequtils
import tables
 
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programVersion = if NimblePkgVersion == "undef": "0.0.1-alpha"
                       else: NimblePkgVersion
let
  programName = "fu-shred"
 


 
proc isDNA(s: string): bool = 
  let ch = @['A', 'C', 'G', 'T', 'N']
  for c in s.toUpper():
    if c notin ch:
      return false
  return true
 
proc version(): string =
  return programName  & " " & programVersion
 

proc main(args: var seq[string]): int =
  let args = docopt("""
  Usage: fu-shred [options]  [<fastq-file>...]

  Systematically produce a "shotgun" of input sequences. Can read from standard input.

  Options:
    -l, --length INT           Segment length [default: 100]
    -s, --step INT             Distance from one segment start to the following [default: 10] 
    -q, --quality INT          Quality (constant) for the segment, if -1 is 
                               provided will be printed in FASTA [default: 40]
    -r, --add-rc               Print every other read in reverse complement
    -b, --basename             Prepend the file basename to the read name
    --split-basename STRING    Split the file basename at this character [default: .]
    --prefix-separator STRING  Join the basename with the rest of the read name with this [default: _]

    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

  #check parameters
  


  let
    readLength = parseInt($args["--length"])
    step = parseInt($args["--step"])
    quality = parseInt($args["--quality"])
    basename = args["--basename"]
    separator = $args["--split-basename"]
    joinString = $args["--prefix-separator"]
    doRevComp = args["--add-rc"]
    qualChar = if parseInt($args["--quality"]) > 0: qualToChar( parseInt($args["--quality"]))
               else: ' '

  var inputFiles = newSeq[string]()
  if len( @( args["<fastq-file>"]))  > 0:
    for f in args["<fastq-file>"]:
      if fileExists(f):
        inputFiles.add(f)
      else:
        stderr.writeLine("ERROR: Skipping file <", f, ">: not found.")
  else:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[fu-shred] Waiting for sequences from STDIN (Ctrl-C to quit)...")
      inputFiles.add("-")

  for inputFile in inputFiles:
    if not fileExists(inputFile) and inputFile != "-":
        stderr.writeLine("ERROR: Input file not found: ", inputFile)
        quit(1)
    try:
      for fqRecord in readfq(inputFile):
          var counter = 0
          let prefix = if basename: extractFilename(inputFile).split(separator)[0] & $args["--prefix-separator"]
                      else: ""
          for pos in countup(0, len(fqRecord.sequence) - readLength, step):
              counter += 1
              let slice = if counter mod 2 == 0: fqRecord.sequence[pos ..< pos+readLength]
                          else: revcompl(fqRecord.sequence[pos ..< pos+readLength])
              

              let readname = prefix  & fqRecord.name & joinString & $counter
              let read = if qualChar != ' ': FQRecord(name: readname, comment: "", sequence: slice, quality: repeat(qualChar, readLength ) )
                        else: FQRecord(name: readname, comment: "", sequence: slice )

              echo $read
    except Exception as e:
      stderr.writeLine("ERROR: parsing ", inputFile, ": ", e.msg)
      quit(1)
        



when isMainModule:
  main_helper(main)
