import klib
import strformat
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
 

proc fastx_sort(argv: var seq[string]): int =
    let args = docopt("""
Usage: sort [options] [<inputfile> ...]

 Sort sequences by size printing only unique sequences

Options:
  -p, --prefix STRING    Sequence prefix 
  -s, --strip-comments   Remove sequence comments
  --asc                  Ascending order
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]
    stripComments = args["--strip-comments"]

    let
      ascending = args["--asc"]

    var
      files : seq[string]  
      prefix: string


    if args["--prefix"]:
      prefix = $args["--prefix"]

    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu sort] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)
    
    
    for filename in files:
      var 
        f = xopen[GzFile](filename)
        y = 0
        r: FastxRecord
        
      defer: f.close()
      var 
        c  = 0
        printed = 0
        seqTable = initTable[string, string]()
               
      while f.readFastx(r):
        
        seqTable[r.seq] = r.name

      var
        seqKeys  = toSeq(keys(seqTable))

      if ascending:
        sort(seqKeys, proc(a, b: string): int =
          if len(a) <= len(b): return -1
          else: return 1
        )
      else:
        sort(seqKeys, proc(a, b: string): int =
          if len(a) > len(b): return -1
          else: return 1
        )
  
      for s in seqKeys:
        c += 1
        var name = seqTable[s]
        if len(prefix) > 0:
          name = prefix & $c
        echo ">", name, "\n", s
