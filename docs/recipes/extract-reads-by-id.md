---
title: Extract reads by a list of IDs
summary: Pull out (or remove) the records named in a list, keeping paired-end files in sync.
order: 5
level: beginner
input: [FASTA, FASTQ]
tools: [seqfu list, seqfu by-id, seqfu subtract, seqfu count]
---

A classifier, an aligner or a colleague gave you a list of read or contig names, one per
line, and you need the corresponding sequences.

```text
A00709:43:HYG25DSXX:1:1101:3640:1000
A00709:43:HYG25DSXX:1:1101:6189:1000
A00709:43:HYG25DSXX:1:1101:10818:1000
```

## Simple extraction

[`seqfu list`]({{ '/tools/list.html' | relative_url }}) prints the records whose name appears in
the list. Lines starting with `#` are ignored, and names can keep a leading `>` or `@`:

```bash
seqfu list ids.txt reads_R1.fq.gz > selected_R1.fq
```

Add `--strict` to fail if some names are not found, or `--report` for a summary on the
standard error. With `--outdir` and several `--lists`, one output file per list is written
in a single pass.

## Paired-end extraction

[`seqfu by-id`]({{ '/tools/by-id.html' | relative_url }}) selects both mates together, so the two
output files stay in sync:

```bash
seqfu by-id -x -f ids.txt \
  -1 reads_R1.fq.gz -2 reads_R2.fq.gz \
  -o selected_R1.fq -O selected_R2.fq

seqfu count selected_R1.fq selected_R2.fq
```

`-x` requires the whole identifier to match; without it, each entry of the list is searched
as a pattern. Use `--pair-mode both` to require that both mates match.

## The opposite: remove the listed reads

Invert the selection with `-v`:

```bash
seqfu by-id -x -v -f ids.txt reads_R1.fq.gz > remaining_R1.fq
```

If you have the unwanted records as a sequence file rather than as a list,
[`seqfu subtract`]({{ '/tools/subtract.html' | relative_url }}) prints the records of the first
file that are absent from the second:

```bash
seqfu subtract reads_R1.fq.gz selected_R1.fq > remaining_R1.fq
```
