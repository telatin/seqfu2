---
title: Overview of the commands
summary: A guided tour of what SeqFu can do, grouped by task.
redirect_from:
  - /intro
  - /intro.html
---

SeqFu consists of **core programs**, available as `seqfu` subcommands, and a set of
**utilities** with the `fu-` prefix. Type `seqfu` alone to list the subcommands, and
`seqfu <command> --help` for the help of each one. `seqfu version` prints the version and
`seqfu cite` the paper.

## Basic operations: cat, head, tail, grep, rc

These commands are inspired by the GNU utilities, and all of them can read from the
standard input.

[`seqfu cat`]({{ '/tools/cat.html' | relative_url }}) reads mixed FASTA and FASTQ files, and can
be forced to write either format. It bundles common manipulations:

* renaming sequences (prefix, suffix, file basename, stripping comments...)
* annotating headers with length, GC content, expected errors or the original name
* filtering by length or expected errors, and trimming bases from either end

[`seqfu grep`]({{ '/tools/grep.html' | relative_url }}) extracts records by name, comment or
oligonucleotide. Oligos are searched on both strands, can contain IUPAC degenerate bases
(e.g. primers) and can be matched allowing mismatches. For finer control, use the
[`by-id`]({{ '/tools/by-id.html' | relative_url }}),
[`by-comment`]({{ '/tools/by-comment.html' | relative_url }}) and
[`by-seq`]({{ '/tools/by-seq.html' | relative_url }}) selectors.

[`seqfu head`]({{ '/tools/head.html' | relative_url }}) can skip records between the ones it
prints (i.e. print the first _N_ sequences taking one every _M_), to extract a small subset
that samples deeper into the file.

[`seqfu rc`]({{ '/tools/rc.html' | relative_url }}) is unusual in taking as input both files and
sequences typed on the command line, and supports IUPAC degenerate bases.

## Getting an idea: view, less, qual, stats, count

[`seqfu view`]({{ '/tools/view.html' | relative_url }}) gives visual feedback on quality values
and on the presence of oligonucleotides, and
[`seqfu less`]({{ '/tools/less.html' | relative_url }}) is a full-screen interactive pager:

![seqfu view]({{ '/img/view.png' | relative_url }})

[`seqfu stats`]({{ '/tools/stats.html' | relative_url }}) prints the number of sequences, total
bases, average length, N50, N75, N90, auN, minimum and maximum length, as TSV, CSV, JSON,
MultiQC or a terminal table:

```text
┌───────────────────────┬───────┬──────────┬────────┬─────┬─────┬─────┬────────┬─────┬─────┐
│ File                  │ #Seq  │ Total bp │ Avg    │ N50 │ N75 │ N90 │ auN    │ Min │ Max │
├───────────────────────┼───────┼──────────┼────────┼─────┼─────┼─────┼────────┼─────┼─────┤
│ data/illumina_1.fq.gz │ 7     │ 630      │ 90.00  │ 90  │ 90  │ 90  │ 90.00  │ 90  │ 90  │
│ data/filt.fa.gz       │ 78730 │ 24299931 │ 308.65 │ 316 │ 316 │ 220 │ 318.44 │ 180 │ 485 │
└───────────────────────┴───────┴──────────┴────────┴─────┴─────┴─────┴────────┴─────┴─────┘
```

[`seqfu count`]({{ '/tools/count.html' | relative_url }}) counts reads and pairs R1/R2 files
automatically, [`seqfu qual`]({{ '/tools/qual.html' | relative_url }}) detects the quality
encoding, and [`seqfu check`]({{ '/tools/check.html' | relative_url }}) validates FASTQ files.

## Managing datasets: interleave, deinterleave, lanes, metadata

Interleaving and deinterleaving Illumina paired-end datasets are very common tasks:
[`seqfu interleave`]({{ '/tools/interleave.html' | relative_url }}) and
[`seqfu deinterleave`]({{ '/tools/deinterleave.html' | relative_url }}) do them quickly and
with checks against corrupted pairs.

Multiple lanes are merged with [`seqfu lanes`]({{ '/tools/lanes.html' | relative_url }}), and
[`seqfu metadata`]({{ '/tools/metadata.html' | relative_url }}) writes sample sheets for QIIME 2,
nf-core pipelines, IRIDA and others from a directory of reads.

## Sorting and dereplicating

[`seqfu sort`]({{ '/tools/sort.html' | relative_url }}) sorts sequences by length.
[`seqfu derep`]({{ '/tools/derep.html' | relative_url }}) dereplicates datasets, printing the
number of identical sequences. It also reads that information from its input, so a set of
already dereplicated files can be dereplicated again while keeping track of the original counts.

## Everything else

The [Tools catalogue]({{ '/tools/' | relative_url }}) lists every command and utility, grouped
by task and filterable by input type.
