
# fu-split

```note
Preliminary version
```

Split a FASTQ or FASTA files into multiple files, by:
* Number of desired output files (`--num-files INT`)
* Number of (max) sequences per file (`--num-seqs INT`)
* Number of (max) bases per file (`--num-bases INT`)

An important component to configure the program is the "output file" string, see below.

```text
usage: fu-split [-h] -i INPUT [-I INPUT_REV] -o OUTPUT [--for-tag FOR_TAG] [--rev-tag REV_TAG]
                (-n NUM_FILES | -s NUM_SEQS | -b NUM_BASES) [--threads THREADS] [--number-char NUMBER_CHAR] [--compress]
                [--verbose] [--debug] [--version]

Split FASTA/FASTQ files into multiple files

optional arguments:
  -h, --help            show this help message and exit
  -i INPUT, --input INPUT
                        Input file
  -I INPUT_REV, --input-rev INPUT_REV
                        Second input file (reverse pair)
  -o OUTPUT, --output OUTPUT
                        Output file (add a stretch of 3+ zeroes to specify the progressive number), compression will be detected.
                        Example: parz_0000.fq.gz
  --for-tag FOR_TAG     Tag to use for the forward reads output (default: _R1
  --rev-tag REV_TAG     Tag to use for the forward reads output (default: _R2
  -n NUM_FILES, --num-files NUM_FILES
                        Number of desired files
  -s NUM_SEQS, --num-seqs NUM_SEQS
                        Number of sequences per file
  -b NUM_BASES, --num-bases NUM_BASES
                        Number of bases per file
  --version             show program's version number and exit

Other options:
  --threads THREADS     Number of threads (-n only) [default: 8
  --number-char NUMBER_CHAR
                        Character used to represent the progressive number in output string [default: 0
  --compress            Force compression of the output files
  --verbose             Verbose mode
  --debug               Debug mode
```

## Output file string

The ideal way to use `fu-split` is to use the `--output` option to specify the output file format
with this apprach: *prefix*, *progressive number*, *suffix*, where *progressive number* is a stretch
of zeroes as long as you would like the progressive number (zeroes can be changed with `--number-char`).

Example:

* `--output parz_0000.fq.gz`: forces output in FASTQ format, compressed with Gzip, with four digits of progressive number.
* `--output parz_000.fa`: forces output in FASTA format, uncompressed, with three digits of progressive number.
* `--output parz`: missing the *progressive number* part, this will be used as prefix, with a four digits progressive number (not recommended, behaviour can change in the future)

## Paired end

Specify both `--input` and `--input-rev` to split a paired end FASTQ file. The output file will be differentiated
with the `--for-tag` and `--rev-tag` options (default: `_R1` and `_R2`).

## Binary

Export `$SEQFU_BIN` to specify the path to SeqFu, otherwise will default to `seqfu` (as in `$PATH`).

## Splashscreen

![Screenshot of "seqfu split"]({{site.baseurl}}/img/screenshot-fu-split.svg "SeqFu split")