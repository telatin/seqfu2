---
layout: default
title: seqfu subtract
parent: Core Tools
nav_order: 27
---


# seqfu subtract

*subtract* is a subprogram of *SeqFu* that prints sequences present in a
first file but **absent** from a second file — the set difference A \ B.

By default the tool enforces that every sequence in `<file2>` is also
present in `<file1>` (i.e. `<file2>` is a strict subset of `<file1>`).
Use `--relaxed` to relax this requirement.

```text
Usage: subtract [options] <file1> <file2>

Print sequences from <file1> that are not present in <file2>.
By default, every sequence in <file2> must be present in <file1>
(i.e. <file2> is a strict subset of <file1>); exit with error otherwise.

Options:
  -s, --by-seq          Match by sequence content instead of name
  -r, --relaxed         Don't error if sequences in <file2> are absent from <file1>
  -c, --strip-comment   Ignore name suffix after first space when matching
  -p, --strip-pair      Ignore /1 or /2 pair suffixes in names when matching
  -v, --verbose         Print stats summary to stderr
  --help                Show this help
```

## Basic usage

Given `all.fa` with sequences A, B, C, D and `subset.fa` with sequences B and D:

```bash
seqfu subtract all.fa subset.fa
```

Output: sequences A and C (in the same order they appear in `all.fa`).

The format (FASTA or FASTQ) is preserved from the input, including quality
scores when subtracting FASTQ files.

## Modes

### Strict mode (default)

By default `subtract` enforces that `<file2>` is a strict subset of `<file1>`.
If any sequence name in `<file2>` is not found in `<file1>`, the program
exits with a non-zero status and prints an error:

```text
ERROR: sequence in <file2> not found in <file1>: mystery_seq
ERROR: 1 sequence(s) from <file2> were not present in <file1>.
Use --relaxed to suppress this error.
```

This makes `subtract` safe to use in pipelines where an unexpected mismatch
should be caught early.

### Relaxed mode (`--relaxed`)

When `<file2>` may contain names that do not appear in `<file1>` — for
example when working with partial or heterogeneous datasets — use
`--relaxed` to suppress the error and continue:

```bash
seqfu subtract --relaxed all.fa external_list.fa
```

## Matching by sequence content (`--by-seq`)

By default matching is done by **sequence name**. With `--by-seq` the match
key is the sequence content (case-insensitive MD5 hash), so a sequence is
subtracted regardless of what it is named:

```bash
seqfu subtract --by-seq assembly.fa contaminants.fa
```

This is useful when the same sequence appears under different names in the
two files, e.g. after re-assembly or database searches.

## Handling sequence comments (`--strip-comment`)

FASTA/FASTQ headers often contain a description after the first space:

```
>contig_42 len=1234 cov=98.3
```

By default the **full** header (name + comment) is used as the match key,
so `contig_42` and `contig_42 len=1234 cov=98.3` are treated as different
identifiers. Use `--strip-comment` to match on the name portion only
(everything before the first space):

```bash
seqfu subtract --strip-comment assembly.fa names_only.fa
```

## Handling paired-end suffixes  

Paired-end reads are commonly named with `/1` and `/2` suffixes. Use
`--strip-pair` to strip these suffixes before matching, so that `read_42/1`
in `<file1>` is matched by `read_42` in `<file2>`:

```bash
seqfu subtract --strip-pair reads_R1.fq filtered.fq
```

 
## Verbose output

Use `-v` / `--verbose` to print a short summary to stderr:

```text
Sequences loaded from file2: 4
Total sequences in file1:    12
Subtracted:                   4
Printed:                      8
```
