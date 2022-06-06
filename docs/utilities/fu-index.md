---
sort: 9
---

# fu-index

Extracts the index (barcode) from Illumina demultiplexed files.

```text
Fastx utility

  A program to print the Illumina INDEX of a set of FASTQ files

  Usage: 
  fu-index [options] <FASTQ>...

  Options:
  
    -m, --max-reads INT    Evaluate INT number of reads, 0 for unlimited [default: 8000]
    -r, --min-ratio FLOAT  Minimum ratio of matches of the top index [default: 0.90]
    -h, --header           Add header to output
    --verbose              Print verbose log
    --help                 Show help
```

## Input files

FASTQ files demultiplexed by CASAVA (Illumina).

## Example output

A tabular output contains:

* filename
* extracted tag
* fraction of the top tag (accounts for errors)
* PASS ("PASS" or "--") if the top tags is >= min-ratio
* Instrument code (from 1.12)
* Run number (from 1.12)
* Flowcell ID (from 1.12)
  
```
data/illumina_1.fq.gz   TACGCTGC+CTATTAAG       1.00    PASS    A00709  43      HYG25DSXX
data/illumina_2.fq.gz   TACGCTGC+CTATTAAG       1.00    PASS    A00709  43      HYG25DSXX
```