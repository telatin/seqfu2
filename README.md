<a href="https://telatin.github.io/seqfu2" description="SeqFu documentation">
<img align="right" width="128" height="128" src="docs/img/seqfu-512.png"></a>

# SeqFu

[![Seqfu-Nim-Build](https://github.com/telatin/seqfu2/actions/workflows/nim-2.yaml/badge.svg)](https://github.com/telatin/seqfu2/actions/workflows/nim-2.yaml)
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

### Build from source

Building the Nim programs alone would just require a `nimble build`, but this would leave out some other utilities.
There is a `make` (Makefile) building system. Since Nim is not so popular, I describe a full installation:

```bash
# Do you have building tools? You will need C and make, in Ubuntu:
sudo apt install build-essential

# Install zlib
sudo apt install zlib1g-dev

# Install Nim 2.0
curl https://nim-lang.org/choosenim/init.sh -sSf | sh

# Clone this repo
git clone https://github.com/telatin/seqfu2

# Compile and test
cd seqfu2
make
make test

# All binaries are in bin (move them in a location in your $PATH)
```

## 📰 Citation

Telatin A, Fariselli P, Birolo G.
*SeqFu: A Suite of Utilities for the Robust
and Reproducible Manipulation of Sequence Files*.
Bioengineering 2021, 8, 59. [doi.org/10.3390/bioengineering8050059](https://doi.org/10.3390/bioengineering8050059)

```bibtex
@article{seqfu,
  title        = {SeqFu: A Suite of Utilities for the Robust and Reproducible Manipulation of Sequence Files},
  author       = {Telatin, Andrea and Fariselli, Piero and Birolo, Giovanni},
  year         = 2021,
  journal      = {Bioengineering},
  volume       = 8,
  number       = 5,
  doi          = {10.3390/bioengineering8050059},
  issn         = {2306-5354},
  url          = {https://www.mdpi.com/2306-5354/8/5/59},
  article-number = 59,
  pubmedid     = 34066939
}
```

## 📙 Full documentation

 The full documentation is available at:
[**telatin.github.io/seqfu2**](https://telatin.github.io/seqfu2)

## Splash screen

![`seqfu`](docs/img/screenshot-seqfu.png "SeqFu")

