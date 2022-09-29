# Package
version       = "1.16.0"
author        = "Andrea Telatin"
description   = "SeqFu command-line tools"
license       = "MIT"

# Dependencies
requires "nim >= 1.2", "docopt", "terminaltables", "readfq", "iterutils", "argparse",  "colorize", "neo", "zip", "datamancer", "illwill#v0.2.0"

srcDir = "src"
binDir = "bin" 
namedBin = {
    "sfu": "seqfu", 
    "fu_cov": "fu-cov", 
    "fu_primers": "fu-primers",
    "fu_orf": "fu-orf",
    "fu_tabcheck": "fu-tabcheck", 
    "fu_shred": "fu-shred",
    "fu_multirelabel": "fu-multirelabel", 
    "fu_sw": "fu-sw", 
    "fu_index": "fu-index", 
    "fu_nanotags": "fu-nanotags",
    "dadaist2_mergeseqs": "dadaist2-mergeseqs", 
    "dadaist2_region": "fu-16Sregion",
    "fu_homocomp": "fu-homocomp",
    "fu_virfilter": "fu-virfilter",
    "fu_msa": "fu-msa"
}.toTable()

 
