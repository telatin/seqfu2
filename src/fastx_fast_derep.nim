import klib
import re
import tables, strutils
import docopt
import ./seqfu_utils
from os import fileExists

proc fastx_fast_derep(argv: var seq[string]): int =
    
    let args = docopt("""
Usage: derep [options] [<inputfile> ...]

Options:
  -k, --keep-name              Do not rename sequence, but use the first sequence name
  -m, --min-size=MIN_SIZE      Print clusters with size equal or bigger than INT sequences [default: 0]
  -p, --prefix=PREFIX          Sequence name prefix [default: seq]
  -s, --separator=SEPARATOR    Sequence name separator [default: .]
  -w, --line-width=LINE_WIDTH  FASTA line width (0: unlimited) [default: 0]
  -c, --size-as-comment        Print cluster size as comment, not in sequence name
  -u, --to-uppercase           Convert all sequences to uppercase
  -v, --verbose                Print verbose messages
  -h, --help                   Show this help

  """, version=version(), argv=argv)

    let 
      lineWidth   = parseInt($args["--line-width"])
      toUpper     = args["--to-uppercase"]

    var
      keepName = if args["--keep-name"]: true
                  else: false
      size_separator = if args["--size-as-comment"] : " " 
               else: ";"
      seqFreqs = initCountTable[string]()
      seqNames = initTable[string, string]()
      files    : seq[string]
      total    = 0
 
        
    if args["<inputfile>"].len() == 0:
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)


    for filename in files:      
      if filename != "-" and not existsFile(filename):
        echo "FATAL ERROR: File ", filename, " not found."
        quit(1)


      var f = xopen[GzFile](filename)
      defer: f.close()
      var r: FastxRecord
      echoVerbose("Reading " & filename, args["--verbose"])

      # Prse FASTX
      var match: array[1, string]
      var c = 0

      while f.readFastx(r):
        c+=1

        # Always consider uppercase sequences
        if toUpper == true:
          r.seq = toUpperAscii(r.seq)
        
        # Store first name in seqNames
        if keepName:
          var seqname = r.name
          if seqFreqs[r.seq] == 0:
            seqNames[r.seq] = seqname
      
        seqFreqs.inc(r.seq)

      total += c
      echoVerbose("\tParsed " & $(c) & " sequences", args["--verbose"])

    
    var n = 0
    #seqFreqs.sort()

    for repSeq, clusterSize in seqFreqs:
      n += 1
      # Generate name
      var name: string
      if keepName:
        name = seqNames[repSeq]
      else:
        name = $args["--prefix"] & $args["--separator"] & $(n)

      if clusterSize >= parseInt($args["--min-size"]):
        name.add(size_separator & "size=" & $(clusterSize) )
        echo ">", name,  "\n", format_dna(repSeq, lineWidth)

    echoVerbose($(n) & " representative sequences out of " & $(total) & " initial sequences.", args["--verbose"])

