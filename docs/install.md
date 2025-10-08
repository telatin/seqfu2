---
layout: default
title: Installation
nav_order: 2
permalink: /installation
---

# Installation

## Install via Miniconda

The **recommended** installation method is via BioConda,
which is supported from both **Linux** and **macOS**.
If you have _conda_ installed ([how to install it](https://docs.conda.io/en/latest/miniconda.html)):

```bash
# Ensure a recent version will be installed: 0.x is a very old and unsupported tool
conda install -c conda-forge -c bioconda "seqfu>1.10"
```

More info on [installing conda](https://telatin.github.io/microbiome-bioinformatics/Install-Miniconda/).

:warning: It is _possible_ to compile the program for Windows,
but we cannot provide support for this platform at the moment.

## Pre-compiled binaries

Pre-compiled core binaries are distributed with the [releases](https://github.com/telatin/seqfu2/releases),
as zip files containing all the tools, labeled as "Linux" and "Darwin" as they target Linux and macOS respectively.
When possible, we recommend to install SeqFu via Miniconda (see above),
as it provides the full set of tools.

## Manual compilation

### Linux and macOS

1) If `nim` is not installed, install it
(**[see instructions](https://nim-lang.org/install_unix.html)**).
We suggest - when available - the `choosenim` method

2) Clone the repository (`git clone https://github.com/telatin/seqfu2`)

3) Compile with `nimble build`, that will download the required packages

4) The binaries will be available in the `./bin` directory
