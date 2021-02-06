# Package
version = "0.8.4"
author        = "Andrea Telatin"
description   = "SeqFU command-line tools"
license       = "MIT"

# Dependencies
requires "nim >= 1.2", "docopt", "terminaltables", "readfq", "iterutils"

srcDir = "src"
binDir = "bin"
bin = @["fu_cov"]

task seqfu, "compile SeqFU":
  mkdir  "bin"
  exec "nim c -d:release  --opt:speed -p:src/lib/ --out:bin/seqfu src/sfu"
  exec "nim c -d:release  --opt:speed -p:src/lib/ --out.bin/fu-cov src/fu_cov"
  exec "nim c -d:release  --opt:speed --threads:on --out.bin/fu-primers src/fu_primers"

task makedebug, "compile SeqFU":
  mkdir  "bin"
  exec "nimble c -p:src/lib/ --out:bin/seqfu_debug src/sfu"

task build, "build":
  exec "nim c --threads:on src/fu_primers.nim"
