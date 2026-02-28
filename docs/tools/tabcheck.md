---
layout: default
title: seqfu tabcheck
parent: Core Tools
nav_order: 26
---

# seqfu tabcheck

Validate TSV/CSV files by checking consistent field counts across rows (gzipped input supported).

`seqfu tabcheck` is the preferred command.  
The legacy binary `fu-tabcheck` is still available and accepts the same options.

```text
tabcheck

A program inspect TSV and CSV files, that must contain more than 1 column.
Double quotes are considered field delimiters, if present.
Gzipped files are supported natively.

Usage:
  tabcheck [options] <FILE>...

Options:
  -s, --separator CHAR   Character separating the values, 'tab' for tab and 'auto'
                         to try tab or commas [default: auto]
  -c, --comment CHAR     Comment/Header char [default: #]
  -i, --inspect          Gather more informations on column content [if valid column]
  --header               Print a header to the report
  --verbose              Enable verbose mode
```

## Output

Regular mode prints one line per file with pass/fail, detected separator, and row/column counts.

On failure, diagnostics include:

* first bad row index
* expected number of columns
* observed number of columns

Example error:

```text
data/table2.tsv    Error[row=3;expected=3;observed=4;reason=inconsistent-column-count]
```

## Notes

* `--separator auto` performs separator sampling before full parsing.
* Comments are ignored when `--comment` is set (default: `#`).
* `--inspect` prints per-column cardinality and most frequent value statistics.

## Examples

Validate two files:

```bash
seqfu tabcheck data/table.tsv data/table.csv
```

Inspect column profiles:

```bash
seqfu tabcheck --inspect --header data/table.tsv
```

Legacy equivalent:

```bash
fu-tabcheck data/table.tsv
```
