# Package
version       = "1.6.3"
author        = "Andrea Telatin"
description   = "SeqFU command-line tools"
license       = "MIT"

# Dependencies
requires "nim >= 1.2", "docopt", "terminaltables", "readfq", "iterutils", "argparse",  "colorize", "neo", "zip"

srcDir = "src"
binDir = "bin" 
namedBin = {"sfu": "seqfu", "fu_cov": "fu-cov", "fu_primers": "fu-primers",
"fu_orf": "fu-orf",
"fu_tabcheck": "fu-tabcheck", 
"fu_shred": "fu-shred",
"fu_multirelabel": "fu-multirelabel", 
"fu_sw": "fu-sw", 
"fu_index": "fu-index", 
"fu_nanotags": "fu-nanotags",
"dadaist2_mergeseqs": "dadaist2-mergeseqs", 
"dadaist2_region": "fu-16Sregion"}.toTable()

 
