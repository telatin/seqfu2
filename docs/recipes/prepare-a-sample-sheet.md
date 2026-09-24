---
title: Prepare and validate a sample sheet
summary: Generate a metadata or manifest file from a directory of reads and validate it before running a pipeline.
order: 2
level: beginner
input: [Directory, TSV-CSV]
tools: [seqfu metadata, seqfu tabcheck, seqfu check]
---

Most pipelines (QIIME 2, nf-core, Dadaist2...) start from a sample sheet listing the
samples and their files. Writing it by hand is tedious and error-prone.

## 1. Make sure the reads are sound

```bash
seqfu check --dir reads/
```

## 2. Generate the sample sheet

[`seqfu metadata`]({{ '/tools/metadata.html' | relative_url }}) extracts the sample ID from the
file names and pairs R1 and R2. The default format is a QIIME 2 import manifest:

```bash
seqfu metadata reads/ > manifest.tsv
```

```text
sample-id	forward-absolute-filepath	reverse-absolute-filepath
sample1	/data/reads/sample1_R1.fq.gz	/data/reads/sample1_R2.fq.gz
sample2	/data/reads/sample2_R1.fq.gz	/data/reads/sample2_R2.fq.gz
```

Pick another format with `-f`; run `seqfu metadata formats` to list them
(`ampliseq`, `mag`, `rnaseq`, `bactopia`, `irida`, `dadaist`, `lotus`, `qiime1`, `qiime2`...):

```bash
seqfu metadata -f ampliseq reads/ > samplesheet.tsv
```

If the sample ID is not the first `_`-separated part of the file name, change the separator
with `--split` and the part(s) to keep with `--pos`.

## 3. Validate the table

Tables edited in a spreadsheet often end up with a missing or extra column in some rows.
[`seqfu tabcheck`]({{ '/tools/tabcheck.html' | relative_url }}) checks that every row has the
same number of fields, and exits with an error otherwise:

```bash
seqfu tabcheck --header manifest.tsv samplesheet.tsv
```

```text
File	PassQC	Columns	Rows	Separator
manifest.tsv	Pass	3	3	[tab]
samplesheet.tsv	Error[row=2;expected=2;observed=3;reason=inconsistent-column-count]
```

Use `--inspect` on a valid table to see the inferred type of each column.
