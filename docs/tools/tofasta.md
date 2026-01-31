---
layout: default
title: seqfu tofasta
parent: Core Tools
nav_order: 22
---

# seqfu tofasta

Converts various sequence file formats to FASTA format.

```note
Introduced in SeqFu 1.23.0
```

A versatile format converter supporting multiple bioinformatics file formats including
sequence alignments, genome annotations, and assembly graphs. The tool automatically
detects the input format and converts sequences to standard FASTA format.

Replicates the approach of [any2fasta](https://github.com/tseeman/any2fasta), but it's faster.

```text
Usage: tofasta [options] <inputfile>...

Convert various sequence formats to FASTA format.

Options:
  -n, --replace-iupac    Replace non-IUPAC characters with 'N'
  -l, --to-lowercase     Convert sequences to lowercase
  -u, --to-uppercase     Convert sequences to uppercase
  -o, --output FILE      Write output to FILE (default: stdout)
                         Note: checks for duplicate IDs across all files
  -v, --verbose          Print progress information to stderr
  -h, --help             Show this help
```

## Supported Formats

`seqfu tofasta` automatically detects and converts the following formats:

| Format | Description | Notes |
|--------|-------------|-------|
| FASTA | Standard FASTA format | Pass-through with optional transformations |
| FASTQ | Sanger, Illumina, Solexa | Quality scores are discarded |
| GenBank   | NCBI GenBank flat file | Extracts sequences from ORIGIN section |
| EMBL      | EMBL-Bank format | Extracts sequences from SQ section |
| GFF       | Generic Feature Format | Extracts sequences after `##FASTA` directive |
| GFA       | Graphical Fragment Assembly | Extracts sequences from S (segment) lines |
| Clustal   | Clustal W alignment | Preserves gaps in sequences |
| Stockholm | Stockholm alignment | Converts '.' gaps to '-' |

## Options


**`-n, --replace-iupac`**
Replaces non-standard IUPAC characters with 'N'. Standard IUPAC codes (A, T, G, C, N)
are preserved, while ambiguous codes (R, Y, W, S, K, M, etc.) are replaced with 'N'.

**`-l, --to-lowercase`**
Converts all sequence characters to lowercase. Useful for soft-masking or
compatibility with tools that expect lowercase input.

**`-u, --to-uppercase`**
Converts all sequence characters to uppercase. Takes precedence over `-l` if both
are specified.

**`-o, --output FILE`**
Writes all sequences to a single output file instead of stdout. When using this option,
the tool performs duplicate ID checking across all input files and will exit with an
error if duplicate sequence IDs are found.

**`-v, --verbose`**
Prints progress information to stder

## Examples

### Basic Format Conversion

Convert a GenBank file to FASTA:

```bash
seqfu tofasta genome.gbk > genome.fasta
```

Convert a FASTQ file (quality scores are discarded):

```bash
seqfu tofasta reads.fastq.gz > reads.fasta
```

### Multiple Files

Process multiple files and combine into one FASTA file:

```bash
seqfu tofasta -o combined.fasta file1.gbk file2.gff file3.fastq.gz
```

Replace ambiguous IUPAC codes with N:

```bash
seqfu tofasta -n -u sequences.fasta > clean.fasta
```


### Input Handling

- **Gzip Support**: All input files can be gzip-compressed (`.gz` extension)
- **No STDIN**: Currently, `tofasta` requires file arguments and does not support reading from standard input
- **Format Detection**: File format is automatically detected from content, not file extension
- **Error Handling**: The tool is strict and will exit with an error on unknown or malformed formats

### Duplicate ID Detection

When using `-o/--output`, the tool checks for duplicate sequence IDs across all input files:

```bash
# This will fail if seq1.gbk and seq2.gbk contain sequences with the same ID
seqfu tofasta -o combined.fasta seq1.gbk seq2.gbk
```

Error message example:
```
ERROR: Duplicate sequence ID found: NZ_12345
  First occurrence in a previous file
  Second occurrence in: seq2.gbk
```

### Format-Specific Behavior

**GenBank/EMBL**:
- Extracts accession number as sequence ID
- Extracts sequence from ORIGIN/SQ section
- Handles multiple records in a single file

**GFF**:
- Only processes sequences after `##FASTA` directive
- Ignores feature annotations
- Preserves sequence IDs from FASTA headers

**Clustal/Stockholm**:
- Preserves alignment gaps in output
- Concatenates sequence fragments if alignment spans multiple blocks
- Stockholm '.' gaps are converted to '-'

**GFA**:
- Only processes S (segment) lines
- Uses segment name as sequence ID
- Ignores paths, links, and other graph elements

