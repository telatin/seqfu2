---
layout: default
title: Core Tools
nav_order: 4
has_children: true
---

# Core Tools

Each of the following tools can be invoked as a subcommand of *SeqFu*.

Invoking `seqfu` will display a list of internal commands:

```text
SeqFu - Sequence Fastx Utilities

        • bases               : count bases in FASTA/FASTQ files
        • cat                 : concatenate FASTA/FASTQ files
        • check               : check FASTQ file for errors
        • count [cnt]         : count FASTA/FASTQ reads, pair-end aware
        • deinterleave [dei]  : deinterleave FASTQ
        • derep [der]         : feature-rich dereplication of FASTA/FASTQ files
        • grep                : select sequences with patterns
        • head                : print first sequences
        • interleave [ilv]    : interleave FASTQ pair ends
        • lanes [mrl]         : merge Illumina lanes
        • less                : interactive viewer for sequences
        • list [lst]          : print sequences from a list of names
        • metadata [met]      : print a table of FASTQ reads (mapping files)
        • orf                 : extract ORFs from nucleotide sequences
        • qual                : inspect quality scores
        • rc                  : reverse complement strings or files
        • rotate [rot]        : rotate a sequence with a new start position
        • sort [srt]          : sort sequences by size (uniques)
        • stats [st]          : statistics on sequence lengths
        • tabcheck            : validate TSV/CSV field consistency
        • tabulate [tab]      : tabulate reads to TSV (and viceversa)
        • tail                : view last sequences
        • tofasta             : convert multiple formats to FASTA
        • trim                : trim FASTQ sequences based on quality
        • view                : view sequences with colored quality and oligo matches

Add --help after each command to print usage.
```


### Manual pages
