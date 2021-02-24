---
sort: 2
permalink: /usage
---
# Short guide

*SeqFu* is composed by a main program with multiple subprograms, and a set of utilities.
Check the complete documentation for each [tool]({{site.baseurl}}/tools), that contains the detailed
documentation.


## Main program

If invoked without parameters, *SeqFu* will print the list of subprograms:

```text
SeqFU - Sequence Fastx Utilities
version: 0.8.8

	• count [cnt]         : count FASTA/FASTQ reads, pair-end aware
	• deinterleave [dei]  : deinterleave FASTQ
	• derep [der]         : feature-rich dereplication of FASTA/FASTQ files
	• interleave [ilv]    : interleave FASTQ pair ends
	• sort [srt]          : sort sequences by size (uniques)
	• stats [st]          : statistics on sequence lengths

	• grep                : select sequences with patterns
	• head                : print first sequences
	• tail                : view last sequences
	• view                : view sequences with colored quality and oligo matches

Add --help after each command to print usage
```

## Subprograms

*SeqFu* is bundled with an (increasing) set of utilities sharing the FASTX parsing library:
* **fu-primers** to remove amplification primers from sequencing datasets
* **fu-orf** to extract ORFs from Paired-End libraries
* **fu-cov** to extract contigs from the most commonly used assembly programs using the coverage information printed in the headers
