---
sort: 11
---

# fu-homocom

Remove all the homopolymers from FASTA and FASTQ files. The output format is the same of
the input

```text
Usage: fu-homocompress [options] [<fastq-file>...]
 
  Other options:
    --pool-size INT            Number of sequences to process per thread [default: 50]
    --max-threads INT          Maxiumum number of threads to use [default: 4]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
```


## Example input and output
 
```
@polya
ACGTACACGTGACGAAAAAAAAAAAAAACGT
+
IIIIIIIIIIIIIII!!!!!!!!!!!!!III
```

will be printed as

```
@polya
ACGTACACGTGACGACGT
+
IIIIIIIIIIIIIIIIII
```