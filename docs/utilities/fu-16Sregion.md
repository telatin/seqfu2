
# fu-16Sregion

```note
This utility is still in development, but feedback is welcome.
```

Align paired-end, or single-end, reads against a 16S
reference sequence to determine
the hypervariable regions sequences via local alignment.

Can read one FASTA/FASTQ file or data from standard input.

```text
Usage: fu-16Sregion [options] [<FASTQ-File>]

  Options:
    -r --reference FILE       FASTA file with a reference sequence, E. coli 16S by default
    -j --regions FILE         Regions names in JSON format, E. coli variable regions by default
    -m --min-fraction FLOAT   Minimum fraction of reads classified to report a region as detected [default: 0.5]
    --min-score INT           Minimum alignment score (approx. %id * readlen * matchScore) [default: 2000]
    --max-reads INT           Parse up to INT reads then quit [default: 500]

  Smith-Waterman:
    --score-match INT         Score for a match [default: 10]
    --score-mismatch INT      Score for a mismatch [default: -5]
    --score-gap INT           Score for a gap [default: -10]
  
  Other options:
    --pool-size INT           Number of sequences/pairs to process per thread [default: 25]
    -v --verbose              Verbose output
    --debug                   Enable diagnostics
    -h --help                 Show this help
```


## Example output

A tabular report, per read, is provided with the following columns

* Read name
* Primary target region
* Alignment score
* Region of the reference sequence covered (coordinates)

The **main** output is given as two columns: 

* regions detected in the same read (e.g. "V3,V4")
* fraction of reads with the combination

Example:

```text
V3-V4  0.83
```

This is only reported when the number of reads / total reads is above `--min-fraction`.

When activating the `--verbose` switch, some more information will be 
printed to the standard error, but also a **read by read output** will
be printed (read name, score, target region covered, detected regions and Pass/Fail):


```text
M05517:39:000000000-CNNWR:1:1105:7840:22808   score:2955  alignment:340..805  regions:V3,V4  Pass
M05517:39:000000000-CNNWR:1:1105:24801:23102  score:3480  alignment:340..805  regions:V3,V4  Pass
M05517:39:000000000-CNNWR:1:1105:9773:23284   score:2835  alignment:340..805  regions:V3,V4  Pass
M05517:39:000000000-CNNWR:1:1105:9791:23288   score:2835  alignment:340..805  regions:V3,V4  Pass
M05517:39:000000000-CNNWR:1:1105:11642:23566  score:1650  alignment:NA        regions:       Fail
M05517:39:000000000-CNNWR:1:1105:13198:23694  score:1535  alignment:NA        regions:       Fail
M05517:39:000000000-CNNWR:1:1105:15837:23728  score:2240  alignment:340..641  regions:V3,V4  Pass
M05517:39:000000000-CNNWR:1:1105:14501:23779  score:2225  alignment:340..641  regions:V3,V4  Pass
```


## Example use with paired-reads

To check paired-end reads, they can be processed independently or merged (if they overlap) before. 
SeqFu merge can be used for this purpose:

```
seqfu merge -1 read_R1.fq -2 read_R2.fq | fu-16region
```

## Region names

By default the following regions are used, but a new set can be fed in JSON format (each region
should contain the `start` and `end` values as show in the example)

```json
{
 "V1": {
   "start": 68,
   "end": 99
  }, "V2": {
   "start": 136,
   "end": 242
  }, "V3": {
   "start": 338,
   "end": 533
  }, "V4": {
   "start": 576,
   "end": 682
  }, "V5": {
   "start": 821,
   "end": 879
  }, "V6": {
   "start": 970,
   "end": 1046
  }, "V7": {
   "start": 1117,
   "end": 1294
  }, "V8": {
   "start": 1435,
   "end": 1465
  }
}
```