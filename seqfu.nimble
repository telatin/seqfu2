# Package
version       = "0.8.13"
author        = "Andrea Telatin"
description   = "SeqFU command-line tools"
license       = "MIT"

# Dependencies
requires "nim >= 1.2", "docopt", "terminaltables", "readfq", "iterutils", "argparse",  "colorize", "neo"

srcDir = "src"
binDir = "bin" 
namedBin = {"sfu": "seqfu", "fu_cov": "fu-cov", "fu_primers": "fu-primers", "fu_orf": "fu-orf", 
"fu_multirelabel": "fu-multirelabel", "fu_sw": "fu-sw",
"dadaist2_mergeseqs": "dadaist2-mergeseqs", "dadaist2_region": "dadaist2-region"}.toTable()

task seqfu, "compile SeqFU":
  mkdir  "bin"
  exec "nim c -d:release  --opt:speed -p:src/lib/  --out:bin/seqfu src/sfu"
  exec "nim c -d:release  --opt:speed -p:src/lib/  --out:bin/fu-cov src/fu_cov"
  exec "nim c -d:release  --opt:speed -p:src/lib/ --threads:on --out:bin/fu-primers src/fu_primers"


task build, "build":
  exec "nim c -d:release  --opt:speed --threads:on src/fu_primers.nim"
  exec "nim c -d:release  --opt:speed --threads:on src/sfu.nim"
  exec "nim c -d:release  --opt:speed src/fu_cov"

