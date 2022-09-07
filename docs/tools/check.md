---
sort: 20
---

# seqfu check

```note
Introduced in SeqFu 1.15
```



```text
Usage: seqfu check [options] <FQFILE> [<REV>]
       seqfu check [options] --dir <FQDIR>

  Check the integrity of FASTQ files

  <FQFILE>                     the forward read file
  <REV>                        the reverse read file
  <FQDIR>                      the directory containing the FASTQ files

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
* 
### Exit status

If an error is identified in at least one file, the program will exit with non zero status.

### Output



