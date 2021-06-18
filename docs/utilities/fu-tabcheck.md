---
sort: 8
---

# fu-tabcheck

An utility to parse CSV/TSV files to check that all the records have the same size.
Multiline records are supported using double quotes as field delimiter. 
Gzipped files are also supported.

```
fu-tabcheck

  A program inspect TSV and CSV files, that must contain more than 1 column.
  Double quotes are considered field delimiters, if present.
  Gzipped files are supported natively.

  Usage: 
  fu-tabcheck [options] <FILE>...

  Options:
    -s --separator CHAR   Character separating the values, 'tab' for tab and 'auto'
                          to try tab or commas [default: auto]
    -c --comment CHAR     Comment/Header char [default: #]
    --verbose             Enable verbose mode

```

## Output
Tabular output has these columns:

* File name
* Pass/Error
* Columns number
* Records number
* Separator (when using _auto_ both tabs and commas are tested)

Example:
```
data/tab.txt.gz     Pass    8   7   separator=<tab>
data/tab.txt        Pass    4   3   separator=<tab>
data/tab-multi.tsv  Pass    2   4   separator=<tab>
data/table.csv      Pass    3   3   separator=,
data/table.tsv      Pass    3   4   separator=<tab>
data/table2.tsv     Error
data/tablegz.tsv.gz Pass    3   4   separator=<tab>
```

:bulb: Multiline records are supported using double quotes, like:
```text
#ID	   Description
R01    "this is       a cell with a tab inside!"
R02    "this is a
multi-line description"
R03    Last Record
```

## Exit code
A single file is not a valid table will lead to non-zero exit status.