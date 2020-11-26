---
sort: 1
permalink: /installation
---

# Installation

```note
this page is a stub
```

## Pre-compiled binaries

Pre-compiled binaries are the fastest and easiest way to get _qax_. To get the latest version,
use the following command, otherwise check the [stable releases](https://github.com/telatin/qax/releases).  


```
# From linux
wget "https://github.com/telatin/seqfu2/raw/main/bin/seqfu"
chmod +x seqfu

# From macOS
wget -O seqfu "https://github.com/telatin/seqfu2/raw/main/bin/seqfu_mac"
chmod +x seqfu
```

## Install via Miniconda

```note
Miniconda installation has been tested on MacOS and Linux, but being _qax_ a single binary, if the precompiled works for you we recommend it.
```

Alternatively, you can install _qax_ from BioConda, if you have _conda_ installed:

```
conda install -c conda-forge -c bioconda seqfu2
```
