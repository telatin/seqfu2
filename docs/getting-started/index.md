---
title: Quick start
summary: Install SeqFu, run your first commands and learn where to look next.
redirect_from:
  - /usage.html
  - /usage
---

## Install

The recommended way to install SeqFu is from [Bioconda](https://anaconda.org/bioconda/seqfu), on Linux and macOS:

```bash
conda install -c conda-forge -c bioconda "seqfu>=1.30"
```

Other options (pre-compiled binaries, building from source) are described in
[Installation]({{ '/getting-started/installation.html' | relative_url }}).
Check that everything works with:

```bash
seqfu version
```

## First commands

SeqFu reads plain or gzipped FASTA and FASTQ files, and most commands behave like the
Unix tools you already know, but are aware of sequence records:

```bash
# How many reads? Paired files are detected and checked together
seqfu count reads_R1.fastq.gz reads_R2.fastq.gz

# Length statistics (N50, auN, min/max...) as a terminal table
seqfu stats -n assembly.fasta

# The first 5 records, or one every 100 reads
seqfu head -n 5 reads_R1.fastq.gz
seqfu head -n 5 --skip 100 reads_R1.fastq.gz

# Records containing a (degenerate) primer, on either strand
seqfu grep -o CCTACGGGNGGCWGCAG amplicons.fasta
```

Typing `seqfu` alone prints the list of subcommands, and every subcommand has its own
help, for example `seqfu stats --help`. `seqfu cite` prints the paper to cite.

## Core tools and utilities

SeqFu ships two kinds of programs:

* **Core tools** are subcommands of the main binary: `seqfu stats`, `seqfu grep`,
  `seqfu interleave`... Their command-line interface is covered by an extensive test
  suite, so options are stable across releases.
* **Utilities** are standalone programs, usually with an `fu-` prefix (`fu-cov`,
  `fu-primers`...). They cover more specialised tasks. A few of them are now
  compatibility wrappers for commands that moved into the core (`fu-orf` runs
  `seqfu orf`, for instance).

The [Tools catalogue]({{ '/tools/' | relative_url }}) lists both, and can be filtered by task,
input type and kind.

## Where next

* [Overview of the commands]({{ '/getting-started/overview.html' | relative_url }}): a guided tour, grouped by task
* [Common conventions]({{ '/getting-started/conventions.html' | relative_url }}): standard input, compressed files, paired-end naming
* [Recipes]({{ '/recipes/' | relative_url }}): short, end-to-end workflows
