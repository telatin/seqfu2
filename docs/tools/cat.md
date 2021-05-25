---
sort: 14
---
# seqfu cat

Concatenate multiple FASTA/FASTQ files, in a similar way of the GNU `cat` utility.

```text
Usage: cat [options] [<inputfile> ...]

Concatenate multiple FASTA or FASTQ files.

Options:
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  -h, --help             Show this help
```


## Input

One or more FASTA or FASTQ files. If no files are provided, the program will read from _standard input_. 
Additionally, you can add _standard input_ to the list of input files
by adding `-`.

## Output
It is possible to mix FASTA and FASTQ files, and by default the program will produce a mixed output. Using `--fasta` or `--fastq` will force a specific output format. For FASTA sequences  a default quality values will be used.