---
layout: default
title: seqfu count
parent: Core Tools
nav_order: 4
---


# seqfu count

*count* (or *cnt*) is one of the core subprograms of *SeqFu*.
It's used to count the sequences in FASTA/FASTQ files, and it's _paired-end_ aware so
it will print the count of both files in a single line, but checking that both
files have the same number of sequences.

In version 1.5 the program has been redesigned to parse multiple files simultaneously.

```text
Usage: count [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -s, --sort MODE        Sort output: input|name|counts|none [default: input]
      --reverse-sort     Reverse selected sort order
  -T, --interactive-table  Open interactive table view (TUI)
  -t, --threads INT      Working threads [default: 8]
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

### Streaming

Input from stream (`-`) is supported.

### Example output

Output is a TSV text with three columns: sample name, number of reads and type ("SE" for Single End, "Paired" for Paired End)

```text
data/test.fastq       3  SE
data/comments.fastq   5  SE
data/test2.fastq      3  SE
data/qualities.fq     5  SE
data/illumina_1.fq.gz 7  Paired
```

With `-T/--interactive-table`, `seqfu count` opens an interactive table viewer (TUI) instead of printing TSV to stdout.  
Inside the viewer you can sort columns, filter rows and save the visible table to file.

In case of pairing/count errors, `seqfu count` prints error diagnostics to stderr and returns a non-zero exit code.

### Sorting

Sorting can be controlled with `--sort`:
- `input`: preserve input argument order (default)
- `name`: sort by filename
- `counts`: sort by read count (descending)
- `none`: emit rows in completion order (first completed worker first)

Use `--reverse-sort` to reverse the selected sort order.

### Error handling

Examples of explicit error diagnostics:
- mismatched paired-end counts (R1 vs R2)
- reverse-only input without matching R1
- unreadable/corrupted input files

Error rows are also represented in table/stdout output with `<Error:...>` labels.

### Multithreading

Performance improvement measured on the _MiSeq SOP_ dataset from [mothur](https://mothur.org):

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu count ../mothur-sop/*.fastq -t 4`   | 142.5 ± 5.8  | 127.3 | 152.3 | 1.00        |
| `seqfu count ../mothur-sop/*.fastq -t 1`   | 416.5 ± 15.2 | 397.8 | 440.9 | 2.92 ± 0.16 |
| `seqfu count-legacy ../mothur-sop/*.fastq` | 539.2 ± 16.6 | 519.6 | 577.4 | 3.78 ± 0.19 |

## Legacy algorithm

```text
Usage: count-legacy [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward string, like _R1 [default: auto]
  -r, --rev-tag R2       Reverse string, like _R2 [default: auto]
  -m, --multiqc FILE     Save report in MultiQC format
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

### MultiQC output

Using the  `--multiqc OUTPUTFILE` option it's possible to save a MultiQC compatible file (we recommend to use the *projectname_mqc.tsv* filename format).
After coolecting all the MultiQC files in a directory, using `multiqc -f .` will generate the MultiQC report.
MultiQC itself can be installed via Bioconda with `conda install -y -c bioconda multiqc`.

To understand how to use MultiQC, if you never did so, check their excellent [documentation](https://multiqc.info).

### Screenshot

![Screenshot of "seqfu count"]({{site.baseurl}}/img/screenshot-count.svg "SeqFu cat")
