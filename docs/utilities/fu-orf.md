---
title: fu-orf
summary: "Compatibility wrapper for seqfu orf."
category: analysis
input: [FASTA, FASTQ]
output: "FASTA (protein)"
wrapper: true
wraps: seqfu orf
deprecated: false
experimental: false
paired: false
interactive: false
---

`fu-orf` is a compatibility wrapper for `seqfu orf`.

Preferred command:

```bash
seqfu orf [options] <InputFile>
seqfu orf [options] -1 File_R1.fq
seqfu orf [options] -1 File_R1.fq -2 File_R2.fq
```

Legacy equivalent:

```bash
fu-orf [options] <InputFile>
fu-orf [options] -1 File_R1.fq
fu-orf [options] -1 File_R1.fq -2 File_R2.fq
```

Both commands share the same behavior and options, including:

* ORF extraction parameters (`--min-size`, `--scan-reverse`, `--code`, `--translate`)
* Paired-end joining controls (`--join`, `--min-overlap`, `--max-overlap`, `--min-identity`)
* batching controls (`--pool-size`, `--in-flight-batches`)

## See also

For full documentation and examples, see **[seqfu orf]({{site.baseurl}}/tools/orf.html)**.
