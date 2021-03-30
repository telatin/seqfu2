---
sort: 4
---

# Core Tools

Each of the following tools can be invoked as a subcommand of *SeqFu*.

Invoking `seqfu` will display a list of internal commands:

```text
SeqFU - Sequence Fastx Utilities
version: 0.8.12

        • count [cnt]         : count FASTA/FASTQ reads, pair-end aware
        • deinterleave [dei]  : deinterleave FASTQ
        • derep [der]         : feature-rich dereplication of FASTA/FASTQ files
        • interleave [ilv]    : interleave FASTQ pair ends
        • merge [mrg]         : merge Illumina lanes
        • sort [srt]          : sort sequences by size (uniques)
        • stats [st]          : statistics on sequence lengths

        • grep                : select sequences with patterns
        • head                : print first sequences
        • rc                  : reverse complement strings or files
        • tail                : view last sequences
        • view                : view sequences with colored quality and oligo matches

Add --help after each command to print usage
```


### Manual pages

{% include list.liquid %}
