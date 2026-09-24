# Package
version = "1.30.0"
author = "Andrea Telatin"
description = "SeqFu command-line tools"
license = "GPL-3.0-only"

srcDir = "src"
binDir = "bin"

# Dependencies
requires "nim >= 2.2.0"
requires "argparse"
requires "checksums"
requires "colorize"
requires "docopt == 0.7.1"
requires "gzfast >= 0.2.2"
requires "illwill == 0.2.0"
requires "iterutils"
requires "malebolgia >= 1.3.2"
requires "readfx >= 0.8.0"
requires "regex >= 0.23"
requires "kexpr >= 0.0.2"
requires "tableview >= 0.6.0"
requires "terminaltables"
requires "zip"

# Binaries
namedBin = {
  "sfu": "seqfu",
  "dadaist2_mergeseqs": "dadaist2-mergeseqs",
  "dadaist2_region": "fu-16Sregion",
  "fu_cov": "fu-cov",
  "fu_index": "fu-index",
  "fu_msa": "fu-msa",
  "fu_multirelabel": "fu-multirelabel",
  "fu_nanotags": "fu-nanotags",
  "fu_orf": "fu-orf",
  "fu_primers": "fu-primers",
  "fu_shred": "fu-shred",
  "fu_sw": "fu-sw",
  "fu_tabcheck": "fu-tabcheck",
  "fu_virfilter": "fu-virfilter"
}.toTable()
