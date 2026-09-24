---
title: Inspect a new sequencing run
summary: A first look at a directory of FASTQ files - integrity, read counts, lengths and quality encoding.
order: 1
level: beginner
input: [FASTQ, Directory]
tools: [seqfu check, seqfu count, seqfu stats, seqfu qual, seqfu view]
---

You just received a directory of paired-end FASTQ files. Before starting any analysis,
it is worth spending a minute checking that they are complete and look as expected.

## 1. Check file integrity

[`seqfu check`]({{ '/tools/check.html' | relative_url }}) validates every file in a directory,
pairing R1 and R2 automatically, and returns a non-zero exit status if something is wrong:

```bash
seqfu check --dir reads/
```

```text
OK	PE	reads/sample1_R1.fq.gz	200	27553	0
OK	PE	reads/sample2_R1.fq.gz	200	36372	0
ERR	PE	reads/uneven_R1.fq.gz	-	900	3	Number of sequences in R1 and R2 do not match (7, 3);...
```

Here a truncated pair is caught before it can silently break a downstream tool.

## 2. Count the reads

[`seqfu count`]({{ '/tools/count.html' | relative_url }}) prints one line per sample, and checks
that the two files of each pair contain the same number of reads:

```bash
seqfu count reads/*.fq.gz
```

## 3. Length statistics

[`seqfu stats`]({{ '/tools/stats.html' | relative_url }}) reports lengths (and N50, which is more
useful for assemblies). `-n` prints a table for the terminal, `-b` strips the paths:

```bash
seqfu stats -n -b reads/*_R1*.fq.gz
```

Add `--multiqc stats_mqc.txt` to include the numbers in a [MultiQC](https://multiqc.info) report.

## 4. Quality encoding and profile

[`seqfu qual`]({{ '/tools/qual.html' | relative_url }}) scans the first reads of each file,
reports the possible encodings and the average quality:

```bash
seqfu qual reads/*.fq.gz
```

```text
reads/sample1_R1.fq.gz	11.0	37.0	Sanger;Illumina-1.8;	36.27+/-3.50	87
```

## 5. Eyeball a few reads

Finally, look at some records with coloured quality bars, highlighting a primer
if you expect one:

```bash
seqfu view -o CCTACGGGNGGCWGCAG reads/sample1_R1.fq.gz | less -R
```

For a full-screen, scrollable view use [`seqfu less`]({{ '/tools/less.html' | relative_url }}).
