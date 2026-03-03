---
layout: default
title: fu-primers
parent: Utilities
---


# fu-primers

A program to remove primers from raw reads (FASTQ)
of amplicons, 
allowing IUPAC degenerate bases and checking for
multiple occurrences (dimers/concatamers).

```text
Usage: fu-primers [options] -1 <FOR> [-2 <REV>]

  Options:
    -1 --first-pair <FOR>     First sequence in pair
    -2 --second-pair <REV>    Second sequence in pair (can be guessed)
    -f --primer-for FOR       Sequence of the forward primer [default: CCTACGGGNGGCWGCAG]
    -r --primer-rev REV       Sequence of the reverse primer [default: GGACTACHVGGGTATCTAATCC]
    -m --min-len INT          Minimum sequence length after trimming [default: 50]
    --primer-thrs FLOAT       Minimum amount of matches over total length [default: 0.8]
    --primer-mismatches INT   Maximum number of mismatches allowed [default: 2]
    --primer-min-matches INT  Minimum number of matches required [default: 8]
    --primer-pos-margin INT   Number of bases from the extremity of the sequence allowed [default: 2]
    -t --threads INT          Number of worker threads [default: 8]
    -p --pool-size INT        Number of reads per worker batch [default: 100]
    --pattern-R1 <tag-1>      Tag in first pairs filenames [default: auto]
    --pattern-R2 <tag-2>      Tag in second pairs filenames [default: auto]
    -v --verbose              Verbose output
    -h --help                 Show this help
```

## Notes

- If `-2/--second-pair` is omitted, `fu-primers` tries to infer R2 from R1 (for example `_R1_`/`_R2_`, `_R1.`/`_R2.`, `_1.`/`_2.`).
- If mate inference fails, it processes input as single-end.
- If `-2` is explicitly provided and the file does not exist, it exits with an error.
- Output order is deterministic and multithreaded processing is performed in bounded-size batches.
