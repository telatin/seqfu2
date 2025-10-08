---
layout: default
title: seqfu lanes
parent: Core Tools
---


# seqfu lanes

```note
This function was called `merge` in a pre-release.
```

*lanes*  is one of the core subprograms of *SeqFu*, that allows 
to quickly and easily merge Illumina lanes.

```text
Usage: lanes [options] -o <outdir> <input_directory>

A program to merge Illumina lanes for a whole directory.

Options:
  -o, --outdir DIR           Output directory
  -e, --extension STR        File extension [default: .fastq]
  -s, --file-separator STR   Field separator in filenames [default: _]
  --comment-separator STR    String separating sequence name and its comment [default: TAB]
  -v, --verbose              Verbose output
  -h, --help                 Show this help
```

## Input

A directory containing files in the standard Illumina naming scheme, like:
```
ID1_S99_L001_R1_001.fastq.gz
ID1_S99_L001_R2_001.fastq.gz
ID1_S99_L002_R1_001.fastq.gz
ID1_S99_L002_R2_001.fastq.gz
ID1_S99_L003_R1_001.fastq.gz
ID1_S99_L003_R2_001.fastq.gz
ID1_S99_L004_R1_001.fastq.gz
ID1_S99_L004_R2_001.fastq.gz
ID2_S99_L001_R1_001.fastq.gz
ID2_S99_L001_R2_001.fastq.gz
ID2_S99_L002_R1_001.fastq.gz
ID2_S99_L002_R2_001.fastq.gz
ID2_S99_L003_R1_001.fastq.gz
ID2_S99_L003_R2_001.fastq.gz
ID2_S99_L004_R1_001.fastq.gz
ID2_S99_L004_R2_001.fastq.gz
ID3_S99_L001_R1_001.fastq.gz
ID3_S99_L001_R2_001.fastq.gz
ID3_S99_L002_R1_001.fastq.gz
ID3_S99_L002_R2_001.fastq.gz
ID3_S99_L003_R1_001.fastq.gz
ID3_S99_L003_R2_001.fastq.gz
ID3_S99_L004_R1_001.fastq.gz
ID3_S99_L004_R2_001.fastq.gz
```

## Performance

If compared with an efficient Bash implementation 
(as described [here](https://github.com/stephenturner/mergelanes#an-easier-way)),
*SeqFu* is >10X faster.

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu merge -o /tmp/ data/lane` | 2.6 ± 0.9 | 1.6 | 10.4 | 1.00 |
| `merge_lanes.sh data/lane/` | 31.8 ± 4.0 | 25.4 | 49.5 | 12.42 ± 4.46 |

The _merge\_lanes.sh_ script is as follows:
```bash
DIR=$PWD
cd $1
ls *R1* | cut -d _ -f 1 | sort | uniq \
    | while read id; do \
        cat $id*R1*.fastq.gz > $id.R1.fastq.gz;
        cat $id*R2*.fastq.gz > $id.R2.fastq.gz;
      done

cd $DIR/
rm $1/*.R{1,2}.*
```

and the test was performed against the `/data/lane` directory of SeqFu repository
using the [hyperfine](https://github.com/sharkdp/hyperfine) program.