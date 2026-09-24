---
title: seqfu homocomp
summary: "Collapse homopolymer runs in FASTA/FASTQ records."
category: transform
input: [FASTA, FASTQ]
output: "Same as input"
wrapper: false
deprecated: false
experimental: false
paired: false
interactive: false
keywords: "homopolymer compress collapse nanopore"
---

`seqfu homocomp` collapses each homopolymer run in FASTA or FASTQ sequences to
one base. Record names, comments, format, and input order are preserved. For
FASTQ records, the first quality score in each collapsed run is retained.

```text
Usage:
  homocomp [options] [<FASTX>...]

Options:
  -t, --threads INT       Number of worker threads [default: 1]
  --batch-size INT        Records processed per worker job [default: 1000]
  -v, --verbose           Print processing information
  -h, --help              Show this help
```

With no input files, the command reads from standard input. Plain and
gzip-compressed FASTA and FASTQ files are supported. Multiple files are emitted
in the order given on the command line.

## Examples

Compress one FASTQ file:

```bash
seqfu homocomp reads.fastq.gz > reads.homocomp.fastq
```

Process several files with four workers and batches of 5,000 records:

```bash
seqfu homocomp reads/*.fastq.gz --threads 4 --batch-size 5000 > combined.fastq
```

Use a pipe:

```bash
seqfu cat reads.fastq.gz | seqfu homocomp > reads.homocomp.fastq
```

## Quality Scores

Input:

```text
@read comment
AAACCCGTTTTA
+
123456789ABC
```

Output:

```text
@read comment
ACGTA
+
1478C
```

The old standalone `fu-homocomp` executable has been removed; use
`seqfu homocomp` instead.
