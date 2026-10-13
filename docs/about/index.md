---
title: About SeqFu
summary: Why SeqFu exists, how it is built, and how to cite it.
redirect_from:
  - /about
  - /notes.html
---

## Citing

Telatin A, Fariselli P, Birolo G.
**SeqFu: A Suite of Utilities for the Robust and
Reproducible Manipulation of Sequence Files**.
Bioengineering 2021, 8, 59.
[doi.org/10.3390/bioengineering8050059](https://doi.org/10.3390/bioengineering8050059)

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

SeqFu is written in [Nim](https://nim-lang.org), which compiles to fast, dependency-free
binaries. FASTA/FASTQ parsing is provided by [readfx](https://github.com/quadram-institute-bioscience/readfx),
which wraps Heng Li's `kseq.h` ([lh3/biofast](https://github.com/lh3/biofast)); earlier versions
used `klib.nim` and [nimreadfq](https://github.com/andreas-wilm/nimreadfq).

## About the name

The name of the program was modeled after "[ScriptFu](https://docs.gimp.org/en/gimp-concepts-script-fu.html)",
a set of macros built in the image manipulation **GIMP**.

## Outreach

* [Slides](https://www.icloud.com/keynote/0cfGObtl14rWj_q4nZ7lFy7fg#seqfu_2)
* [Slides (PDF)]({{ '/files/slides.pdf' | relative_url }})
