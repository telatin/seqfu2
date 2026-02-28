---
layout: default
title: Usage Guide
nav_order: 4
permalink: /usage
---

# Short guide

*SeqFu* is composed by a main program with multiple subcommands, and a set of utilities.
Check the complete documentation for each [tool]({{site.baseurl}}/tools), that contains the detailed
documentation.

SeqFu has tools for:

* Make life easier when working from the command line
 (`seqfu head`, `seqfu tail`, `seqfu rc`...)
* Provide a visual feedback of datasets (like `seqfu view`)
* Get statistics (`seqfu count` and `seqfu stats`)
* Perform common operations with a reliable tool (`seqfu interleave`, `seqfu deinterleave`)
* Perform specialistic operations with added ease of use or features

## Main program

If invoked without parameters, *SeqFu* will print the list of subprograms:

```text
SeqFu - FASTX Tools

  · count [cnt]         : count FASTA/FASTQ reads, pair-end aware
  · deinterleave [dei]  : deinterleave FASTQ
  · derep [der]         : feature-rich dereplication of FASTA/FASTQ files
  · interleave [ilv]    : interleave FASTQ pair ends
  · lanes [mrl]         : merge Illumina lanes
  · metadata [met]      : print a table of FASTQ reads (mapping files)
  · orf                 : extract ORFs from nucleotide sequences
  · sort [srt]          : sort sequences by size (uniques)
  · stats [st]          : statistics on sequence lengths

  · cat                 : concatenate FASTA/FASTQ files
  · grep                : select sequences with patterns
  · head                : print first sequences
  · rc                  : reverse complement strings or files
  · tab                 : tabulate reads to TSV (and viceversa)
  · tabcheck            : validate TSV/CSV field consistency
  · tail                : view last sequences
  · view                : view sequences with colored quality and oligo matches

Type 'seqfu version' or 'seqfu cite' to print the version and paper, respectively.
Add --help after each command to print its usage.
```

## Core and Utilities

Preferred commands are exposed as `seqfu` subcommands (see **[Core Tools]({{site.baseurl}}/tools/)**), including:

* `seqfu orf` to extract ORFs from nucleotide reads/sequences
* `seqfu tabcheck` to validate TSV/CSV field consistency

Compatibility binaries are still shipped for existing pipelines:

* `fu-orf` (wrapper for `seqfu orf`)
* `fu-tabcheck` (wrapper for `seqfu tabcheck`)
* plus additional standalone utilities such as `fu-cov`, `fu-homocomp`, and others

See the **[full list of utilities]({{site.baseurl}}/utilities/)**.
