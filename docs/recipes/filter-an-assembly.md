---
title: Filter and rename an assembly
summary: Assess an assembly, drop short or low-coverage contigs, and give the survivors clean names.
order: 6
level: intermediate
input: [FASTA]
tools: [seqfu stats, fu-cov, seqfu cat]
---

## 1. Assess the assembly

```bash
seqfu stats -b --gc --index contigs.fa
```

```text
File	#Seq	Total bp	Avg	N50	N75	N90	auN	Min	Max	%GC	L50	L75	L90
contigs	40	34563	864.08	1522	513	397	2547.14	208	7585	0.46	6	19	30
```

`--index` adds the L50/L75/L90 contig counts and `--gc` the GC content.

## 2. Filter by length and coverage

Assemblers such as SPAdes, MEGAHIT, Unicycler and Shovill write the coverage of each contig
in its name. [`fu-cov`]({{ '/utilities/fu-cov.html' | relative_url }}) reads it and filters on it:

```bash
fu-cov -c 10 -l 500 contigs.fa > filtered.fa
```

```text
9/40 sequences printed (40 with coverage info) from 1 files.
Skipped:          2 too short, 0 too long, then 29 low coverage, 0 high coverage, .
Total size:       10258/34563 bp printed (29.7%)
```

`fu-cov -s -t 10 contigs.fa` prints the ten contigs with the highest coverage instead.

## 3. Rename the contigs

Many downstream tools prefer short, simple names.
[`seqfu cat`]({{ '/tools/cat.html' | relative_url }}) replaces the name with a prefix and a
zero-padded counter, drops the comments, and can save the old-to-new mapping:

```bash
seqfu cat -z -p ctg --zero-pad 4 -s --report rename.tsv filtered.fa > final.fa
head -n 1 final.fa
```

```text
>ctg0001
```

For [anvi'o](https://anvio.org), `seqfu cat --anvio` applies its naming rules in one go.
