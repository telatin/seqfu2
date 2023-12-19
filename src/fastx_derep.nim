import klib
import re
import md5
import json
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils

#[ 
proc seqFuEventHandler() {.noconv.} =
  stderr.writeLine("Quitting...")
  quit 0
setControlCHook(seqFuEventHandler)

 ]#

proc fastx_derep(argv: var seq[string]): int =
    
    let args = docopt("""
Usage: derep [options] [<inputfile> ...]

Options:
  -k, --keep-name              Do not rename sequence (see -p), but use the first sequence name
  -i, --ignore-size            Do not count 'size=INT;' annotations (they will be stripped in any case)
  -m, --min-size=MIN_SIZE      Print clusters with size equal or bigger than INT sequences [default: 0]
  -p, --prefix=PREFIX          Sequence name prefix [default: seq]
  -5, --md5                    Use MD5 as sequence name (overrides other parameters)
  -j, --json=JSON_FILE         Save dereplication metadata to JSON file
  -s, --separator=SEPARATOR    Sequence name separator [default: .]
  -w, --line-width=LINE_WIDTH  FASTA line width (0: unlimited) [default: 0]
  -l, --min-length=MIN_LENGTH  Discard sequences shorter than MIN_LEN [default: 0]
  -x, --max-length=MAX_LENGTH  Discard sequences longer than MAX_LEN [default: 0]
  -c, --size-as-comment        Print cluster size as comment, not in sequence name
  --add-len                    Add length to sequence
  -v, --verbose                Print verbose messages
  -h, --help                   Show this help

  
  """, version=version(), argv=argv)

  

    let 
      sizePattern = re";?size=(\d+);?"
      sizeCapture = re".*;?size=(\d+);?.*"
      addLength = args["--add-len"]
      useHash   = args["--md5"]
      useJson   = if $args["--json"] == "nil" : false 
                  else: true
      jsonFile  = if $args["--json"] == "nil" : "" 
                  else: $args["--json"]
      lineWidth = parseInt($args["--line-width"])



    var size_separator = if args["--size-as-comment"] or useHash : " " 
               else: ";"
    var 
      keepName = if args["--keep-name"]: true
                  else: false
      seqFreqs = initCountTable[string]()
      seqNames = initTable[string, string]()
      #seqFiles = initTable[string, seq[string]]()
      seqFiles  = newTable[string, TableRef[string, seq[string]]]()
      files    : seq[string]
      total    = 0
 
        
    if useHash:
      keepName = true
    
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu derep] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)


    for filename in files:      
      if filename != "-" and not fileExists(filename):
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
        r.seq = toUpperAscii(r.seq)

        # Discard short and long sequences
        if $args["--min-length"] != "0" and len(r.seq) < parseInt($args["--min-length"]):
          continue
        if $args["--max-length"] != "0" and len(r.seq) > parseInt($args["--max-length"]):
          continue
        


        # New sequence?
        if seqFreqs[r.seq] == 0:
          if keepName:
            seqNames[r.seq] = (r.name).replace(sizePattern, "")
          
          if useHash:
            seqNames[r.seq] = getMD5(r.seq)
          
          if useJson:
            if getMD5(r.seq) notin seqFiles:
              seqFiles[ getMD5(r.seq) ] = newTable[string, seq[string]]()
            if filename in seqFiles[ getMD5(r.seq) ]:
              seqFiles[ getMD5(r.seq) ][filename].add(r.name)
            else:
              seqFiles[ getMD5(r.seq) ][filename] = @[r.name]
          
        else:
          if useJson:
            if getMD5(r.seq) notin seqFiles:
              seqFiles[ getMD5(r.seq) ] = newTable[string, seq[string]]()
            if filename in seqFiles[ getMD5(r.seq) ]:
              seqFiles[ getMD5(r.seq) ][filename].add(r.name)
            else:
              seqFiles[ getMD5(r.seq) ][filename] = @[r.name]

        # Json metadata
        #if useJson:
        #  echo "OK"
      
        # Calculate size
        if not args["--ignore-size"]:
          # consider size=XX as count (otherwise: 1)
          if match(r.name, sizeCapture, match):
            seqFreqs.inc(r.seq, parseInt(match[0]))
          elif match(r.comment, sizeCapture, match):
            seqFreqs.inc(r.seq, parseInt(match[0]))
          else:
            seqFreqs.inc(r.seq)
        else:
          seqFreqs.inc(r.seq)

      # Current file parsed
      total += c
      echoVerbose("\tParsed " & $(c) & " sequences", args["--verbose"])

    # All files parsed
    var n = 0
    seqFreqs.sort()

    for repSeq, clusterSize in seqFreqs:
      n += 1
      # Generate name
      var name: string
      if keepName:
        name = seqNames[repSeq]
      else:
        name = $args["--prefix"] & $args["--separator"] & $(n)

      if clusterSize < parseInt($args["--min-size"]):
        let  missing = seqFreqs.len - (n - 1)
        stderr.writeLine("Skipped ", missing, " clusters having less than " , args["--min-size"] ," sequences.")
        quit(0)
      name.add(size_separator & "size=" & $(clusterSize) )

      if addLength:
        name.add(";len=" & $len(repSeq))
      echo ">", name,  "\n", format_dna(repSeq, lineWidth)

    echoVerbose($(n) & " representative sequences out of " & $(total) & " initial sequences.", args["--verbose"])
    
    #echo pretty(%*seqFiles)
    if useJson:
      try:
        writeFile(jsonFile, pretty(%*seqFiles))
      except Exception as e:
        stderr.writeLine("ERROR: ", e.msg, "\n", "Unable to write JSON to ", jsonFile, " (dumping here):\n")
        stderr.writeLine( pretty(%*seqFiles))