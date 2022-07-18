* **SeqFu grep** will die if fed with non existing files (to ensure no wrong parameters were passed)
* **SeqFu grep** will match oligos case insensitive by default
* Addedd invert match `-v` to `seqfu grep`
* Improved `fu-tabcheck`, notably added `--inspect` option to print columns info
* `fu-split` now can use a different SeqFu than specified in path, setting `$SEQFU_BIN` or `--bin` option
* `fu-split` version check fixed
* :warning: Bugfix in `seqfu tab`: was not working with FASTA files
* **SeqFu head** and **SeqFu tail** migrated to readfq library