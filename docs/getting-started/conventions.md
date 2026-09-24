---
title: Common conventions
summary: Behaviour shared by most SeqFu commands, from compressed input to paired-end file naming.
---

## Input formats

* FASTA and FASTQ are detected automatically, and gzip-compressed files are read natively.
  There is no need to specify the format or to decompress first.
* Multi-line FASTA is supported everywhere. Multi-line FASTQ is legal but rare; commands
  that need strict validation (such as `seqfu check --deep`) say so in their help.

## Standard input and output

* Commands that accept files also read the **standard input**: use `-` as the file name, or
  omit the file entirely where the help says so. This makes it easy to chain commands:

  ```bash
  seqfu cat -m 100 reads.fq.gz | seqfu head -n 1000 - | seqfu stats -
  ```

* Output goes to the **standard output** unless an output option is given, so redirect it
  (`> out.fq`) or pipe it into `gzip`.
* Messages, warnings and progress go to the standard error, so they never end up in your data.

## Paired-end files

Commands with paired-end support (`count`, `interleave`, `check`, `metadata`, `trim`...)
detect the second file of a pair from the name of the first. By default they look for the
common Illumina tags `_R1`/`_R2` and fall back to `_1`/`_2`. The tags can be changed with
options such as `--for-tag` and `--rev-tag`.

```text
Sample1_S1_L001_R1_001.fastq.gz   <- forward
Sample1_S1_L001_R2_001.fastq.gz   <- reverse, found automatically
```

## Exit status

Commands return a non-zero exit status on errors (unreadable files, malformed records,
invalid options, validation failures in `check` or `tabcheck`), so they can be used safely
in scripts and workflow managers.

## Help and version

```bash
seqfu                 # list all subcommands
seqfu stats --help    # help for one subcommand
seqfu version         # print the version
seqfu cite            # print the citation
```
