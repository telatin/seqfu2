import docopt
import readfq
 
import os
import tables
import strutils
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
    -f, --frag-len INT         Total fragment length [default: 500]
    -o, --out-prefix STR       If specified, will run in paired end mode, and will output two files
                               with this prefix, one for each end. If not specified, will output
                               to STDOUT in single end mode.

    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

  #check parameters
  


  let
    outprefix = $args["--out-prefix"]
    readLength = parseInt($args["--length"])         
    fragLength = parseInt($args["--frag-len"])
    step = parseInt($args["--step"])
    basename = args["--basename"]
    separator = $args["--split-basename"]
    joinString = $args["--prefix-separator"]
    doRevComp = bool(args["--add-rc"])
    qualChar = if parseInt($args["--quality"]) > 0: qualToChar( parseInt($args["--quality"]))
               else: ' '

    pe = if outprefix != "nil": true
         else: false

    verbose = bool(args["--verbose"])
    cutLen = if pe: fragLength
             else: readLength

  var inputFiles = newSeq[string]()

  if fragLength <= readLength:
    stderr.writeLine("ERROR: Fragment length must be greater than read length.")
    quit(1)
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

  if verbose:
    stderr.writeLine("[fu-shred] Read length: ", readLength)
    stderr.writeLine("[fu-shred] Step: ", step, if doRevComp: " (with reverse complement)" else: "")
    if pe:
      stderr.writeLine("[fu-shred] Fragment length: ", fragLength)
      stderr.writeLine("[fu-shred] Output prefix: ", outprefix)

  var
    fwdFile = if pe: open(outprefix & "_R1.fq", fmWrite)
             else: stdout
    revFile = if pe: open(outprefix & "_R2.fq", fmWrite)
             else: stdout
        
  defer: fwdFile.close()
  defer: revFile.close()
  
  for inputFile in inputFiles:
    if not fileExists(inputFile) and inputFile != "-":
        stderr.writeLine("ERROR: Input file not found: ", inputFile)
        quit(1)

    if verbose:
      stderr.writeLine("[fu-shred] Processing file: ", inputFile, if pe: " (paired end)" else: "(single end)")
    try:
      for fqRecord in readfq(inputFile):
          var counter = 0
          let prefix = if basename: extractFilename(inputFile).split(separator)[0] & $args["--prefix-separator"]
                      else: ""
          for pos in countup(0, len(fqRecord.sequence) - cutLen, step):
              counter += 1
              let slice = if counter mod 2 == 0 or not doRevComp: fqRecord.sequence[pos ..< pos+cutLen]
                          else: revcompl(fqRecord.sequence[pos ..< pos+cutLen])
              

              let readname = prefix  & fqRecord.name & joinString & $counter


              if pe:
                let r1 = if qualChar != ' ': FQRecord(name: readname, 
                                        comment: "", 
                                        sequence: slice[0 ..< readLength], 
                                        quality: repeat(qualChar, readLength ) )
                            else: FQRecord(name: readname, 
                                      comment: "", 
                                      sequence: slice )
                let r2 = if qualChar != ' ': FQRecord(name: readname, 
                                        comment: "", 
                                        sequence: revcompl(slice)[0 ..< readLength], 
                                        quality: repeat(qualChar, readLength ) )
                            else: FQRecord(name: readname, 
                                      comment: "", 
                                      sequence: slice )
                fwdFile.writeLine($r1)
                revFile.writeLine($r2)
              else:
                let read = if qualChar != ' ': FQRecord(name: readname, 
                                        comment: "", 
                                        sequence: slice, 
                                        quality: repeat(qualChar, readLength ) )
                            else: FQRecord(name: readname, 
                                      comment: "", 
                                      sequence: slice )
                echo $read
    except Exception as e:
      stderr.writeLine("ERROR: parsing ", inputFile, ": ", e.msg)
      quit(1)
        



when isMainModule:
  main_helper(main)
