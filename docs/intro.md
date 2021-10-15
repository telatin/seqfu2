---
sort: 2
permalink: /intro
---

# Overview

## Basic operations: cat, head, tail, grep, rc

These commands have been inspired by the common *GNU commands*, and all can
read from the standard input.

Their usage is quite intuitive, so here we highlight some special feature.

**[seqfu cat]({{site.baseurl}}/tools/cat.html)** can read mixed FASTA and FASTQ files, and be forced to output in either FASTA or FASTQ format. Some basic manipulations are bundled, like:

* Forcing FASTA or FASTQ output
* Manipulating sequence name (prefix, suffix, prepend filename, remove comments...)
* Add infos in the header (length, gc content, original name)
* Filter by length (minimum length, maximum length, trim bases at the beginning or the end...)
* ...

**[seqfu grep]({{site.baseurl}}/tools/grep.html)** can be used to extract sequences by matching oligonucleotides, that would be scanned also in the reverse strand and allowing for mismatches or partial matches. The oligo can be in IUPAC alphabet with ambiguous bases (e.g. degenerate primers).

**[seqfu head]({{site.baseurl}}/tools/head.html)** can skip a number of sequences (_i. e._ print the first _N_ sequences
taking one every _M_), to extract a small subset sampling deeper.

The _reverse complement_ function (**[seqfu rc]({{site.baseurl}}/tools/rc.html)**) is unique in taking as input both
files and sequences, and properly supports IUPAC degenerate bases.

## Getting an idea: view, qual, stats, count...

**[seqfu view]({{site.baseurl}}/tools/view.html)** is only for interactive use, and can be used to have a visual
feedback on the quality values and on the presence of oligonucleotides:

![View]({{site.baseurl}}/img/view.png)

**[seqfu stats]({{site.baseurl}}/tools/stats.html)** can print the total number of sequences, bases, average, N50, N75, N90 and AuN, minimum and maximum length of a dataset, both in TSV format and with a nicer console oriented output:

```
┌─────────────────────────┬───────┬──────────┬───────┬─────┬─────┬─────┬────────┬─────┬─────┐
│ File                    │ #Seq  │ Total bp │ Avg   │ N50 │ N75 │ N90 │ auN    │ Min │ Max │
├─────────────────────────┼───────┼──────────┼───────┼─────┼─────┼─────┼────────┼─────┼─────┤
│ data/filt.fa.gz         │ 78730 │ 24299931 │ 308.6 │ 316 │ 316 │ 220 │ 0.385  │ 180 │ 485 │
│ data/illumina_1.fq.gz   │ 7     │ 630      │ 90.0  │ 90  │ 90  │ 90  │ 12.857 │ 90  │ 90  │
│ data/illumina_2.fq.gz   │ 7     │ 630      │ 90.0  │ 90  │ 90  │ 90  │ 12.857 │ 90  │ 90  │
│ data/illumina_nocomm.fq │ 7     │ 630      │ 90.0  │ 90  │ 90  │ 90  │ 12.857 │ 90  │ 90  │
└─────────────────────────┴───────┴──────────┴───────┴─────┴─────┴─────┴────────┴─────┴─────┘
```

## Managing datasets: interleave, deinterleave, lanes

Very common tasks when dealing with Illumina Paired-End sequences are
interleaving and deinterleaving the datasets. 

**[seqfu interleave]({{site.baseurl}}/tools/interleave.html)** and **[seqfu deinterleave]({{site.baseurl}}/tools/deinterleave.html)** can do that, with high speed and lower corruption risks.

Multiple lanes can be quickly merged with **[seqfu lanes]({{site.baseurl}}/tools/merge_lanes.html)**.

## Sorting, dereplicating

**[seqfu sort]({{site.baseurl}}/tools/sort.html)** can sort sequences by length.

**[seqfu derep]({{site.baseurl}}/tools/derep.html)** can be used to dereplicate
datasets, printing the number of identical sequences. In particular, this information
can be used also from the input dataset, allowing to dereplicating a set of dereplicated files keeping trace of the number of sequences.

