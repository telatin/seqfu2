---
sort: 4
permalink: /about
---

# About SeqFu

## Citing

Telatin A, Fariselli P, Birolo G. **SeqFu: A Suite of Utilities for the Robust and Reproducible Manipulation of Sequence Files**. Bioengineering 2021, 8, 59. 
[https://doi.org/10.3390/bioengineering8050059](doi.org/10.3390/bioengineering8050059)

## Why

There are several tools for the analysis of FASTQ/FASTA files.
My personal choice has been (and is) **[SeqKit](https://bioinf.shenwei.me/seqkit/)**,
a general purpose toolkit.

As many other bioinformaticians, I found myself coding small _ad hoc_ scripts, for example:
 * A tool to extract the _index_ from Illumina FASTQ files
(taking the most common occurrence from the first 1000 reads)
 * A tool to extract contigs using a list from a predictor
 * Scripts to interleave/deinterleave FASTQ files

The problem was distributing a very small script to users lacking the library I was using (like the excellent [pyfastx](https://pypi.org/project/pyfastx/) or our 
[FASTX::Reader](https://metacpan.org/release/FASTX-Reader)).

The possibility to distribute self-contained binaries was an option that was both
boosting the performance of the program, and solving the dependency hell for minor
applications.

This led to the start of the project.

## How

The main parsing library is `klib.nim` by Heng Li ([lh3/biofast](https://github.com/lh3/biofast)), that provides good performances.

For some utilities the *readfq* library has been used ([andreas-wilm/nimreadfq](https://github.com/andreas-wilm/nimreadfq)). This is based on the
C version of Heng Li's parsed, wrapped in an object oriented module.

## About the name

The names was modeled after "[ScriptFu](https://docs.gimp.org/en/gimp-concepts-script-fu.html)", a set of macros built in the image manipulation GIMP.
[Apparently](https://twitter.com/StevenSalzberg1/status/1439704488508526599?s=20), in the US this might sound offensive, so we after a consultation with Microsoft, offer a tool to rename the program to **SeqFlower**. It's called `flower.sh` in the _src_ directory.

![SeqFlower]({{site.baseurl}}/img/flowers.png)

### Perl module
A Perl version of the parser is available both from 
**[MetaCPAN](https://metacpan.org/release/FASTX-Reader)** and from Bioconda:

```
conda install -c bioconda perl-fastx-reader
```

### Templates

The repository contains some templates to quickly write
FASTX parser-based applications (in Nim or in Perl).

:package: [seqfu2/templates](https://github.com/telatin/seqfu2/tree/main/templates)
