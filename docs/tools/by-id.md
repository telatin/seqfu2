---
title: seqfu by-id
summary: "Select records by identifier, with patterns, lists and numeric-suffix ranges."
category: filter
input: [FASTA, FASTQ]
output: "Same as input"
wrapper: false
deprecated: false
experimental: false
paired: true
interactive: false
related: ["seqfu by-comment", "seqfu by-seq", "seqfu list"]
keywords: "identifier name id list select filter"
---

`by-id` selects FASTA or FASTQ records by identifier (the text before the first
whitespace in a record header). Comments and sequence content are not searched.
For comments, use [`seqfu by-comment`]({{site.baseurl}}/tools/by-comment.html).
Use [`seqfu by-seq`]({{site.baseurl}}/tools/by-seq.html) to select by
biological sequence instead.

```text
Usage:
  by-id [options] [-e PATTERN]... [<item>...]

Matching:
  -e, --pattern PATTERN      Add a pattern; may be repeated
  -f, --patterns-file FILE   Read one pattern per line
  --logic MODE               Combine patterns: any|all [default: any]
  -F, --fixed-string         Treat patterns as literal strings
  -x, --exact                Match complete identifiers
  -i, --ignore-case          Case-insensitive matching
  --strip-pair               Ignore terminal /1 or /2 when matching
  --strip-marker             Ignore leading > or @ in pattern-file entries
  -v, --invert-match         Invert the final selection

Numeric suffix:
  --number-range MIN:MAX     Inclusive numeric interval
  --number-lt INT            Numeric suffix < INT
  --number-le INT            Numeric suffix <= INT
  --number-gt INT            Numeric suffix > INT
  --number-ge INT            Numeric suffix >= INT
  --number-eq INT            Numeric suffix = INT
  --number-regex REGEX       Extract number from first capture group
  --missing-number MODE      drop|keep|error [default: drop]

Input:
  <item>...                  Pattern followed by input files, or files with -e/-f/numeric
  -1, --r1 FILE             Paired-end R1 FASTQ
  -2, --r2 FILE             Paired-end R2 FASTQ
  --interleaved             Treat one input as interleaved FASTQ

Paired selection:
  --pair-mode MODE           Match either or both mates: any|both [default: any]

Output:
  -o, --output FILE          Write to FILE (gzip if .gz)
  -O, --output-r2 FILE       Write selected R2 reads to FILE
  --interleaved-output       Keep paired output interleaved even when -o implies R2
  --gzip-level INT           Gzip compression level [default: 6]

Performance:
  -t, --threads INT          Worker threads [default: 1]
  --batch-size INT           Records or pairs per batch [default: 4096]

Other:
  --stats                    Print processed and selected counts to stderr
  --verbose                  Print input and output routing to stderr
  -h, --help                 Show this help
```

## Match identifiers

A positional pattern is a regular expression matched anywhere in the ID:

```bash
seqfu by-id '^contig_' assembly.fa
```

Use `-e` to supply multiple patterns. They match with OR logic by default;
`--logic all` requires every pattern to match the **same** identifier. `-F`
treats patterns literally, while `-x` requires a complete-ID match.

```bash
seqfu by-id -e '^sample7' -e 'lane2' --logic all reads.fastq.gz
seqfu by-id -F -x -f ids.txt reads.fastq.gz
```

A pattern file has one pattern per line; blank lines and lines beginning with
`#` are skipped. Add `--strip-marker` if its entries begin with `>` or `@`.
Use `-e` with file inputs whenever the positional pattern would be ambiguous.
With no input file, `by-id` reads standard input; `-` names it explicitly.

## Select numeric IDs

By default, numeric options use the final run of decimal digits: `contig_001`
has numeric value 1. Leading zeroes do not change the comparison, and the
original ID is preserved in output. A numeric selector can be used without a
text pattern.

```bash
seqfu by-id --number-range 1:100 assembly.fa
seqfu by-id -e '^contig_' --number-ge 10 --number-lt 20 assembly.fa
```

For structured IDs such as `NODE_25_length_900`, capture the desired number
with `--number-regex` rather than using the final suffix (`900`):

```bash
seqfu by-id -e '^NODE_' --number-regex '^NODE_([0-9]+)_' \
  --number-range 20:40 assembly.fa
```

Text patterns and numeric bounds are combined with AND logic. IDs without a
valid numeric component are dropped by default; `--missing-number keep` retains
them, and `--missing-number error` stops with an error. `-v` inverts the final
selection.

## Paired reads and output

Pass two FASTQ files with `-1` and `-2`, or one interleaved FASTQ file with
`--interleaved`. By default, either mate may match; `--pair-mode both` requires
both mates to satisfy the complete predicate. Selected pairs are always emitted
together, interleaved on standard output unless file output is requested.

```bash
seqfu by-id -e '^sample7' -1 reads_R1.fastq.gz -2 reads_R2.fastq.gz > selected.fastq
seqfu by-id -e '^sample7' --interleaved interleaved.fastq.gz -o selected.fastq.gz
```

Use `-o` and `-O` for separate R1 and R2 output. If only `-o` is given,
`by-id` infers an R2 filename by replacing `_R1` with `_R2` or `_1.` with
`_2.`; otherwise it writes interleaved pairs to the specified file. Add
`--interleaved-output` to override inference. Files ending in `.gz` are
compressed automatically.

```bash
seqfu by-id -F -x -e pair_001 --strip-pair \
  -1 reads_R1.fastq.gz -2 reads_R2.fastq.gz \
  -o selected_R1.fastq.gz -O selected_R2.fastq.gz
```

`--strip-pair` removes terminal `/1` or `/2` for matching and numeric
extraction only; output headers remain unchanged. For more expensive searches,
`-t` enables bounded, ordered parallel matching with Malebolgia. The default
single-thread path streams pointer-backed records without batch copies.
