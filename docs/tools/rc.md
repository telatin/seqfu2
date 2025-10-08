---
layout: default
title: seqfu rc
parent: Core Tools
---


# seqfu rc

*rc*  is one of the core subprograms of *SeqFu*, that allows 
to print the _reverse complement_ of sequences, either from
input files or provided as strings. IUPAC DNA characters allowed.

```text
Usage: rc [options] [<strings-or-files>...] 

Print the reverse complementary of sequences in files or sequences
given as parameters

Options:
  -s, --seq-name NAME    Sequence name if coming as string [default: string]
  --strip-comments       Remove sequence comments
  -v, --verbose          Verbose output
  --help                 Show this help
```

## Reverse complement strings

To print the reverse complement of sequence, for example of universal primers with degenerate bases:
```
seqfu rc CCTACGGGNGGCWGCAG GGACTACHVGGGTATCTAATCC
```

will produce:
```text
>string_1
CTGCWGCCNCCCGTAGG
>string_2
GGATTAGATACCCBDGTAGTCC
```

**Note**: if a single sequence (string) is provided, the output is not in FASTA format but a plain string. This makes easier
a programmatic use like:
```bash
removePrimersScript.sh --for $FOR --rev $(seqfu rc $REV)
```

## Reverse commplement files
When supplying input files, the whole file will be complemented. If the file is in FASTQ format the 
quality will be reversed as well. The program can process multiple files.
```
seqfu rc data/test.fasta
```

will produce:
```text
>SEQ1_BamHI-EcoRI
ACGTGTACCAGCTACGATCGTGTGTAGCTAGCTCGTCAGCTAGCTACGTCGATCACGTACGCTGT
>Seq2 with comm
GTGTGTGTGTGTGTGTGTGTGTGTGTGTGTGT
>Seq3
GGGGGGGGGGGGGGGGGGGGG
```


