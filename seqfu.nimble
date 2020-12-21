# Package
version = "0.8.4"
author        = "Andrea Telatin"
description   = "SeqFU command-line tools"
license       = "MIT"

# Dependencies
requires "nim >= 1.2", "docopt", "terminaltables"

srcDir = "src"
bin = @["seqfu"]

task seqfu, "compile SeqFU":
  mkdir  "bin"
  exec "nimble c -d:release  --opt:speed -p:src/lib/ --out:bin/seqfu src/sfu"

task makedebug, "compile SeqFU":
  mkdir  "bin"
  exec "nimble c -p:src/lib/ --out:bin/seqfu_debug src/sfu"
