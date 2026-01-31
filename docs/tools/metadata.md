---
layout: default
title: seqfu metadata
parent: Core Tools
nav_order: 14
---

# seqfu metadata

Given one (or more) directories containing sequencing reads, this tool produces a metadata file by extracting the ID from the filename and optionally adding file paths or read counts.

## Usage
```
Usage: 
  metadata [options] [<dir>...]
  metadata formats

Prepare mapping files from directory containing FASTQ files

Options:
  -1, --for-tag STR      String found in filename of forward reads [default: _R1]
  -2, --rev-tag STR      String found in filename of forward reads [default: _R2]
  -s, --split STR        Separator used in filename to identify the sample ID [default: _]
  --pos INT...           Which part of the filename is the Sample ID [default: 1]

  -f, --format TYPE      Output format: dadaist, irida, manifest,... list to list [default: manifest]
  -p, --add-path         Add the reads absolute path as column 
  -c, --counts           Add the number of reads as a property column (experimental)
  -t, --threads INT      Number of simultaneously opened files (legacy: ignored) 
  --pe                   Enforce paired-end reads (not supported)
  --ont                  Long reads (Oxford Nanopore) [default: false]

  GLOBAL OPTIONS
  --abs                  Force absolute path
  --basename             Use basename instead of full path
  --force-tsv            Force '\t' separator, otherwise selected by the format
  --force-csv            Force ',' separator, otherwise selected by the format
  -R, --rand-meta INT    Add a random metadata column with INT categories

  FORMAT SPECIFIC OPTIONS
  -P, --project INT      Project ID (only for irida)
  --meta-split STR       Separator in the SampleID to extract metadata, used in MetaPhage [default: _]
  --meta-part INT        Which part of the SampleID to extract metadata, used in MetaPhage [default: 1]
  --meta-default STR     Default value for metadata, used in MetaPhage [default: Cond]

  -v, --verbose          Verbose output
  --debug                Debug output
  -h, --help             Show this help

```

## Output formats

SeqFu metadata now supports the following output formats:

1. **manifest**: Used as import manifest for [Qiime2](https://qiime2.org/) artifacts.
2. **qiime1**: Forward-compatible [Qiime1](http://qiime.org/) mapping file.
3. **qiime2**: [Qiime2](https://qiime2.org/) metadata file.
4. **dadaist**: [Dadaist2](https://quadram-institute-bioscience.github.io/dadaist2) compatible metadata.
5. **lotus**: [Lotus](http://lotus2.earlham.ac.uk/) mapping file (tested with Lotus1).
6. **irida**: [IRIDA uploader](https://github.com/phac-nml/irida-uploader) sample sheet. Requires `-P PROJECTID`.
7. **metaphage**: [MetaPhage](https://mattiapandolfovr.github.io/MetaPhage) metadata file. Use `--meta-split`, `--meta-part`, and `--meta-default` to customize a Treatment column.
8. **ampliseq**: [nf-core/ampliseq](https://nf-co.re/ampliseq) metadata file.
9. **rnaseq**: [nf-core/rnaseq](https://nf-co.re/rnaseq) metadata file.
10. **bactopia**: [Bactopia](https://bactopia.github.io/) FOFN (File of File Names) file.
11. **mag**: [nf-core/mag](https://nf-co.re/mag) metadata file.

## New Features

- Support for `--format bactopia` to generate Bactopia FOFN files.
- Added `--ont` option for long reads (Oxford Nanopore Technology).
- Enhanced support for various bioinformatics pipelines (ampliseq, rnaseq, mag).

## Examples

### Manifest (default)

```bash
seqfu metadata ./MiSeq_SOP/
```

Output:
```
sample-id	forward-absolute-filepath	reverse-absolute-filepath
F3D0	/Users/telatin/MiSeq_SOP/F3D0_S188_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D0_S188_L001_R2_001.fastq.gz
F3D1	/Users/telatin/MiSeq_SOP/F3D1_S189_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D1_S189_L001_R2_001.fastq.gz
...
```

### Qiime1 mapping file

```bash
seqfu metadata MiSeq_SOP -f qiime1 --add-path --counts
```

Output:
```
#SampleID	Counts	Paths
F3D0	7793	F3D0_S188_L001_R1_001.fastq.gz,F3D0_S188_L001_R2_001.fastq.gz
F3D1	5869	F3D1_S189_L001_R1_001.fastq.gz,F3D1_S189_L001_R2_001.fastq.gz
...
```

### IRIDA uploader

```bash
seqfu metadata -f irida -P 123 data/pe/
```

Output:
```
Sample_Name,Project_ID,File_Forward,File_Reverse
sample1,123,sample1_R1.fq.gz,sample1_R2.fq.gz
sample2,123,sample2_R1.fq.gz,sample2_R2.fq.gz
```

### Bactopia FOFN

```bash
seqfu metadata -f bactopia data/pe/
```

For ONT data, add `--ont`

Output:
```
sample	runtype	r1	r2
sample1	paired-end	/path/to/data/pe/sample1_R1.fq.gz	/path/to/data/pe/sample1_R2.fq.gz
sample2	paired-end	/path/to/data/pe/sample2_R1.fq.gz	/path/to/data/pe/sample2_R2.fq.gz
```

## Notes

- Use `--add-path` to include full file paths in the output (when supported by the format).
- The `--counts` option adds read counts to the output (experimental feature, not supported by all formats).
- Format-specific options (like `--project` for IRIDA) are required for certain output types.
- Use `--verbose` for detailed processing information and `--debug` for troubleshooting.

For more information on each format and its specific options, please refer to the respective tool's documentation.