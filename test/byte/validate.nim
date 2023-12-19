import docopt
import os, strutils
import zip/gzipfiles
import strformat
import ../../src/seqfu_utils
proc version(): string =
    "1.0"


proc validateFastxFile(path: string, optOffset: int, optQualcheck: bool, optVerbose: bool): string =
    var
        fp: GzFileStream
        line: string
        lineCount = 0
        seqCount = 0
        seqLen = 0
        valid = true
        firstSeq = ""
        lastSeq = ""

    # Open the gzip file
    try:
        if path.len > 0 and fileExists(path):
            fp = newGzFileStream(path, fmRead)
            if optVerbose:
                echo "Opening file: ", path
    except IOError as e:
        echo "Error opening file: ", path, ": ", e.msg
        return "ERR\t0\t\t"

    # Process the FASTQ file
    while not fp.atEnd():
        line = fp.readLine()
        lineCount.inc()

        # Process the line based on its position in the 4-line sequence block
        case lineCount mod 4
            of 1:  # Header line
                if line[0] != '@':
                    valid = false
                    break
                if seqCount == 0:
                    firstSeq = line[1..^1]  # Store first sequence header (excluding '@')
                    lastSeq = line[1..^1]  # Store last sequence header (excluding '@')
                seqCount += 1

            of 2:  # Sequence line
                seqLen = line.len
                for ch in line.toUpperAscii:
                    if not (ch in {'A', 'C', 'G', 'T', 'N'}):
                        valid = false
                        break

            of 3:  # Plus line
                if line[0] != '+':
                    valid = false
                    break

            of 0:  # Quality line
                if seqLen != line.len:
                    valid = false
                    break
                if optQualcheck:
                    for qchar in line:
                        let qscore = ord(qchar) - optOffset
                        if qscore < 0 or qscore > 60:
                            valid = false
                            break
            of 4:
                continue
            else:
                continue

    # Close the file
    fp.close()

    # Construct the result string
    let status = if valid: "OK" else: "ERR"
    return fmt"{status}{'\t'}{seqCount}{'\t'}{firstSeq}{'\t'}{lastSeq}"

proc validateFastxMain(args: var seq[string]): int {.gcsafe.} =
  let args = docopt("""
  Usage:
    validate [options] <FASTX>...

  Validate one or more FASTA or FASTQ file for integrity

  Options:
    -q, --validate-quality     Check quality string
    -o, --quality-offset INT   Phred quality offset [default: 33]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=version(), argv=commandLineParams())

  #check parameters
  try:
    discard parseInt($args["--quality-offset"])
  except Exception as e:
    stderr.writeLine e.msg
    quit(1)
    
  let
    optOffset = parseInt($args["--quality-offset"])
    optQualcheck = bool(args["--validate-quality"])
    optVerbose   = bool(args["--verbose"])

  for filename in args["<FASTX>"]:
    echo validateFastxFile(filename, optOffset, optQualcheck, optVerbose)

when isMainModule:
  main_helper(validateFastxMain)


