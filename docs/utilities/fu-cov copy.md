
# fu-secheck

A program to check a single FASTQ file

```text
Usage: fu-secheck [-s] [-o offset] filename

Parameters:
 -s            : Validate quality (optional).
 -o OFFSET     : The offset for quality score (optional, default: 33).
 filename      : The name of the file to be processed (optional, default: stdin)
```

## Input

A FASTQ file, compressed or not, or STDIN.

## Output

A four column table with the following columns:

1. Status (`OK` or `ERR`)
2. Number of sequences counted
3. Name of the first read
4. Name of the last read

This output allows to use the module to check for the integrity of paired-end
reads as well, comparing the number of sequences and the first and last read