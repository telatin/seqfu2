---
layout: default
title: History
parent: Releases
---

## Release history

### version 1.27.0

* Added `seqfu amplicheck`, a new paired-end amplicon FASTQ QC command.
  * Produces DADA2-style QC recommendations without requiring R or DADA2.
  * Supports direct paired input and batch pairing by forward/reverse filename tags.
  * Reports primer detection, read-length summaries, per-position quality profiles, native overlap estimates, and recommended `truncLen`, `maxEE`, `truncQ`, and strategy values.
  * Includes deterministic subsampling via `--subsample` and bounded scans via `--max-reads`.
  * Writes JSON reports by default, optional human-readable text reports with `--text`, and standalone HTML quality plots with `--plot`.
  * Bundles a primer label database and supports `--amplicon auto`, `16s`, and `its` modes.
* Improved `seqfu list` with the updated syntax, multi-output mode via `--outdir` and repeatable `--lists`, support for leading `>`/`@` entries, duplicate/comment/blank-line handling, `--partial-match`, `--strict`, and per-list reports.
* Bugfix in `seqfu grep` word-search behaviour, with regression coverage.
* Fixed search behaviour and minor issues in the MSA viewer.
* Improved build and CI portability, including portable script build targets and workflow updates.
* Refreshed tool documentation, fixed broken links, and expanded the test suite for `amplicheck`, `list`, `grep`, and stats-related checks.

### version 1.26.0

* Added `seqfu subtract` to output records from a FASTA/FASTQ file that are absent from another file.
  * Matching can be done by sequence name, or by sequence content using `--by-seq`.
  * Added `--strip-comment`, `--strip-pair`, and `--relaxed` matching options.
* Improved `seqfu stats` JSON output so numeric fields are emitted as numeric values.
* Improved `seqfu stats --sort-by` validation with early errors for unknown keys.
* Fixed MultiQC `%GC` output in `seqfu stats` so it does not emit `NaN` or `Inf` when `--gc` is not explicitly requested.
* Refactored reverse-complement primer matching in `fu-primers`, switched internal threading to malebolgia, and expanded tests.
* Bugfix in `seqfu tab`: paired-end mode could print the wrong sequence.
* Bugfix in `seqfu metadata`: `--force-csv` is now honoured.

### version 1.25.1

* Fixed Bioconda build linkage for `-lphreads`.

### version 1.25.0

* Improved `seqfu counts` with multithreading support.
* Added an experimental table view in `seqfu counts`.
* Improved `seqfu stats` with multithreading support via `--threads INT`; multiple files are processed in parallel when threads are greater than 1 and stdin is not involved.
* Updated `seqfu stats` JSON output to use integer and float values instead of strings.

### version 1.23.0

* Added `seqfu tofasta`, a port of `any2fasta`, to extract sequences from GenBank, EMBL, GFF, and related formats.

### version 1.22.3

* Bugfix in `seqfu cat --anvio`: it no longer requires an explicit `--report` option to work.

### version 1.22.2

* Added support for L50, L75, and L90 statistics in `seqfu stats` using `--index`.
* The `--index` flag and output format are experimental and may change.

### version 1.22.1

* Tagged follow-up for L50, L75, and L90 statistics and test updates.

### version 1.22.0

* Added `seqfu cat --anvio`
* Added layouts to `seqfu metadata`, now supporting nf-core/rnaseq and nf-core/ampliseq
* Added experimental bactopia filesheets to `seqfu metadata`
* Improved `seqfu derep`
* Moved tests and code to support Nim 2.0
* Fixed `seqfu cat` prefix handling
* Various documentation updates

### version 1.20.3

* Bugfix in `seqfu interleave` and `seqfu deinterleave`.

### version 1.20.2

* Continued migration to Nim 2.0.

### version 1.20.1

* Bugfix in `seqfu metadata` when producing a single-end manifest file.
* Added `--translate` to `fu-orf`.

### version 1.20.0

* Improved `seqfu interleave/deinterleave`
* Migration to Nim 2.0
* Added `--translate` to `fu-orf`
* Faster smith-waterman `fu-sw`

### version 1.18

* Added paired end support to `fu-shred`

### version 1.17

* Bugfixes and removal of thread library 

### version 1.16

* Added amino-acid color scheme for `fu-msa`
* Bugfixes in `seqfu check` and `seqfu bases`

### version 1.15.0

* New SeqFu check program to validate the integrity of FASTQ datasets
* Bug fix in seqfu qual that was printing debug information in non-debug runs

#### 1.15.3

* Added SeqFu bases to evaluate the composition of FASTX files

### version 1.14.0

* **Seqfu grep** will die if fed with non existing files (to ensure no wrong parameters were passed)
* **Seqfu grep** will match oligos case insensitive by default
* Addedd invert match `-v` to `seqfu grep`
* Improved `fu-tabcheck`, notably added `--inspect` option to print columns info
* `fu-split` now can use a different SeqFu than specified in path, setting `$SEQFU_BIN` or `--bin` option
* `fu-split` version check fixed
* :warning: Bugfix in `seqfu tab`: was not working with FASTA files

### version 1.13.0

* `seqfu cat` now can skip a set of initial sequences (`--skip-first INT`) or start from a specific sequence (`--jump-to`)
* Minor updates in the test suite, github actions (including rich_codex) and documentation updates

#### 1.13.1

* added `fu-split` (experimental)

#### 1.13.2

* added `--print-last` option to **seqfu cat** and **seqfu heda**
* updated `fu-split`, with support for paired end reads, improved performance thanks to `--print-last`, new tests
  
### version 1.12.0

* Expanded "fu-index": also reports run infos, not only indexes
* Minor bugfix

### version 1.11.0

* Improved seqfu stats: added sorting option and JSON output, added GC content, improved test suite.
* bugfix Seqfu tabulate -d (detabulate) was too stringent in requiring forward and reverse reads to have the same length 🤦

### version 1.10.0
* Added support for MetaPhage to seqfu metadata
* Added --header to fu-tabcheck
* Minor fixes

### version 1.9.3

* bugfix: seqfu cat controls the length of operations (truncate, trim)
* improved: seqfu cat improved renaming options (basename and strip-name will now add a progressive number automatically)

### version 1.9.2

* Bugfix on Seqfu Detabulate

### version 1.9.1

* Fixes #8
* This is a re-release finally with all the necessary commits

### version 1.9.0

* seqfu grep now has -w (word) and -f (full) match options. default behaviour unchanged.
* seqfu cat now has a filter for Ns (--max-ns INT)
* seqfu cat now has a filter for the total expected errors (--max-ee FLOAT), and can report --add-ee and --add-initial-ee
* Added header line in seqfu metadata when using "irida" formats


### version 1.8.6

* Enabled **seqfu rotate**


### version 1.8.4

* **fu-orf**
  * Fixed bug in `fu-orf` to allow for single sequences
  * Introduced `-r`, `--scan-reverse` to include reverse complement in the ORF finder
  * `fu-orf` also prints frame in the sequence comment
* Expanded test suite


### version 1.8.3

* Markdown documentation improvements
* Splashscreen for *fu-virfilter* fixed
* Argument parser for _fu-cov_ improved
* Now `seqfu --version` and `seqfu version` will print the version number and exit
* Added test for _fu-cov_
* Added citation in main command and repository


### version 1.8.2

* Added `fu-virfilter` to filter VirFinder results
* Bugfix in `seqfu cat --basename`: the last update made it working only when prefix was also specified


### version 1.8.1

* introduced `fu-homocomp` to compress homopolymers


### version 1.8.0

* added `seqfu list` to extract sequences via a list


### version 1.7.2

* `seqfu grep` supports for comments


### version 1.7.1

* **Bugfix release**: `seqfu cat` with no parameters was stripping the reads name


### version 1.7.0

* Default primer character for oligo matches in seqfu view was Unicode, now Ascii
* Updated `seqfu cat` with improved sequence id renaming handling
* Updated `seqfu grep` to report the _oligo_ matches in the output as sequence comments


### version 1.6.3

* Removed ambiguity on `-q` in `seqfu head`
* Minor documentation updates

### version 1.6.0

* Improved STDIN messages, that can be disabled by `$SEQFU_QUIET=1`
* Added `--format irida` in `seqfu metadata` (for [IRIDA uploader](https://github.com/phac-nml/irida-uploader))
* Added `--gc` in `seqfu qual`: will print an additional column with the GC content
* Minor improvements on `seqfu cat`


### version 1.5.4

* Improved STDIN messages, that can be disabled by `$SEQFU_QUIET=1`
* Minor improvements on `seqfu cat`

### version 1.5.2

* **seqfu cat** has new options to manipulate the sequence name (like `--append STRING`) and to add comments (like  `--add-len`, `--add-gc`)

### version 1.5.0

* **seqfu count** now multithreading and redesigned. The output format is identical but  the order of the records is not protected (use **seqfu count-legacy** if needed)
* **seqfu cat** can print a list of sequences matching the criteria (`--list`)

### version 1.4.0

* Added **fu-shred**
* Added  `--reverse-read` to *fu-nanotags*

# version 1.3.6

* Automatic release system
* Documentation updates
* Minor updates
