import docopt
import readfx
import os
import klib

proc main(): int =
  let args = docopt("""
  Usage: 
    v2 [args] <FILES>...

   FILES      list of files to process

  """, version="1.0", argv=commandLineParams())

  for file in args["<FILES>"]:
    if not fileExists(file):
      echo "File not found: ", file


    var
        c = 0
        totlen = 0
    for read in readfq(file):
      c += 1
      totlen += len(read.sequence)
    echo file, "\t", $c, "\t", $totlen

    var R1 = xopen[GzFile](file)
    defer: R1.close()
    var read1: FastxRecord

    c = 0
    totlen = 0
    while R1.readFastx(read1):
      c += 1
      totlen += len(read1.seq)
    echo file, "\t", $c, "\t", $totlen

when isMainModule:
  discard main()