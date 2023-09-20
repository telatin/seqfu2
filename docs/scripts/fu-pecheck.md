
# fu-split

```note
Preliminary version
```

A program to check the integrity of Paired End FASTQ files.

```text
usage: fu-pecheck [-h] [--for-tag FOR_TAG] [--rev-tag REV_TAG] [--verbose] [--version] DIR

Validate FASTQ files

positional arguments:
  DIR                Input directory

optional arguments:
  -h, --help         show this help message and exit
  --for-tag FOR_TAG  Tag to use for the forward reads output (default: _R1)
  --rev-tag REV_TAG  Tag to use for the forward reads output (default: _R2)
  --verbose          Verbose output
  --version          show program's version number and exit
```

This script runs `fu-secheck` twice and compare the results,
and will print a five column table with the following columns:

1. Sample basename
2. Status (`OK` or `ERR`)
3. Number of reads or "None" if the file is corrupt
4. Name of the first read
5. Name of the last read

