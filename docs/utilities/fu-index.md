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
  
    -m, --max-reads INT    Evaluate INT number of reads [default: 1000]
    -r, --min-ratio FLOAT  Minimum ratio of matches of the top index [default: 0.85]
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
* PASS/FAIL
  
```
data/illumina_1.fq.gz   TACGCTGC+CTATTAAG       1.00    PASS
data/illumina_2.fq.gz   TACGCTGC+CTATTAAG       1.00    PASS
```