---
layout: default
title: seqfu orf
parent: Core Tools
nav_order: 25
---

# seqfu orf

Extract open reading frames (ORFs) from nucleotide sequences (FASTA/FASTQ, gzipped supported).

`seqfu orf` is the preferred command.  
The legacy binary `fu-orf` is still available and accepts the same options.

```text
orf - extract ORF from nucleotide sequences

Usage:
  orf [options] <InputFile>
  orf [options] -1 File_R1.fq
  orf [options] -1 File_R1.fq -2 File_R2.fq
  orf --help | --codes

Input files:
  -1, --R1 FILE           First paired end file
  -2, --R2 FILE           Second paired end file

ORF Finding and Output options:
  -m, --min-size INT      Minimum ORF size (aa) [default: 25]
  -p, --prefix STRING     Rename reads using this prefix
  -r, --scan-reverse      Also scan reverse complemented sequences
  -c, --code INT          NCBI Genetic code to use [default: 1]
  -l, --min-read-len INT  Minimum read length to process [default: 25]
  -t, --translate         Consider input CDS

Paired-end options:
  -j, --join              Attempt Paired-End joining
  --min-overlap INT       Minimum PE overlap [default: 12]
  --max-overlap INT       Maximum PE overlap [default: 200]
  --min-identity FLOAT    Minimum sequence identity in overlap [default: 0.80]

Other options:
  --codes                 Print NCBI genetic codes and exit
  --pool-size INT         Reads per batch [default: 250]
  --in-flight-batches INT Max buffered batches before flush; 0 = auto [default: 0]
  --verbose               Print verbose log
  --debug                 Print debug log
  --help                  Show help
```

## Notes

* `--max-overlap` is a hard cap during paired-end overlap scan.
* `--in-flight-batches` controls memory/throughput balance:
  * lower values use less RAM
  * higher values can improve throughput
  * `0` enables automatic sizing

## Examples

Single input file:

```bash
seqfu orf --min-size 500 data/orf.fa.gz
```

Paired-end reads:

```bash
seqfu orf --min-size 29 -1 data/illumina_1.fq.gz -2 data/illumina_2.fq.gz
```

Paired-end with join and tighter memory budget:

```bash
seqfu orf -j --min-size 29 --in-flight-batches 4 -1 data/illumina_1.fq.gz -2 data/illumina_2.fq.gz
```

Legacy equivalent:

```bash
fu-orf --min-size 29 -1 data/illumina_1.fq.gz -2 data/illumina_2.fq.gz
```

## Genetic codes

Use `--code` to select an NCBI genetic code.  
Run `seqfu orf --codes` (or `fu-orf --codes`) to print supported codes.
