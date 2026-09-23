---
layout: default
title: seqfu sort
parent: Core Tools
---

# seqfu sort

*sort*  is one of the core subprograms of *SeqFu*, that allows
sorting FASTA sequences by length, printing only unique sequences
(unless `--keep-duplicates` is used).

```text
Usage: sort [options] [<inputfile> ...]

 Sort FASTA sequences by length, printing only unique sequences.

 All input files are pooled: duplicates are removed across files and
 a single sorted output is printed. When a sequence occurs more than once,
 the name of its first occurrence is kept. Sequences of equal length are
 printed in input order.

 FASTQ is not supported: FASTQ input is accepted, but quality scores are
 discarded and the output is always FASTA.

Options:
  -p, --prefix STRING    Rename sequences as STRING1, STRING2, ...
  -s, --strip-comments   Remove sequence comments
  -k, --keep-duplicates  Keep identical sequences as separate records
  --asc                  Ascending order
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

## Notes

* **FASTQ is not supported.** Sorting is designed for FASTA files. FASTQ files
  are read, but quality scores are dropped and the output is FASTA (a warning
  is printed to the standard error).
* **Multiple files are pooled** into a single sorted output. Without
  `--keep-duplicates`, a sequence present in more than one file is printed once.
* **Duplicates**: identical sequences (case-sensitive comparison) are collapsed
  into the first occurrence, keeping its name and comment. Use
  `--keep-duplicates` to print every record.
* **Ties**: sequences with the same length are printed in the order they
  appear in the input, so the output is reproducible.
* The whole input is loaded in memory before sorting.

## Example

```bash
seqfu sort --asc -p seq_ contigs.fa > sorted.fa
```

## Screenshot

![Screenshot of "seqfu sort"]({{site.baseurl}}/img/screenshot-sort.svg "SeqFu sort")
