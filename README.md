<a href="https://telatin.github.io/seqfu2" description="SeqFu documentation">
<img align="right" width="128" height="128" src="docs/img/seqfu-512.png"></a>

# SeqFu

[![Build_Nim](https://img.shields.io/github/workflow/status/telatin/seqfu2/Build_Nim?label=SeqFu%20build)](https://github.com/telatin/seqfu2/actions/workflows/nimtest.yml)
![Last Commit](https://img.shields.io/github/last-commit/telatin/seqfu2)
[![Downloads](https://img.shields.io/conda/dn/bioconda/seqfu)](https://bioconda.github.io/recipes/seqfu/README.html)
[![Latest release](https://img.shields.io/github/v/release/telatin/seqfu2)](https://github.com/telatin/seqfu2/releases)

A general-purpose program to manipulate and parse information from FASTA/FASTQ files,
supporting gzipped input files.
Includes functions to *interleave* and *de-interleave* FASTQ files, to *rename*
sequences and to *count* and print *statistics* on sequence lengths.

---

## 📦 Installation

Seqfu can be easily installed via Miniconda:

```bash
conda install -y -c conda-forge -c bioconda "seqfu>1.10"
```

## 📰 Citation

Telatin A, Fariselli P, Birolo G.
*SeqFu: A Suite of Utilities for the Robust
and Reproducible Manipulation of Sequence Files*.
Bioengineering 2021, 8, 59. [doi.org/10.3390/bioengineering8050059](https://doi.org/10.3390/bioengineering8050059)

## 📙 Full documentation

 The full documentation is available at:
[**telatin.github.io/seqfu2**](https://telatin.github.io/seqfu2)

## Splash screen

```
SeqFu - Sequence Fastx Utilities
version: 1.10.0

  · count [cnt]         : count FASTA/FASTQ reads, pair-end aware
  · deinterleave [dei]  : deinterleave FASTQ
  · derep [der]         : feature-rich dereplication of FASTA/FASTQ files
  · interleave [ilv]    : interleave FASTQ pair ends
  · lanes [mrl]         : merge Illumina lanes
  · list [lst]          : print sequences from a list of names
  · metadata [met]      : print a table of FASTQ reads (mapping files)
  · rotate [rot]        : rotate a sequence with a new start position
  · sort [srt]          : sort sequences by size (uniques)
  · stats [st]          : statistics on sequence lengths

  · cat                 : concatenate FASTA/FASTQ files
  · grep                : select sequences with patterns
  · head                : print first sequences
  · rc                  : reverse complement strings or files
  · tab                 : tabulate reads to TSV (and viceversa)
  · tail                : view last sequences
  · view                : view sequences with colored quality and oligo matches

Type 'seqfu version' or 'seqfu cite' to print the version and paper, respectively.
Add --help after each command to print its usage.
```


![`seqfu`](docs/img/screenshot-seqfu.svg "SeqFu")