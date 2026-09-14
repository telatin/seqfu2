---
layout: default
title: seqfu merge
parent: Core Tools
---


# seqfu merge

```note
Function under development: APIs and default parameters are likely going to change.

This is why you don't see it listed in the main screen of SeqFu (yet).
```

A tool to merge paired end reads using overlap detection, quality-aware consensus
calling, and optional worker threads.

```
Usage:
  merge [options] -1 FILE_R1 [-2 FILE_R2]
  merge [options] FILE_R1

  Options:
  -1, --R1 FILE              First paired-end file
  -2, --R2 FILE              Second paired-end file, can be automatically inferred
  -i, --min-id FLOAT         Minimum overlap identity [default: 0.90]
  -m, --min-overlap INT      Minimum overlap length [default: 20]
  --accept-id FLOAT          Accept overlap immediately above identity [default: 0.97]
  --min-len INT              Minimum merged read length, 0 disables [default: 50]
  --max-len INT              Maximum merged read length, 0 disables [default: 0]
  --min-length INT           Deprecated alias for --min-len
  --max-length INT           Deprecated alias for --max-len
  --search STR               Overlap search mode [default: seeded]
                             (seeded/exhaustive)
  --keep-unmerged            Output R1 when merging fails [default: false]
  --qual-method STR          Quality handling strategy [default: recalculate]
                             (first/lowest/recalculate)
  -t, --threads INT          Worker threads
  --batch-size INT           Read pairs per worker batch [default: 1024]
  -v, --verbose              Print verbose messages
  -h, --help                 Show this help
```

## Merging reads

There are several tools to merge overlapping reads, and some are better than others.
In particular if we use tools that correcly interpret the _Phred quality scores_, then
tools like USEARCH and VSEARCH are correcly recalibrating the quality of the overlapping
bases.

This experimental module of SeqFu now uses a seeded offset search with an
exhaustive fallback. In the overlapping segment, `--qual-method recalculate`
recomputes posterior Phred scores, `first` keeps the R1 quality, and `lowest`
keeps the lower quality score.

## Potential uses

This tool can be used to estimate the overlapping size or the "mergeability" of reads 
before using the tools of choice.

For example:
```
seqfu merge -1 reads_R1.fq | seqfu head -n 200 | seqfu stats -n
```

## Output
The merged reads are printed to the standard output.

Also this is somehow unusual compared with most mergin tools, but allows streaming which
is a core feature in SeqFu tools.
