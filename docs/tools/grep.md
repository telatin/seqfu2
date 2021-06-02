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


## Get sequences by name

In a sequence the name, or id, is the string before the first white space
character, while we define as comment all the rest:
```text
>Seq_Name_Here  after the name or ID, everything else is the comment
ATTACAAACAGTCGATCGTAGCTAGCTAGCTGATC
```


To extract all the sequences containing "Here" in the name:
```
seqfu grep -n Here file.fasta
```

If we also want to extend the search to comments we need to add the `-c` (or `--comment`) switch:
```
seqfu grep -c -n extend file.fasta
```

Finally, [regular expressions](https://www.regular-expressions.info/)
are supported only enabling `-r` (or `--regex`):
```
seqfu grep -r -n Seq_N..._ file.fasta
```


## Matching patterns in DNA sequences

A simple text search (even with regular expressions) cannot be 
a handy way to identify matches in a DNA/RNA sequence.

Using the `-o` (`--oligo`) parameter, we scan the sequence for matches 
of oligonucleotides supporting [IUPAC degenerate bases](https://www.bioinformatics.org/sms/iupac.html),
supporting **reverse complement** matches and partial matches.

```text
>Example
CAGATAAAA
```

if we scan for `TTTT` we will match the sequence, as it's in the reverse complement strand:
```
seqfu -o TTTT file.fasta
```

We can also use IUPAC bases (N for any base, B for C, G or A...):
```
seqfu -o TTTTNT file.fasta
```
