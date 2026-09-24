---
title: Dereplicate amplicon reads
summary: Collapse identical sequences, keep their abundance, and carry the counts across multiple rounds of dereplication.
order: 4
level: intermediate
input: [FASTA, FASTQ]
tools: [seqfu derep, seqfu sort, seqfu stats, seqfu grep]
---

Amplicon datasets contain many identical reads. Dereplicating them (keeping one copy of
each unique sequence plus its abundance) makes clustering and denoising much faster.

## 1. Dereplicate

[`seqfu derep`]({{ '/tools/derep.html' | relative_url }}) prints unique sequences sorted by
abundance, with the abundance in the name in the `;size=N` format understood by USEARCH and
VSEARCH:

```bash
seqfu derep reads.fa.gz > uniques.fa
head -n 1 uniques.fa
```

```text
>seq.1;size=18335
```

Use `--json derep.json` to save the mapping between input and output sequences, or `-c` to
write the size as a comment instead of in the name.

## 2. Drop singletons

Sequences seen only once are often errors. `--min-size` keeps only the abundant ones:

```bash
seqfu derep -m 2 reads.fa.gz > uniques.min2.fa
```

```text
Skipped 13575 clusters having less than 2 sequences.
```

## 3. Dereplicate across samples

`derep` reads the `size=` annotations of its input, so files that were dereplicated
separately can be combined without losing the original counts:

```bash
for f in samples/*.fa.gz; do
  seqfu derep "$f" > "derep/$(basename "$f" .fa.gz).fa"
done
seqfu derep derep/*.fa > all_uniques.fa
```

Add `--ignore-size` if you want each input record to count as one.

## 4. Inspect the result

```bash
# How many unique sequences, and how long?
seqfu stats -n uniques.min2.fa

# Longest first (sort also removes duplicates)
seqfu sort uniques.min2.fa | head -n 2

# Which uniques contain the forward primer?
seqfu grep -o CCTACGGGNGGCWGCAG uniques.min2.fa
```
