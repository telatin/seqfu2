---
title: Merge lanes per sample
summary: Combine the L001-L004 files produced by an Illumina run into one R1 and one R2 file per sample.
order: 3
level: beginner
input: [Directory, FASTQ]
tools: [seqfu lanes, seqfu count]
---

Illumina runs split each sample across lanes:

```text
ID1_S99_L001_R1_001.fastq.gz
ID1_S99_L001_R2_001.fastq.gz
ID1_S99_L002_R1_001.fastq.gz
ID1_S99_L002_R2_001.fastq.gz
...
```

## 1. Merge

[`seqfu lanes`]({{ '/tools/lanes.html' | relative_url }}) groups the files by sample and strand
and writes one file for each:

```bash
seqfu lanes -o merged/ raw/
ls merged/
```

```text
ID1_R1.fastq  ID1_R2.fastq  ID2_R1.fastq  ID2_R2.fastq ...
```

```note
The merged files are written uncompressed. The --extension option only changes the name
of the output files, so compress them afterwards (for example with gzip or pigz) rather
than passing -e .fastq.gz.
```

```bash
gzip merged/*.fastq
```

## 2. Check that no read was lost

The total number of reads per sample should match the sum over the lanes:

```bash
seqfu count raw/ID1_*_R1_*.fastq.gz
seqfu count merged/ID1_R1.fastq.gz
```
