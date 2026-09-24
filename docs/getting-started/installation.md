---
title: Installation
summary: Install SeqFu from Bioconda, as a pre-compiled binary, or from source.
redirect_from:
  - /installation
  - /installation.html
  - /install.html
---

## Bioconda (recommended)

The recommended installation method is via [Bioconda](https://anaconda.org/bioconda/seqfu),
supported on both **Linux** and **macOS**. It installs the full set of tools: the `seqfu`
binary, all the `fu-*` utilities and the helper scripts.

```bash
conda install -c conda-forge -c bioconda "seqfu>=1.30"
```

A dedicated environment keeps things tidy:

```bash
conda create -n seqfu -c conda-forge -c bioconda seqfu
conda activate seqfu
```

```note
Ask for a recent version explicitly: 0.x releases are very old and no longer supported.
```

## Pre-compiled binaries

Pre-compiled binaries are attached to each
[release](https://github.com/telatin/seqfu2/releases). Starting with v1.29.0, releases include
the main `seqfu` binary for Linux and macOS, on both x86_64 and ARM64/aarch64.
The binaries contain the core tools only; install from Bioconda to get the utilities too.

To install the latest matching binary into `$HOME/.local/bin`:

```bash
curl -fsSL {{ site.url }}{{ site.baseurl }}/install.sh | sh
```

The installer detects the latest release and your platform, downloads the matching asset,
verifies it against the SHA-256 digest reported by GitHub, installs it as `seqfu` and marks
it executable. Set `SEQFU_INSTALL_DIR` to choose another destination:

```bash
curl -fsSL {{ site.url }}{{ site.baseurl }}/install.sh | SEQFU_INSTALL_DIR=/opt/bin sh
```

## Build from source

SeqFu is written in [Nim](https://nim-lang.org) and requires Nim 2.2 or newer.

1. Install Nim ([instructions](https://nim-lang.org/install_unix.html)); `choosenim` is the
   easiest option where available.
2. Clone the repository and build:

   ```bash
   git clone https://github.com/telatin/seqfu2
   cd seqfu2
   make
   ```

3. The binaries are written to `./bin`. Run the test suite with `make test`.

`nimble build` also works, and downloads the required Nim packages.

It is possible to compile SeqFu on Windows, but the platform is not supported.
