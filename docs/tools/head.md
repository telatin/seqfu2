---
sort: 5
---
# seqfu head

*head*  is one of the core subprograms of *SeqFu*.

It will print the first sequences of a FASTX file (like GNU head), but
can be instructed to skip a number of sequences between each printed one.

```text
Usage: head [options] [<inputfile> ...]

Select a number of sequences from the beginning of a file, allowing
to select

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  --help                 Show this help
```

  