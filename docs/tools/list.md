---
layout: default
title: seqfu list
parent: Core Tools
---


# seqfu list

Extract sequences from sequence files using a list of requested items.
Introduced in **SeqFu 1.8**.

```text
Usage: list [options] <LIST> <FASTQ>...

Print sequences that are present in a list file.
Duplicated entries in the list will be ignored

Other options:
  -c, --with-comments    Include comments in the list file
  -p, --partial-match    Allow partial matches (UNSUPPORTED)
  -m, --min-len INT      Skip entries smaller than INT [default: 1]

  -v, --verbose          Verbose output
  -r, --report           Print report of found sequences
  --help                 Show this help
```


## Input

The **list** file is a simple text file with sequence names, 
that can contain the comments and
they can have a leading `>` or `@` characters 
(which would be discarded).

By default, if comments are present in the list they are ignored
and the match is only at the sequence name level, unless
the `--with-comments` option is used.

## Output

The standard output is in the same format as the input files,
either FASTA or FASTQ.

With `--report` the full input list is printed with the total
number of sequences printed.

Example report:

```
# SEQUENCES REPORT
# Sequence 'protein.1c;size=5372' found 1 times
# Sequence 'protein.1d;size=5372' found 1 times
# Sequence 'protein.missing' found 0 times
# Sequence 'protein.1a;size=5372' found 1 times
# Sequence 'protein.1f;size=5372' found 1 times
# Sequence 'protein.notfound' found 0 times
# Sequence 'protein.1b;size=5372' found 1 times
Total sequences found: 5/7
```