---
layout: default
title: Core Tools
nav_order: 5
has_children: true
---

# Core Tools

Each of the following tools can be invoked as a subcommand of *SeqFu*.

Invoking `seqfu` will display a list of internal commands:

```text
      ____             _____      
     / ___|  ___  __ _|  ___|   _ 
     \___ \ / _ \/ _` | |_ | | | |
      ___) |  __/ (_| |  _|| |_| |
     |____/ \___|\__, |_|   \__,_|
                    |_|           
  · amplicheck          : QC single- or paired-end amplicon FASTQ files
  · bases               : count bases in FASTA/FASTQ files
  · check               : check FASTQ file for errors
  · count [c]           : count FASTA/FASTQ reads, pair-end aware
  · deinterleave [dei]  : deinterleave FASTQ
  · derep [der]         : feature-rich dereplication of FASTA/FASTQ files
  · homocomp            : collapse homopolymer runs in FASTA/FASTQ records
  · interleave [ilv]    : interleave FASTQ pair ends
  · lanes [ill]         : merge Illumina lanes
  · list [lst]          : print sequences from a list of names
  · merge [mrg]         : merge paired-end FASTQ reads
  · metadata [met]      : print a table of FASTQ reads (mapping files)
  · msa                 : interactive multiple sequence alignment viewer
  · orf                 : extract ORFs from nucleotide sequences
  · rotate [rot]        : rotate a sequence with a new start position
  · shred               : systematically shred sequences into reads
  · sort [srt]          : sort sequences by size (uniques)
  · stats [st]          : statistics on sequence lengths
  · subtract            : print sequences in <file1> absent from <file2>
  · tofasta             : convert multiple formats to FASTA
  · trim                : trim FASTQ sequences based on quality

  · cat                 : concatenate FASTA/FASTQ files
  · grep                : select sequences with patterns
  · by-id               : select sequences by identifier
  · head                : print first sequences
  · less                : interactive viewer for sequences (like less)
  · rc                  : reverse complement strings or files
  · tab                 : tabulate reads to TSV (and viceversa)
  · tabcheck            : validate TSV/CSV field consistency
  · tail                : view last sequences
  · view                : view sequences with colored quality and oligo matches

Type 'seqfu version' or 'seqfu cite' to print the version and paper, respectively.
Add --help after each command to print its usage.
```


### Manual pages
