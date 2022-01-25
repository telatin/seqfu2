import os, streams 
import docopt
import zip/gzipfiles, strutils


const NimblePkgVersion {.strdefine.} = "undef"

# Convert a stream into an iterator of lines
proc linesIterator(stream: Stream): iterator(): string =
  result = iterator(): string =
    while not stream.atEnd:
      yield stream.readLine()

# Convert an iterator of strings into a seq of strings
# (contrived illustration of passing an iterator to a proc)
proc readAllLines(iter: iterator(): string): seq[string] =
  result = newSeq[string]()
  for line in iter():
    result.add(line)


proc main(): int =
  let args = docopt("""
  Usage: kraken-classified [options] <FILES>...
 
  Options:
    --char CHAR                Separator [default: C]
    --precision INT            Print percentages with this precision [default: 5]
    --progress INT             Show progress every N reads [default: 0]
  Other options:
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """, version=NimblePkgVersion, argv=commandLineParams())

  let
  #  countChar = $args["--char"][0]
    charString = $args["--char"]
    firstChar  = charString[0]
    precision = parseInt($args["--precision"])
    progressStep = parseInt($args["--progress"])

  if len(args["<FILES>"]) == 0:
    stderr.writeLine("No files specified")
    return 1

  for filename in args["<FILES>"]:
    if args["--verbose"]:
      stderr.writeLine("Processing file: " & filename)
    
        
    let stream: Stream =
        if filename[^3 .. ^1] == ".gz":
            newGZFileStream(filename)
        else:
            newFileStream(filename, fmRead)
    if stream == nil:
        echo "Unable to open file: " & filename
        quit(1)

    let lines = linesIterator(stream)

    var
        tot = 0
        classified = 0
    for line in lines():
        tot += 1
        if progressStep > 0 and tot mod progressStep == 0:
            let percent = 100.0 * float(classified / tot )
            stderr.writeLine("# ", classified, "/", tot, " classified: ", percent.formatFloat(ffDecimal, precision))
        if line[0] == firstChar:
            classified += 1 

    # Calculate percentage with 5 digits
    let
      percent_classified = 100.0 * float(classified / tot )
      percent_unclassified = 100.0 - percent_classified

    echo filename, "\t", classified, "\t", tot, "\t", percent_classified.formatFloat(ffDecimal, precision), "%\t", percent_unclassified.formatFloat(ffDecimal, precision)
    stream.close()

when isMainModule:
  discard main()
