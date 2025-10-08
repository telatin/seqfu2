---
layout: home
title: Home
nav_order: 1
---

<a href="https://telatin.github.io/seqfu2" description="SeqFu documentation">
  <img align="right" width="128" height="128" src="img/seqfu-512.png">
</a>

# SeqFu

[![Seqfu-Nim-Build](https://github.com/telatin/seqfu2/actions/workflows/nim-2.yaml/badge.svg)](https://github.com/telatin/seqfu2/actions/workflows/nim-2.yaml)
[![pages-build-deployment](https://github.com/telatin/seqfu2/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/telatin/seqfu2/actions/workflows/pages/pages-build-deployment)
[![GitHub Stars](https://img.shields.io/github/stars/telatin/seqfu2?label=⭐️)](https://github.com/telatin/seqfu2)
[![Latest release](https://img.shields.io/github/v/release/telatin/seqfu2)](https://github.com/telatin/seqfu2/releases)
[![Bioconda Downloads](https://img.shields.io/conda/dn/bioconda/seqfu?label=Bioconda%20Downloads)](https://anaconda.org/bioconda/seqfu)

📦 See the **[repository](https://github.com/telatin/seqfu2)** | 💾 **[releases](https://github.com/telatin/seqfu2/releases)**

A general-purpose program to manipulate and parse information from FASTA/FASTQ files,
supporting gzipped input files.
Includes functions to _interleave_ and _de-interleave_ FASTQ files,
to _rename_ sequences and to _count_ and print _statistics_ on sequence lengths.
SeqFu is available for Linux and MacOS.

* A compiled program delivering high performance analyses
* Supports FASTA/FASTQ files, also Gzip compressed
* A growing collection of handy utilities, also for quick inspection of the datasets
* UNIX like commands but specific for sequences like `seqfu cat`, `seqfu head`, `seqfu tail`, `seqfu grep`
* Terminal friendly reports from `seqfu stats` or `seqfu count`...

Can be easily [installed](installation) via conda:

```bash
conda install -c conda-forge -c bioconda "seqfu>1.0"
```

## Citation

Telatin A, Fariselli P, Birolo G. *SeqFu: A Suite of Utilities for the Robust
and Reproducible Manipulation of Sequence Files*.
Bioengineering 2021, 8, 59. [doi.org/10.3390/bioengineering8050059](https://doi.org/10.3390/bioengineering8050059)
