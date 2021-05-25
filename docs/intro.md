---
sort: 3
permalink: /intro
---

# Overview

## Basic operations: cat, head, tail, grep, rc

These commands have been inspired by the common GNU commands, and all can
read from the standard input.
Some special features: **[seqfu cat]({{site.baseurl}}/tools/cat.html)** can read mixed FASTA and FASTQ files, and be
forced to output in either FASTA or FASTQ format.
**[seqfu grep]({{site.baseurl}}/tools/grep.html)** can be used to extract sequences by matching oligonucleotides, that
would be scanned also in the reverse strand and allowing for mismatches or partial
matches.
**[seqfu head]({{site.baseurl}}/tools/head.html)** can skip a number of sequences (_i. e._ print the first _N_ sequences
taking one every _M_), to extract a small subset sampling deeper.
The _reverse complement_ function (**[seqfu rc]({{site.baseurl}}/tools/rc.html)**) is unique in taking as input both
files and sequences, and properly supports IUPAC degenerate bases.

## Getting an idea: view, qual

**[seqfu view({{site.baseurl}}/tools/view.html)** is only for interactive use, and can be used to have a visual
feedback on the quality values and on the presence of oligonucleotides:

![View]({{site.baseurl}}/img/view.png)

## Managing datasets: interleave, deinterleave, lanes

Very common tasks when dealing with Illumina Paired-End sequences are
interleaving and deinterleaving the datasets. **[seqfu interleave]({{site.baseurl}}/tools/interleave.html)** and **[seqfu deinterleave]({{site.baseurl}}/tools/deinterleave.html)** can do that, with high speed and lower corruption risks.
Multiple lanes can be quickly merged with **[seqfu lanes]({{site.baseurl}}/tools/merge_lanes.html)**.