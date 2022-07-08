---
sort: 3
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
  -t, --threads INT      Working threads [default: 4]
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

### Streaming

Input from stream is supported.

### Example output

Output is a TSV text with three columns: sample name, number of reads and type ("SE" for Single End, "Paired" for Paired End)

```text
data/test.fastq       3  SE
data/comments.fastq   5  SE
data/test2.fastq      3  SE
data/qualities.fq     5  SE
data/illumina_1.fq.gz 7  Paired
```

In case of errors will print a warning:

```text
ERROR: Different counts in data/longerone_R1.fq.gz and data/longerone_R2.fq.gz
# data/longerone_R1.fq.gz: 7
# data/longerone_R2.fq.gz: 2
```

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

## Screenshot

![Screenshot of "seqfu count"](img/screenshot-count.svg "SeqFu cat")