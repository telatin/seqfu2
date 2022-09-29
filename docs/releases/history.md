## Release history

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
