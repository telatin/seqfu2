<a href="https://telatin.github.io/seqfu2" description="SeqFu documentation">
<img align="right" width="128" height="128" src="docs/img/seqfu-512.png"></a>

# SeqFu 0.8.2

![Commit](https://img.shields.io/github/last-commit/telatin/nim-stuff)
![Version 0.8.2](https://img.shields.io/badge/version-0.8.2-blue)
[![Build Status](https://travis-ci.com/telatin/seqfu2.svg?branch=main)](https://travis-ci.com/telatin/seqfu2)

A general-purpose program to manipulate and parse information from FASTA/FASTQ files,
supporting gzipped input files.
Includes functions to *interleave* and *de-interleave* FASTQ files, to *rename*
sequences and to *count* and print *statistics* on sequence lengths.


:book: **The documentation is available from [dedicated website](https://telatin.github.io/seqfu2)**

---

The program has a set of subcommands (and there are some extra utilities as well)
```
SeqFU - Sequence Fastx Utilities
version: 0.8.2

	• count [cnt]         : count FASTA/FASTQ reads, pair-end aware
	• deinterleave [dei]  : deinterleave FASTQ
	• derep [der]         : feature-rich dereplication of FASTA/FASTQ files
	• interleave [ilv]    : interleave FASTQ pair ends
	• merge [mrg]         : merge Illumina lanes
	• sort [srt]          : sort sequences by size (uniques)
	• stats [st]          : statistics on sequence lengths

	• grep                : select sequences with patterns
	• head                : print first sequences
	• tail                : view last sequences
	• view                : view sequences

Add --help after each command to print usage

```
## Some functions

### seqfu head

```
Usage: head [options] [<inputfile> ...]

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING       Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

### seqfu interleave

```
ilv: interleave FASTQ files

  Usage: ilv [options] -1 <forward-pair> [-2 <reverse-pair>]

  -f --for-tag <tag-1>       string identifying forward files [default: auto]
  -r --rev-tag <tag-2>       string identifying forward files [default: auto]
  -o --output <outputfile>   save file to <out-file> instead of STDOUT
  -c --check                 enable careful mode (check sequence names and numbers)
  -v --verbose               print verbose output

  -s --strip-comments        skip comments
  -p --prefix "string"       rename sequences (append a progressive number)

guessing second file:
  by default <forward-pair> is scanned for _R1. and substitute with _R2.
  if this fails, the patterns _1. and _2. are tested.

example:

    ilv -1 file_R1.fq > interleaved.fq
```

### seqfu deinterleave

```
ilv: interleave FASTQ files

  Usage: dei [options] -o basename <interleaved-fastq>

  -o --output-basename "str"     save output to output_R1.fq and output_R2.fq
  -f --for-ext "R1"              extension for R1 file [default: _R1.fq]
  -r --rev-ext "R2"              extension for R2 file [default: _R2.fq]
  -c --check                     enable careful mode (check sequence names and numbers)
  -v --verbose                   print verbose output

  -s --strip-comments            skip comments
  -p --prefix "string"           rename sequences (append a progressive number)
 
notes:
    use "-" as input filename to read from STDIN

example:

    dei -o newfile file.fq
```

### seqfu derep

```
Usage: derep [options] [<inputfile> ...]

Options:
  -k, --keep-name              Do not rename sequence, but use the first sequence name
  -i, --ignore-size            Do not count 'size=INT;' annotations (they will be stripped in any case)
  -m, --min-size=MIN_SIZE      Print clusters with size equal or bigger than INT sequences [default: 0]
  -p, --prefix=PREFIX          Sequence name prefix [default: seq]
  -5, --md5                    Use MD5 as sequence name (overrides other parameters)
  -j, --json=JSON_FILE         Save dereplication metadata to JSON file
  -s, --separator=SEPARATOR    Sequence name separator [default: .]
  -w, --line-width=LINE_WIDTH  FASTA line width (0: unlimited) [default: 0]
  -l, --min-length=MIN_LENGTH  Discard sequences shorter than MIN_LEN [default: 0]
  -x, --max-length=MAX_LENGTH  Discard sequences longer than MAX_LEN [default: 0]
  -c, --size-as-comment        Print cluster size as comment, not in sequence name
  --add-len                    Add length to sequence
  -v, --verbose                Print verbose messages
  -h, --help                   Show this help
```

### seqfu stats

```
Usage: stats [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -n, --nice             Print nice terminal table
  --csv                  Separate with commas (default: tabs)
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

### seqfu count

```
Usage: count [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -v, --verbose          Verbose output
  -h, --help             Show this help
```
