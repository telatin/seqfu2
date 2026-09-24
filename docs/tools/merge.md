---
title: seqfu merge
summary: "Merge overlapping paired-end reads into single fragments."
category: paired
input: [FASTQ]
output: "FASTQ"
aliases: [mrg]
wrapper: false
deprecated: false
experimental: true
paired: true
interactive: false
related: ["seqfu interleave", "seqfu trim"]
keywords: "merge join overlap paired pear flash"
---

```note
Function under development: APIs and default parameters are likely going to change.
```

A tool to merge paired end reads using overlap detection, quality-aware consensus
calling, and optional worker threads.

```text
Usage:
  merge [options] -1 FILE_R1 [-2 FILE_R2]
  merge [options] FILE_R1

Options:
  -1, --R1 FILE              First paired-end file
  -2, --R2 FILE              Second paired-end file (can be auto-inferred)

Merging options:
  -i, --min-id FLOAT         Minimum overlap identity [default: 0.90]
  -m, --min-overlap INT      Minimum overlap length [default: 20]
  --accept-id FLOAT          Accept overlap immediately above identity [default: 0.97]
  --search STR               Overlap search mode [default: seeded]
                             (seeded/exhaustive)
  --keep-unmerged            Output R1 when merging fails [default: false]

Output filter:
  --min-length INT           Minimum merged read length, 0 disables [default: 50]
  --max-length INT           Maximum merged read length, 0 disables [default: 0]
  
Quality options:
  --qual-method STR          Quality handling strategy [default: recalculate]
                             (first/lowest/recalculate)

Threading options:
  -t, --threads INT          Worker threads [default: 8]
  --batch-size INT           Read pairs per worker batch [default: 1024]

Other options:
  -v, --verbose              Print verbose messages
  -h, --help                 Show this help
```

## Merging reads

There are several tools to merge overlapping reads, and some are better than others.

This module of SeqFu now uses a seeded offset search with an
exhaustive fallback. In the overlapping segment, `--qual-method recalculate`
recomputes posterior Phred scores, `first` keeps the R1 quality, and `lowest`
keeps the lower quality score. The `first` mode is interesting for tools that are calibrated on original Illumina quality.

## Potential uses

This tool can be used to estimate the overlapping size or the "mergeability" of reads 
before using the tools of choice.

For example:

```bash
seqfu merge -1 reads_R1.fq | seqfu head -n 200 | seqfu stats -n
```

## Output

The merged reads are printed to the standard output.

Also this is somehow unusual compared with most mergin tools, but allows streaming which
is a core feature in SeqFu tools.
