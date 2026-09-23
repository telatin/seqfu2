---
layout: default
title: seqfu by-seq
parent: Core Tools
---

# seqfu by-seq

```text
Usage:
  by-seq [options] [-e PATTERN]... [<item>...]

Select FASTA/FASTQ records by sequence. Without -e/-f, the first positional
item is the pattern; remaining items are input files. Default: IUPAC DNA,
forward strand, at least one site per pattern and mate.

Patterns:
  -e, --pattern PATTERN       Add a pattern; may be repeated
  -f, --patterns-file FILE    Read patterns or name<TAB>pattern lines
  --logic MODE               Combine patterns: any|all [default: any]
  --regex                    Use pure-Nim regular expressions
  --literal                  Use literal strings instead of IUPAC DNA
  --case-sensitive           Match letter case

Biological matching:
  --strand MODE              Search forward|reverse|both [default: forward]
  -m, --max-mismatches INT   Maximum substitutions per site (default: 0)
  --circular                 Allow matches across the sequence origin
  --occurrences INT          Require exactly INT sites per pattern and mate
  --min-occurrences INT      Minimum sites per pattern and mate
  --max-occurrences INT      Maximum sites per pattern and mate
  -v, --invert-match         Invert final selection

Input:
  <item>...                  Pattern then files, or files with -e/-f
  -1, --r1 FILE             Paired-end R1 FASTQ
  -2, --r2 FILE             Paired-end R2 FASTQ
  --interleaved             Treat one input as interleaved FASTQ

Paired selection:
  --pair-mode MODE           Match each pattern in any|both mates [default: any]

Output:
  -o, --output FILE          Write to FILE (gzip if .gz)
  -O, --output-r2 FILE       Write selected R2 reads to FILE
  --interleaved-output       Keep paired output interleaved
  --hits FILE                Write sites for selected records as TSV
  --gzip-level INT           Gzip compression level [default: 6]

Performance:
  -t, --threads INT          Worker threads [default: 1]
  --batch-size INT           Records or pairs per batch [default: 4096]

Other:
  --stats                    Print processed and selected counts to stderr
  --verbose                  Print input and output routing to stderr
  -h, --help                 Show this help
```

`by-seq` selects FASTA/FASTQ records by sequence. The default is a
case-insensitive IUPAC DNA search on the forward strand. Use
[`by-id`]({{site.baseurl}}/tools/by-id.html) or
[`by-comment`]({{site.baseurl}}/tools/by-comment.html) for header fields.

```bash
seqfu by-seq ACGTR reads.fastq.gz
seqfu by-seq -e ACGTR -e TTYGCA --logic all reads.fastq.gz
seqfu by-seq --regex -e 'A[CG]T' reads.fastq.gz
```

With no `-e` or `-f`, the first positional argument is the pattern and the
rest are input files. With `-e` or `-f`, all positional arguments are input
files. Omit input or use `-` to read stdin. A pattern file has one pattern
per line, or `name<TAB>pattern`; blank and `#` lines are ignored.

## Biological matching

IUPAC queries accept `ACGTRYSWKMBDHVN`. A query `N` matches any canonical
base, but an ambiguous base in the read (including `N`) makes that candidate
site ineligible. `--literal` searches actual characters, including read `N`.
`--case-sensitive` respects soft masking.

```bash
seqfu by-seq -e AGT --strand reverse reads.fastq.gz
seqfu by-seq -e AGT --strand both -m 1 reads.fastq.gz
seqfu by-seq -e TTGG --circular plasmids.fa
```

Reverse search reverse-complements the query, not the output read. `-m` allows
substitutions only; there are no indels. `--circular` allows one origin-crossing
match, but patterns longer than a molecule never match. Reverse search with
`--literal` requires an `A/C/G/T` pattern. Regex mode is forward-only and
cannot be combined with mismatches or circular search.

## Count sites

The default selects reads with at least one site per pattern. Sites are
full-length matches at distinct start coordinates; overlaps count. A site
matching both strands counts once, including palindromes. Linear `AAA` has
three sites in `AAAAA`; circular search has five.

```bash
seqfu by-seq AAA --occurrences 1 reads.fa
seqfu by-seq AAA --occurrences 0 reads.fa
seqfu by-seq AAA --min-occurrences 2 --max-occurrences 5 reads.fa
```

`--occurrences N` means exactly N sites and cannot be combined with minimum
or maximum bounds. Bounds apply separately to every pattern in every mate.
`--logic any|all` combines patterns (default `any`). For paired reads,
`--pair-mode any|both` first combines mates for each pattern (default `any`),
then `--logic` combines patterns. `--invert-match` reverses the final decision.
Regex occurrence counting includes overlapping non-empty matches at distinct
starts; zero-length matches are ignored.

## Paired input and output

Use `-1` and `-2` for separate FASTQ mates, or `--interleaved` for one
interleaved FASTQ stream. Both mates of a selected pair are always retained.
Output defaults to stdout, interleaved for pairs.

```bash
seqfu by-seq -e ACT --pair-mode both -1 reads_R1.fq.gz -2 reads_R2.fq.gz \
  -o selected_R1.fq.gz -O selected_R2.fq.gz
seqfu by-seq -e ACT --interleaved paired.fq.gz -o selected.fq.gz
```

If only `-o` is supplied for pairs, `_R1` to `_R2` or `_1.` to `_2.` infers
the second output path. Otherwise the output is interleaved. Use
`--interleaved-output` to override inference. A `.gz` suffix compresses each
output independently.

## Hit report and threads

`--hits FILE` writes sites from selected records to a separate TSV file;
`.gz` compresses it. Columns are `input`, `record`, `mate`, `pattern`,
`strand`, `start`, `end`, `mismatches`, and `wraps`. Coordinates are zero-based
and half-open on the original read. For a wrapping site, `end` is the position
after the match modulo the read length and `wraps` is `true`.

```bash
seqfu by-seq -e TTGG --circular --hits sites.tsv.gz plasmids.fa \
  -o selected.fa.gz
seqfu by-seq -e ACGTR -t 4 --batch-size 4096 reads.fastq.gz \
  -o selected.fastq.gz
```

The default `-t 1` streams records directly. With more threads, matching runs
in bounded Malebolgia batches; input and output stay on the main thread and
selected records remain in input order.
