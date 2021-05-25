---
sort: 8
---
# seqfu grep

*grep*  is one of the core subprograms of *SeqFu*.

It can be used to select sequences by their name, comments or
sequence using IUPAC degenerate oligo as query.

```text
Usage: grep [options] [<inputfile> ...]

Print sequences selected if they match patterns or contain oligonucleotides

Options:
  -n, --name STRING      String required in the sequence name
  -r, --regex PATTERN    Pattern to be matched in sequence name
  -c, --comment          Also search -n and -r in the comment
  -c, --comment STRING   String required in the sequence comment
  -o, --oligo IUPAC      Oligonucleotide required in the sequence,
                         using ambiguous bases and reverse complement
  --max-mismatches INT   Maximum mismatches allowed [default: 0]
  --min-matches INT      Minimum number of matches [default: oligo-length]
  -v, --verbose          Verbose output
  --help                 Show this help
```