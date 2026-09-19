---
layout: default
title: seqfu tabcheck
parent: Core Tools
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
  -i, --inspect          Inspect one valid table and infer column types and statistics
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
* `--inspect` accepts exactly one table and validates it before printing a profile.
* A leading comment/header row supplies column names. An unmarked first row is
  inferred as a header when its labels differ from numeric or date values below;
  otherwise columns are numbered from 1.
* Types are inferred from all non-empty values as `int`, `float`, `date`, or
  `string`. Dates recognize `YYYY-MM-DD` and `YYYY/MM/DD`.
* Numeric descriptions report minimum, maximum, and average across non-empty
  values. String descriptions report total and distinct counts plus the three
  most frequent values and their percentages. Date descriptions report the
  minimum and maximum date.

## Examples

Validate two files:

```bash
seqfu tabcheck data/table.tsv data/table.csv
```

Inspect column profiles:

```bash
seqfu tabcheck --inspect --header data/table.tsv
```

The profile is tab-separated:

```text
Column  Type    Description
sample  string  total=10; distinct=3; top3=A: 5 (50.0%), B: 3 (30.0%), C: 2 (20.0%)
count   int     min=1; max=12; average=6.4
```

Legacy equivalent:

```bash
fu-tabcheck data/table.tsv
```
