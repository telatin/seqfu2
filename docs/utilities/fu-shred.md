---
title: fu-shred
summary: "Deprecated launcher that forwards its arguments to seqfu shred."
category: transform
input: [FASTA, FASTQ]
output: "FASTQ or FASTA"
wrapper: true
wraps: seqfu shred
deprecated: true
experimental: false
paired: false
interactive: false
---

The `fu-shred` binary is deprecated: it forwards all of its arguments to [`seqfu shred`]({{ '/tools/shred.html' | relative_url }}), which is the preferred command.

```bash
# Legacy
fu-shred -l 150 -s 50 genome.fa > reads.fq

# Preferred
seqfu shred -l 150 -s 50 genome.fa > reads.fq
```

Since SeqFu 1.30 the `fu-readtope` script has also been replaced, by `seqfu shred --amplicon`.
