---
sort: 1
permalink: /installation
---

# Installation


## Install via Miniconda

The **recommended** installation method is via BioConda. 
If you have _conda_ installed ([how to install it](https://docs.conda.io/en/latest/miniconda.html)):

```
conda install -c conda-forge -c bioconda seqfu
```

More info on [installing conda](https://telatin.github.io/microbiome-bioinformatics/Install-Miniconda/).

## Pre-compiled binaries

Pre-compiled core binaries are distributed with the [stable releases](https://github.com/telatin/seqfu2/releases),
where `seqfu` is the native Linux binary and `seqfu-mac` is the MacOS binary.
When possible, we recommend to install SeqFu via Miniconda (see above), as it provides the full set of tools.


## Manual compilation

1) If `nim` is not installed, install it ([see instructions](https://nim-lang.org/install_unix.html)).
  * We suggest - when available - the `choosenim` method
2) Clone the repository (`git clone https://github.com/telatin/seqfu2`)
3) Compile with `nimble build`
4) The binaries will be available in the `./bin` directory

 
