---
sort: 20
---

# seqfu check

```note
Introduced in SeqFu 1.15
```

Evaluates the integrity of DNA FASTQ files. 

```text
Usage: seqfu check [options] <FQFILE> [<REV>]
       seqfu check [options] --dir <FQDIR>

  Check the integrity of FASTQ files, returns non zero
  if an error occurs. Will print a table with a report.

  Input is a single dataset:
    <FQFILE>                     the forward read file
    <REV>                        the reverse read file
  or a directory of FASTQ files:
    --dir <FQDIR>                the directory containing the FASTQ files

  Options:
    -n, --no-paired            Disable autodetection of second pair
    -q, --quiet                Do not print infos, just exit status
    -v, --verbose              Verbose output 
    -t, --thousands            Print numbers with thousands separator
    --debug                    Debug output
    -h, --help                 Show this help
```

### Integrity check

A single FASTQ file is considered valid if:
  
* each record has the same sequence and quality length
* only A,C,G,T,N characters are present in the sequence

A paired-end set of FASTQ files is considered valid if:

* each file is individually valid
* the two files have the same number of sequences
* the first and last sequence of both files has the same name (the last three characters are ignored if the remaining sequence name is greater than 4 characters)
* the first and last sequence of the two files are not identical (R1 != R2)

### Usage

To test a single file:

```bash
seqfu check test_file.fq.gz
```

To test a pair of files:

```bash
seqfu check test_R1.fq.gz [test_R2.fq.gz]
```

Note that if supplying a single file but a matching pair is detected (e.g. `test_R1.fq.gz` is supplied and `test_R2.fq.gz` is found), the check will be performed on both files.

To test all files in a directory:

```bash
seqfu check --dir test_dir
```

#### Other options

* `--no-paired` disables the autodetection of the second pair (i.e. force single end check)
* `--thousands` will add a thousands separator to the output
* `--quiet` will not print data, but only the exit status will be used
* `--verbose` will print more information (including processing speed)
* `--debug` will print debug information

### Exit status

If an error is identified in at least one file, the program will exit with non zero status.

### Output

The output is a table with the following columns:

1. Status (`OK` or `ERR`)
2. Library type (`SE` or `PE`)
3. Filename (the path to the first pair, if `PE`)
4. Number of sequences counted (if `PE`: number of sequences in **both** files) or `-` if the dataset is not valid
5. Number of bases (if `PE`: total number of bases in **both** files) or `-` if the dataset is not valid
6. Number of errors
7. List of detected errors (if any)

#### Example

Example of output for a directory containing 3 Paired End datasets:

```text
OK      PE      /tmp/data/16S_R1.fq.gz  12274   3694474 0
OK      PE      /tmp/data/16Snano_R1.fq.gz      468     140868  0
OK      PE      /tmp/data/illumina_1.fq.gz      14      1260    0
```

Example of errors (can be reproduced using the *data* directory of the repository)

```bash
seqfu check --dir data/primers
```

```text
OK      SE      data/primers/16S_merge.fq.gz    6137    2596981 0
OK      SE      data/primers/16S_vsearch_merge.fq.gz    3935    1818111 0
ERR     SE      data/primers/artificial.fq.gz   -       -       2       Invalid character in sequence: < > in R2.REV+.middle;
OK      SE      data/primers/its-merge.fq.gz    7299    1504898 0
OK      SE      data/primers/se.fq.gz   234     70434   0
OK      SE      data/primers/small.fq   4       360     0
OK      PE      data/primers/16S_R1.fq.gz       12274   3694474 0
OK      PE      data/primers/16Snano_R1.fq.gz   468     140868  0
ERR     PE      data/primers/art_R1.fq.gz       7       -       5       R2=Invalid character in sequence: < > in R2.REV+.middle;;First sequence names do not match (R1.startFOR+, R2.startREV+);Last sequence names do not match (R1.FOR1+.start-middle, );
OK      PE      data/primers/its_R1.fq.gz       16000   3387804 0
OK      PE      data/primers/itsfilt_R1.fq.gz   15618   3272396 0
OK      PE      data/primers/pico_R1.fq.gz      24      7224    0
```