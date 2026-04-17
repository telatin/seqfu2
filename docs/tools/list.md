---
layout: default
title: seqfu list
parent: Core Tools
---


# seqfu list

Extract sequences from sequence files using a list of requested items.
Introduced in **SeqFu 1.8**.

```text
Usage: list [options] <LIST> <FASTQ>...
       list [options] --outdir <DIR> [--lists <LIST>]... <FASTX>

Classic mode: print sequences from <FASTQ> whose names appear in <LIST>.
Multi mode:   for each --lists file, write matching sequences to a file in
              <DIR> named <listbasename>.<input_extension>.

List files may contain leading ">" or "@" characters.  Duplicated entries
within a list are ignored.  Lines starting with "#" and blank lines are skipped.

Options:
  -c, --with-comments    Include comments when matching sequence names
  -p, --partial-match    Match list entries as substrings of sequence names
  -m, --min-len INT      Skip list entries shorter than INT [default: 1]
  -s, --strict           Exit with error if any listed name was not found
  -v, --verbose          Verbose output
  -r, --report           Print per-list report of found sequences to stderr
  --lists <LIST>         List file for multi-output mode (repeat for each list)
  --outdir <DIR>         Output directory for multi-output mode
  -f, --force            Overwrite existing output files
  --help                 Show this help
```


## Modes

**Classic mode** takes a single list file and one or more sequence files,
printing matching sequences to stdout.

**Multi mode** is activated by `--outdir`. Each `--lists` file is processed
independently and matching sequences are written to a separate file inside
`<DIR>`, named `<listbasename>.<input_extension>` (e.g. `targets.fasta`).
Use `-f`/`--force` to overwrite existing output files.

## Input

List files are plain text files with one sequence name per line.
Leading `>` or `@` characters are stripped before matching.
Blank lines and lines starting with `#` are skipped.
Duplicated entries within a list are silently ignored.

By default only the sequence name (before the first space) is matched.
Use `--with-comments` to include the full header when matching, and
`--partial-match` to treat list entries as substrings of sequence names.

## Output

In classic mode, output is written to stdout in the same format as the
input files (FASTA or FASTQ).

In multi mode, each output file is written to `--outdir` and the format
mirrors the input.

With `--report`, a per-list summary is printed to stderr showing how many
times each requested name was found.  Use `--strict` to exit with a
non-zero status if any listed name was not matched.

Example report:

```
# SEQUENCES REPORT
# Sequence 'protein.1c;size=5372' found 1 times
# Sequence 'protein.1d;size=5372' found 1 times
# Sequence 'protein.missing' found 0 times
# Sequence 'protein.1a;size=5372' found 1 times
# Sequence 'protein.1f;size=5372' found 1 times
# Sequence 'protein.notfound' found 0 times
# Sequence 'protein.1b;size=5372' found 1 times
Total sequences found: 5/7
```
