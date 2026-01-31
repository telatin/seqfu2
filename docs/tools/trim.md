---
layout: default
title: seqfu trim
parent: Core Tools
nav_order: 23
---

# trim

The `trim` command provides comprehensive quality trimming and filtering for FASTQ files, with an interface and efficiency similar to `fastp`. It supports both single-end and paired-end reads.

By default, it performs 3' sliding window trimming and quality filtering.

## Usage

For single-end reads:
```
seqfu trim [options] <input.fq>
```

For paired-end reads:
```
seqfu trim [options] -1 <R1.fq> [-2 <R2.fq>]
```

## Options

### Input Options

| Option | Description | Default |
|---|---|---|
| `<input>` | Single-end FASTQ file. Use `-` for stdin. | |
| `-1, --r1 FILE` | R1 file for paired-end reads. | |
| `-2, --r2 FILE` | R2 file for paired-end reads. If not specified, it's auto-detected based on the R1 filename. | |
| `--for-tag TAG` | Pattern for R1 files for auto-detection. | `auto` |
| `--rev-tag TAG` | Pattern for R2 files for auto-detection. | `auto` |

### Output Options

| Option | Description | Default |
|---|---|---|
| `-o, --output FILE/BASE` | Output file for single-end, or output basename for paired-end (required for PE). | `stdout` |
| `--r1-suffix SUFFIX` | Suffix for the R1 output file in paired-end mode. | `_R1.fastq` |
| `--r2-suffix SUFFIX` | Suffix for the R2 output file in paired-end mode. | `_R2.fastq` |
| `-z, --compress` | Compress output with gzip. | off |

### Fixed Position Trimming

| Option | Description | Default |
|---|---|---|
| `--trim-front N` | Trim N bases from the 5' end of each read. | 0 |
| `--trim-tail N` | Trim N bases from the 3' end of each read. | 0 |

### Sliding Window Trimming

This is used to remove low-quality ends of reads.

| Option | Description | Default |
|---|---|---|
| `-5, --cut-front` | Enable 5' sliding window trimming. | off |
| `--cut-front-window N` | Window size for 5' trimming. | 4 |
| `--cut-front-qual N` | Quality threshold for 5' trimming. | 20 |
| `-3, --cut-tail` | Enable 3' sliding window trimming. | **on** |
| `--cut-tail-window N` | Window size for 3' trimming. | 4 |
| `--cut-tail-qual N` | Quality threshold for 3' trimming. | 20 |
| `-r, --cut-right` | Enable right-side sliding window trimming (takes precedence over `cut-tail`). | off |
| `--cut-right-window N` | Window size for right-side trimming. | 4 |
| `--cut-right-qual N` | Quality threshold for right-side trimming. | 20 |

### Quality Filtering

Enabled by default.

| Option | Description | Default |
|---|---|---|
| `-Q, --disable-quality` | Disable all quality filtering. | off |
| `--qualified-qual N` | A base is considered qualified if its quality is >= N. | 15 |
| `--unqualified-percent N`| Maximum allowed percentage of unqualified bases per read. | 40.0 |
| `--avg-qual N` | Minimum average quality for a read. Disabled if 0. | 0 |

### Other Filtering

| Option | Description | Default |
|---|---|---|
| `-n, --n-base-limit N` | Maximum number of N bases allowed in a read. | 5 |
| `-l, --min-length N` | Minimum read length to keep a read. | 15 |
| `--max-length N` | Maximum read length. Disabled if 0. | 0 |
| `--complexity` | Enable low complexity filter. | off |
| `--complexity-threshold F`| Minimum complexity ratio (0 to 1). | 0.3 |

### Performance

| Option | Description | Default |
|---|---|---|
| `-t, --threads N` | Number of threads to use. | 1 |
| `--batch-size N` | Number of reads to process in each batch per thread. | 10000 |

### Other Options

| Option | Description | Default |
|---|---|---|
| `--offset N` | Quality score offset. | 33 |
| `--preset PRESET` | Apply a preset configuration (`strict` or `lenient`). | |
| `-v, --verbose` | Print verbose statistics to stderr. | off |
| `--stats-json FILE` | Write detailed statistics in JSON format to a file. | |
| `-h, --help` | Show the help message. | |

## Description

The `trim` command is a versatile tool for cleaning FASTQ data. It can handle both single-end and paired-end reads and offers a wide range of options for trimming and filtering.

By default, `seqfu trim` enables 3' tail trimming (`--cut-tail`) and quality filtering (based on `--qualified-qual` and `--unqualified-percent`). For paired-end data, both reads must pass all filtering steps to be included in the output.

## Presets

Two presets are available for convenience:

- `strict`: Enables aggressive filtering. Equivalent to `--cut-right -l 50 --avg-qual 25`.
- `lenient`: Enables light filtering. Equivalent to `--cut-tail -l 30 -Q` (disables quality filtering).

## Examples

### Basic trimming (defaults)

For a single-end file, this uses the default settings: 3' tail trimming and quality filtering.
```bash
seqfu trim input.fq -o output.fq
```

### Paired-end trimming

The R2 file is auto-detected from the R1 name. The output files will be `trimmed_R1.fastq` and `trimmed_R2.fastq`.
```bash
seqfu trim -1 sample_R1.fq -o trimmed
```

### Aggressive filtering

This example uses the `--cut-right` method, sets a minimum average quality of 25, and a minimum length of 50 bp.
```bash
seqfu trim -1 R1.fq -2 R2.fq -o out --cut-right --avg-qual 25 -l 50
```

### Minimal processing

This disables quality filtering (`-Q`) and applies fixed trimming from both ends. Note that the default 3' sliding window trimming (`--cut-tail`) is still active.
```bash
seqfu trim input.fq -o output.fq -Q --trim-front 5 --trim-tail 5
```
