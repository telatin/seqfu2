
# seqfu stats

*stats*  is one of the core subprograms of *SeqFu*.

```text
Usage: stats [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -n, --nice             Print nice terminal table
  -j, --json             Print json (EXPERIMENTAL)
  -s, --sort-by KEY      Sort by KEY from: filename, counts, n50, tot, avg, min, max
                         descending for values, ascending for filenames [default: none]
  -r, --reverse          Reverse sort order
  -t, --thousands        Add thousands separator (only tabbed/nice output)
  --csv                  Separate output by commas instead of tabs
  --gc                   Also print %GC
  --multiqc FILE         Saves a MultiQC report to FILE (suggested: name_mqc.txt)
  --precision INT        Number of decimal places to round to [default: 2]
  --noheader             Do not print header
  -v, --verbose          Verbose output
  -h, --help             Show this help
```

### Sorting

```note
Sorting added in SeqFu 1.11. 
```
To sort by filename (ascending alphabetical order) add `--sort filename`.
Numerical values are sorted from the largest (descending), supported values are:
* *n50*, *n75* or *N90*
* *count* or *counts* (number of reads)
* *sum* or *tot* (total bases)
* *min* or *minimum* (minimum length)
* *max* or *maximum* (maximum length)
* *avg* or *mean* (average length)
* *aun* (area under the Nx curve)

**NOTE** Specifying an invalid key will result in unsorted results with a warning,
but in future releases this might throw an error.
 
### Example output

Output is a TSV text with three columns (or CSV using  `--csv`):

```text
File,#Seq,Sum,Avg,N50,N75,N90,Min,Max
data/filt.fa.gz,78730,24299931,308.6,316,316,220,180,485
```

### Screen friendly output

When using `-n` (`--nice`) output:

```text 
seqfu stats data/filt.fa.gz  -n
┌─────────────────┬───────┬──────────┬───────┬─────┬─────┬─────┬───────┬─────┬─────┐
│ File            │ #Seq  │ Total bp │ Avg   │ N50 │ N75 │ N90 │ auN   │ Min │ Max │
├─────────────────┼───────┼──────────┼───────┼─────┼─────┼─────┼───────┼─────┼─────┤
│ data/filt.fa.gz │ 78730 │ 24299931 │ 308.6 │ 316 │ 316 │ 220 │ 0.385 │ 180 │ 485 │
└─────────────────┴───────┴──────────┴───────┴─────┴─────┴─────┴───────┴─────┴─────┘
```
 

## MultiQC output

Using the  `--multiqc OUTPUTFILE` option it's possible to save a MultiQC compatible file (we recommend to use the *projectname_mqc.tsv* filename format).
After coolecting all the MultiQC files in a directory, using `multiqc -f .` will generate the MultiQC report. 
MultiQC itself can be installed via Bioconda with `conda install -y -c bioconda multiqc`.

To understand how to use MultiQC, if you never did so, check their excellent [documentation](https://multiqc.info).

## Legacy

The pre 1.11 version of the statistics has been made available via `seqfu oldstats`.
There are no breaking changes at the moment, and an expanded set of tests ensures
the compatibility not only of the metrics (unchanged) but also of the output (now
supporting sorting options).


## Benchmark

A similar functionality is provided by `SeqKit`, so we compared the performance of 
SeqFu with 
[SeqKit](https://bioinf.shenwei.me/seqkit/) and 
[n50](https://metacpan.org/pod/release/PROCH/Proch-N50-1.3.0/bin/n50), 
both available from bioconda. 
We used a Linux Virtual Machine running Ubuntu 18.04, with 8 cores and 64 Gb of RAM for the test,
with Miniconda (4.9.2) to install the required tools.

:warning: SeqKit, by default, omits N50 calculation, that is a core feature (always enabled) in SeqFu.
The correct comparison is thus between `seqfu stats` and `seqkit stats --all`.

Speed evaluate with 
[hyperfine](https://github.com/sharkdp/hyperfine), 
peak memory usage with this 
[bash script](https://gist.github.com/MattForshaw/86b82b6c09bdbfce5ff5ee570e8a8bef).

As dataset we used the Human Genome (see [this benchmark page](https://bioinf.shenwei.me/seqkit/benchmark/)),
which contains few large sequences, and the reference genome of the gastrointestinal tract, which is composed by many
short sequences instead.

The test can be replicated with these commands:
```bash
# Download tools (can be done in a new environment)
conda install -c conda-forge -c bioconda hyperfine n50=1.3.0 seqkit=0.16.0 seqfu=0.9.6
 
# Download datasets: many short sequences and few large sequences 
wget http://downloads.hmpdacc.org/data/reference_genomes/body_sites/Gastrointestinal_tract.nuc.fsa
wget ftp://ftp.ensembl.org/pub/release-84/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz

# Compare execution times
FILE1=Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz
FILE2=Gastrointestinal_tract.nuc.fsa

for FILE in $FILE1 $FILE2; do
  hyperfine --export-markdown stat_$(basename $FILE | cut -f1 -d.).md --warmup 1 --min-runs 3 \
    "seqfu stats $FILE" \
    "seqkit stats $FILE" \
    "seqkit stats --all $FILE" \
    "n50 -x $FILE" 
done
```

The result, for the **Human Genome** (few large sequences), has been:

| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu stats $FILE` | 27.420 ± 0.349 | 27.090 | 27.785 | 1.00 |
| `seqkit stats $FILE`  :warning:  | 116.693 ± 0.236 | 116.512 | 116.960 | 4.26 ± 0.05 |
| `seqkit stats --all $FILE` | 120.435 ± 0.434 | 120.054 | 120.907 | 4.39 ± 0.06 |
| `n50 -x $FILE` | 34.888 ± 0.628 | 34.167 | 35.316 | 1.27 ± 0.03 |

For the **Gastrointestinal reference genomes** (many short sequences):

| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu stats $FILE` | 6.885 ± 0.307 | 6.602 | 7.211 | 1.82 ± 0.09 |
| `seqkit stats $FILE` :warning: | 3.793 ± 0.082 | 3.699 | 3.854 | 1.00 |
| `seqkit stats --all $FILE` | 7.667 ± 0.081 | 7.583 | 7.746 | 2.02 ± 0.05 |
| `n50 -x $FILE` | 76.377 ± 1.990 | 74.891 | 78.638 | 20.14 ± 0.68 |


## Screenshot

![Screenshot of "seqfu stats"]({{site.baseurl}}/img/screenshot-stats.svg "SeqFu stats")