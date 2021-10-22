---
sort: 3
permalink: /usage
---
# Short guide

*SeqFu* is composed by a main program with multiple subprograms, and a set of utilities.
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
SeqFu - Sequence Fastx Utilities
version: {VERSION}

  · count [cnt]         : count FASTA/FASTQ reads, pair-end aware
  · deinterleave [dei]  : deinterleave FASTQ
  · derep [der]         : feature-rich dereplication of FASTA/FASTQ files
  · interleave [ilv]    : interleave FASTQ pair ends
  · lanes [mrl]         : merge Illumina lanes
  · list [lst]          : print sequences from a list of names
  · metadata [met]      : print a table of FASTQ reads (mapping files)
  · sort [srt]          : sort sequences by size (uniques)
  · stats [st]          : statistics on sequence lengths

  · cat                 : concatenate FASTA/FASTQ files
  · grep                : select sequences with patterns
  · head                : print first sequences
  · rc                  : reverse complement strings or files
  · tab                 : tabulate reads to TSV (and viceversa)
  · tail                : view last sequences
  · view                : view sequences with colored quality and oligo matches

Add --help after each command to print usage

```

## Subprograms

*SeqFu* is bundled with an (increasing) set of utilities sharing the FASTX parsing library:

* **fu-orf** to extract ORFs from Paired-End libraries
* **fu-cov** to extract contigs from the most commonly used assembly programs using the coverage information printed in the headers
* **fu-homocomp** to compress homopolymers (e.g. for Nanopore applications)
* ...
* See the **[full list](https://telatin.github.io/seqfu2/utilities/)**.
