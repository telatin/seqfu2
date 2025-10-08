---
layout: default
title: seqfu sort
parent: Core Tools
---


# seqfu sort

*sort*  is one of the core subprograms of *SeqFu*, that allows 
sorting a FASTA/FASTQ file by sequence size.

```text
Usage: sort [options] [<inputfile> ...]

 Sort sequences by size printing only unique sequences

Options:
  -p, --prefix STRING    Sequence prefix 
  -s, --strip-comments   Remove sequence comments
  --asc                  Ascending order
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

## Screenshot

![Screenshot of "seqfu sort"]({{site.baseurl}}/img/screenshot-sort.svg "SeqFu sort")