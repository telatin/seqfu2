
# seqfu metadata

Given one (or more) directories containing sequencing reads,
will produce a metadata file extracting the ID from the filename
and optionally adding the file paths or read counts.

```
Usage: metadata [options] [<dir>...]

Prepare mapping files from directory containing FASTQ files

Options:
  -1, --for-tag STR      String found in filename of forward reads [default: _R1]
  -2, --rev-tag STR      String found in filename of forward reads [default: _R2]
  -s, --split STR        Separator used in filename to identify the sample ID [default: _]
  --pos INT...           Which part of the filename is the Sample ID [default: 1]

  -f, --format TYPE      Output format: dadaist, irida, manifest, metaphage, qiime1, qiime2  [default: manifest]
  --pe                   Enforce paired-end reads (not supported)
  -p, --add-path         Add the reads absolute path as column 
  -c, --counts           Add the number of reads as a property column
  -t, --threads INT      Number of simultaneously opened files [default: 2]

  FORMAT SPECIFIC OPTIONS
  -P, --project INT      Project ID (only for irida)
  --meta-split STR       Separator in the SampleID to extract metadata, used in MetaPhage [default: _]
  --meta-part INT        Which part of the SampleID to extract metadata, used in MetaPhage [default: 1]
  --meta-default STR     Default value for metadata, used in MetaPhage [default: Cond]

  -v, --verbose          Verbose output
  -h, --help             Show this help
```

## Output formats

* manifest (used as import manifest for [Qiime2](https://qiime2.org/) artifacts)
* qiime1, qiime2 (forward-compatible [qiime1](http://qiime.org/) mapping file; a dedicated [Qiime2](https://qiime2.org/) metadata file is under development)
* dadaist ([Dadaist2](quadram-institute-bioscience.github.io/dadaist2) compatible metadata)
* lotus ([Lotus](http://lotus2.earlham.ac.uk/) mapping file - tested with Lotus1)
* irida ([IRIDA uploader](https://github.com/phac-nml/irida-uploader) sample sheet. Requires `-P PROJECTID`)
* metaphage ([MetaPhage](https://mattiapandolfovr.github.io/MetaPhage), use `--meta-split`, `--meta-part` and `--meta-default` to customize a Treatment column)

## Examples

### Manifest

```
seqfu metadata ./MiSeq_SOP/
```

Will produce this output:
```
sample-id	forward-absolute-filepath	reverse-absolute-filepath
F3D0	/Users/telatin/MiSeq_SOP/F3D0_S188_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D0_S188_L001_R2_001.fastq.gz
F3D1	/Users/telatin/MiSeq_SOP/F3D1_S189_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D1_S189_L001_R2_001.fastq.gz
F3D141	/Users/telatin/MiSeq_SOP/F3D141_S207_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D141_S207_L001_R2_001.fastq.gz
F3D142	/Users/telatin/MiSeq_SOP/F3D142_S208_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D142_S208_L001_R2_001.fastq.gz
F3D143	/Users/telatin/MiSeq_SOP/F3D143_S209_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D143_S209_L001_R2_001.fastq.gz
F3D144	/Users/telatin/MiSeq_SOP/F3D144_S210_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D144_S210_L001_R2_001.fastq.gz
F3D145	/Users/telatin/MiSeq_SOP/F3D145_S211_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D145_S211_L001_R2_001.fastq.gz
F3D146	/Users/telatin/MiSeq_SOP/F3D146_S212_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D146_S212_L001_R2_001.fastq.gz
F3D147	/Users/telatin/MiSeq_SOP/F3D147_S213_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D147_S213_L001_R2_001.fastq.gz
F3D148	/Users/telatin/MiSeq_SOP/F3D148_S214_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D148_S214_L001_R2_001.fastq.gz
F3D149	/Users/telatin/MiSeq_SOP/F3D149_S215_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D149_S215_L001_R2_001.fastq.gz
F3D150	/Users/telatin/MiSeq_SOP/F3D150_S216_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D150_S216_L001_R2_001.fastq.gz
F3D2	/Users/telatin/MiSeq_SOP/F3D2_S190_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D2_S190_L001_R2_001.fastq.gz
F3D3	/Users/telatin/MiSeq_SOP/F3D3_S191_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D3_S191_L001_R2_001.fastq.gz
F3D5	/Users/telatin/MiSeq_SOP/F3D5_S193_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D5_S193_L001_R2_001.fastq.gz
F3D6	/Users/telatin/MiSeq_SOP/F3D6_S194_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D6_S194_L001_R2_001.fastq.gz
F3D7	/Users/telatin/MiSeq_SOP/F3D7_S195_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D7_S195_L001_R2_001.fastq.gz
F3D8	/Users/telatin/MiSeq_SOP/F3D8_S196_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D8_S196_L001_R2_001.fastq.gz
F3D9	/Users/telatin/MiSeq_SOP/F3D9_S197_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/F3D9_S197_L001_R2_001.fastq.gz
Mock	/Users/telatin/MiSeq_SOP/Mock_S280_L001_R1_001.fastq.gz	/Users/telatin/MiSeq_SOP/Mock_S280_L001_R2_001.fastq.gz
```

### Qiime mapping file

Note that `-f qiime2` will add a second header line.

```
seqfu metadata MiSeq_SOP -f qiime1 --add-path --counts
```

Output:

```
#SampleID	Counts	Paths
F3D0	7793	F3D0_S188_L001_R1_001.fastq.gz,F3D0_S188_L001_R2_001.fastq.gz
F3D1	5869	F3D1_S189_L001_R1_001.fastq.gz,F3D1_S189_L001_R2_001.fastq.gz
F3D141	5958	F3D141_S207_L001_R1_001.fastq.gz,F3D141_S207_L001_R2_001.fastq.gz
F3D142	3183	F3D142_S208_L001_R1_001.fastq.gz,F3D142_S208_L001_R2_001.fastq.gz
F3D143	3178	F3D143_S209_L001_R1_001.fastq.gz,F3D143_S209_L001_R2_001.fastq.gz
F3D144	4827	F3D144_S210_L001_R1_001.fastq.gz,F3D144_S210_L001_R2_001.fastq.gz
F3D145	7377	F3D145_S211_L001_R1_001.fastq.gz,F3D145_S211_L001_R2_001.fastq.gz
F3D146	5021	F3D146_S212_L001_R1_001.fastq.gz,F3D146_S212_L001_R2_001.fastq.gz
F3D147	17070	F3D147_S213_L001_R1_001.fastq.gz,F3D147_S213_L001_R2_001.fastq.gz
F3D148	12405	F3D148_S214_L001_R1_001.fastq.gz,F3D148_S214_L001_R2_001.fastq.gz
F3D149	13083	F3D149_S215_L001_R1_001.fastq.gz,F3D149_S215_L001_R2_001.fastq.gz
F3D150	5509	F3D150_S216_L001_R1_001.fastq.gz,F3D150_S216_L001_R2_001.fastq.gz
F3D2	19620	F3D2_S190_L001_R1_001.fastq.gz,F3D2_S190_L001_R2_001.fastq.gz
F3D3	6758	F3D3_S191_L001_R1_001.fastq.gz,F3D3_S191_L001_R2_001.fastq.gz
F3D5	4448	F3D5_S193_L001_R1_001.fastq.gz,F3D5_S193_L001_R2_001.fastq.gz
F3D6	7989	F3D6_S194_L001_R1_001.fastq.gz,F3D6_S194_L001_R2_001.fastq.gz
F3D7	5129	F3D7_S195_L001_R1_001.fastq.gz,F3D7_S195_L001_R2_001.fastq.gz
F3D8	5294	F3D8_S196_L001_R1_001.fastq.gz,F3D8_S196_L001_R2_001.fastq.gz
F3D9	7070	F3D9_S197_L001_R1_001.fastq.gz,F3D9_S197_L001_R2_001.fastq.gz
Mock	4779	Mock_S280_L001_R1_001.fastq.gz,Mock_S280_L001_R2_001.fastq.gz
```

### IRIDA uploader

```
seqfu metadata -f irida  -P 123 data/pe/
```

Output:
```
Sample_Name,Project_ID,File_Forward,File_Reverse
sample1,123,sample1_R1.fq.gz,sample1_R2.fq.gz
sample2,123,sample2_R1.fq.gz,sample2_R2.fq.gz
```


## Screenshot

![Screenshot of "seqfu metadata"]({{site.baseurl}}/img/screenshot-metadata.svg "SeqFu metadata")