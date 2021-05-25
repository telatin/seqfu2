---
sort: 4
---

# fu-16Sregion

Align paired-end, or single-end, reads against a 16S reference sequence to determine
the hypervariable regions sequences via local alignment.

```text
Usage: fu-16Sregion [options] -1 <FOR> [-2 <REV>]

  Options:
    -1 --first-pair <FOR>     First sequence in pair
    -2 --second-pair <REV>    Second sequence in pair (can be inferred)
    -r --reference FILE       FASTA file with a reference sequence, E. coli 16S by default
    -j --regions FILE         Regions names in JSON format, E. coli variable regions by default
    --pattern-R1 <tag-1>      Tag in first pairs filenames [default: auto]
    --pattern-R2 <tag-2>      Tag in second pairs filenames [default: auto]
    --pool-size INT           Number of sequences/pairs to process per thread [default: 20]
    --min-score INT           Minimum alignment score [default: 80]
    --max-reads INT           Parse up to INT reads then quit [default: 1000]
    --se                      Force single end
    -v --verbose              Verbose output
```


## Example output

A tabular report, per read, is provided with the following columns:
* Read name
* Primary target region
* Alignment score
* Region of the reference sequence covered (coordinates)

```text
M05517:39:000000000-CNNWR:1:1105:14289:5036.2   V4      score=958       432-856
M05517:39:000000000-CNNWR:1:1105:14879:12655.1  V7      score=950       775-1210
M05517:39:000000000-CNNWR:1:1105:6800:12686.2   V4      score=966       432-883
M05517:39:000000000-CNNWR:1:1105:24317:7693.1   V4      score=994       605-1069
M05517:39:000000000-CNNWR:1:1105:5057:7976.2    V4      score=956       446-883
M05517:39:000000000-CNNWR:1:1105:24702:10407.1  V3      score=946       147-599
```
