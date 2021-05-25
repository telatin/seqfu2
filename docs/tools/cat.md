---
sort: 14
---
# seqfu cat

Concatenate multiple FASTA/FASTQ files.

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
