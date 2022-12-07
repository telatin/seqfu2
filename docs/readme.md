<a href="https://telatin.github.io/seqfu2" description="SeqFu documentation">
  <img align="right" width="128" height="128" src="img/seqfu-512.png">
</a>

# SeqFu

[![Seqfu-Test](https://github.com/telatin/seqfu2/actions/workflows/nimtest.yml/badge.svg)](https://github.com/telatin/seqfu2/actions/workflows/nimtest.yml)
[![pages-build-deployment](https://github.com/telatin/seqfu2/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/telatin/seqfu2/actions/workflows/pages/pages-build-deployment)
![Last Commit](https://img.shields.io/github/last-commit/telatin/seqfu2)
[![Latest release](https://img.shields.io/github/v/release/telatin/seqfu2)](https://github.com/telatin/seqfu2/releases)
[![Bioconda Downloads](https://img.shields.io/conda/dn/bioconda/seqfu?label=Bioconda%20Downloads)](https://anaconda.org/bioconda/seqfu)

:package: See the **[repository](https://github.com/telatin/seqfu2)** | :dvd: **[releases](https://github.com/telatin/seqfu2/releases)**

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
conda install -c bioconda seqfu
```

## Citation

Telatin A, Fariselli P, Birolo G. *SeqFu: A Suite of Utilities for the Robust 
and Reproducible Manipulation of Sequence Files*. 
Bioengineering 2021, 8, 59. [doi.org/10.3390/bioengineering8050059](https://doi.org/10.3390/bioengineering8050059)

## Contents

{% include list.liquid all=true %}

