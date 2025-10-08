---
layout: default
title: fu-primers
parent: Utilities
---


# fu-primers

A program to remove primers from the raw output (FASTQ)
of amplicons, 
allowing IUPAC degenerate bases and checking for
multiple occurrences (dimers/concatamers).

```text
Usage: fu-primers [options] -1 <FOR> [-2 <REV>]

  This program currently only supports paired-end Illumina reads.

  Options:
    -1 --first-pair <FOR>     First sequence in pair
    -2 --second-pair <REV>    Second sequence in pair (can be guessed)
    -f --primer-for FOR       Sequence of the forward primer [default: CCTACGGGNGGCWGCAG]
    -r --primer-rev REV       Sequence of the reverse primer [default: GGACTACHVGGGTATCTAATCC]
    -m --min-len INT          Minimum sequence length after trimming [default: 50]
    --primer-thrs FLOAT       Minimum amount of matches over total length [default: 0.8]
    --primer-mismatches INT   Maximum number of missmatches allowed [default: 2]
    --primer-min-matches INT  Minimum numer of matches required [default: 8]
    --primer-pos-margin INT   Number of bases from the extremity of the sequence allowed [default: 2]
    --pattern-R1 <tag-1>      Tag in first pairs filenames [default: auto]
    --pattern-R2 <tag-2>      Tag in second pairs filenames [default: auto]
    -v --verbose              Verbose output
    -h --help                 Show this help
```       