---
sort: 11
title: trim
---

# trim

The `trim` command trims FASTQ sequences from the 3' end when quality drops below a threshold in a sliding window.

## Usage

```
seqfu trim [options] [<inputfile> ...]
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-w, --window-size INT` | Window size for quality calculation | 5 |
| `-q, --min-avg-qual INT` | Minimum average quality within window | 20 |
| `--offset INT` | Quality offset (33 for Illumina) | 33 |
| `-o, --output FILE` | Output filename | stdout |
| `-v, --verbose` | Verbose output | off |
| `-h, --help` | Show help | |

## Description

This command scans the quality scores of FASTQ sequences using a sliding window of the specified size. 
When the average quality within the window drops below the specified threshold, it trims the sequence 
from that position, discarding all subsequent bases.

This is useful for removing low-quality regions from the 3' end of sequencing reads, which often 
contain more errors as the sequencing reaction progresses.

## Examples

Trim sequences when the quality drops below 20 in a window of 5 bases:
```bash
seqfu trim input.fastq -o output.fastq
```

Use a more stringent quality threshold:
```bash
seqfu trim -q 25 input.fastq -o output.fastq
```

Change the window size:
```bash
seqfu trim -w 10 -q 20 input.fastq -o output.fastq
```