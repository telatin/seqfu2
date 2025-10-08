---
layout: default
title: fu-cov
parent: Utilities
---


# fu-cov

A program to filter the output of assembly programs using the
coverage information they print
in the sequence names.

```text
Extract contig by sequence length and coverage, if provided in the sequence name.

Usage:
  fu-cov [options] [inputfile ...]

Arguments:
  [inputfile ...]

Options:
  -h, --help
  -v, --verbose              Print verbose messages
  -s, --sort                 Store contigs in memory, and sort them by descending coverage
  -c, --min-cov=MIN_COV      Minimum coverage (default: 0.0)
  -l, --min-len=MIN_LEN      Minimum length (default: 0)
  -x, --max-cov=MAX_COV      Maximum coverage (default: 0.0)
  -y, --max-len=MAX_LEN      Maximum length (default: 0)
  -t, --top=TOP              Print the first TOP sequences (passing filters) when using --sort (default: 10)

```

## Input

The FASTA output of an assembly program (currently tested with SPAdes, MegaHit, Unicycler, Shovill),
as the _length_ of the sequences is clearly checked from the FASTA file itself, while the coverage
is found in the sequence description:

Example of contig name from _Shovill_:

```
>contig00001 len=596929 cov=9.9 corr=0 origname=NODE_1_length_596929_cov_9.873201_pilon sw=shovill-spades/1.0.4 date=20181128
ACCCGGTAGAATACCGGACTGAGTATCAAAAAGCCGGTTAACTGAAACTGTCCAGGTTTTGGGGTTCAGTTCATGCCGCATCTTATCCGACCTTGTATTATCCCTCCAGTGCAGAGAAAATC
...
```

## Output

A set of filtered contigs in FASTA file.
Will print to STDERR a summary like:

````
1/1 sequences printed (1 with coverage info) from 1 files.
Skipped:          0 too short, 0 too long, then 0 low coverage, 0 high coverage, .
Average length:   180.00 bp, [180.0 - 180.0]
Average coverage: 9.90X, [9.9-9.9]
```