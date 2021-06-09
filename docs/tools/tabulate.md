---
sort: 16
---
# seqfu tabulate

```note
under development
```

This program converts a sequence file (FASTA or FASTQ) to a tabular file,
and vice versa.

Several Unix tools can process a stream of information line-by-line, and
tabular file can be easily modified and filtered piping serveral programs.

This tool will allow to **tabulate** (convert to TSV) and 
**detabulate** (convert to FASTX) sequences.

```
Usage: tabulate [options] [<file>]

Convert FASTQ to TSV and viceversa. Single end is a 4 columns table (name, comment, seq, qual),
paired end have 4 columns for the R1 and 4 columns for the R2. 
Paired end reads need to be supplied as interleaved.
 

Options:
  -i, --interleaved        Input is interleaved (paired-end)
  -d, --detabulate         Convert TSV to FASTQ (if reading from file is autodetected) 
  -c, --comment-sep CHAR   Separator between name and comment (default: tab)
  -s, --field-sep CHAR     Field separator (default: tab)
  -v, --verbose            Verbose output
  -h, --help               Show this help
```

## Tabular format

The conversion works as follows:
* FASTA files are converted to a 3 columns table: name, comments and sequence
* Single-End FASTQ files are converted to a 4 columns table: name, comments, sequence and quality
* Paired-End FASTQ (interleaved) files are converted to 8 colums table: R1 name, comments, sequence and quality and R2 name, comments, sequence and quality

To allow an efficient use of streams, paired-end datasets need to be interleaved (see: _seqfu interleave_).

## Conversions


### Sequence to table
A single file can be converted to tabular format. 

*NOTE*: If the file is automatically detected as interleaved (the first and second read
have the same name) you can omit `-i` (or `--interleave`), but we recommend to use it to make the command clearer.

```
seqfu tabulate file.fastq | gzip -c > tabular.tab.gz
```


### Table to sequences
When a file is provided, the input format is automatically detected. Otherwise specify `-d` (or `--detabulate` to convert from table to FASTX).

```
seqfu tabulate file.tab > sequences.fq
```
or, via _stream_:
```
cat file.tab.gz | seqfu tabulate  --detabulate > sequences.fq
```

### Pipeline

We designed the tool to provide a simple way to make ad hoc modifications via tabular lines, so a full workflow could be:

```
seqfu interleave ... | seqfu tabulate | CUSTOM_STEP | seqfu tabulate --detabulate | seqfu deinterleave -o basename -
```
