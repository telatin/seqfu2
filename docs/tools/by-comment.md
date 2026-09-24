---
title: seqfu by-comment
summary: "Select records by comment text or typed key=value attributes and expressions."
category: filter
input: [FASTA, FASTQ]
output: "Same as input"
wrapper: false
deprecated: false
experimental: false
paired: true
interactive: false
related: ["seqfu by-id", "seqfu by-seq", "seqfu grep"]
keywords: "comment attributes where expression select filter"
---

`by-comment` selects FASTA and FASTQ records by the comment after the sequence
identifier. It can search raw comment text, compare embedded `key=value`
attributes, or evaluate arithmetic and boolean expressions over those
attributes. To match identifiers instead, use
[`seqfu by-id`]({{site.baseurl}}/tools/by-id.html).

```text
Usage:
  by-comment [options] [-e PATTERN]... [--where PREDICATE]... [--attribute-type KEY:TYPE]... [<item>...]

Comment text:
  -e, --pattern PATTERN       Add a pattern; may be repeated
  -f, --patterns-file FILE    Read one pattern per line
  --logic MODE                Combine patterns: any|all [default: any]
  -F, --fixed-string          Treat patterns as literal strings
  -x, --exact                 Match the complete comment
  -i, --ignore-case           Ignore case
  --has-comment               Require a non-empty comment
  --no-comment                Require an empty comment

Attributes:
  --where PREDICATE           Add a typed test; may be repeated
  --where-file FILE           Read one predicate per line
  --where-logic MODE          Combine predicates: any|all [default: all]
  --expr EXPRESSION           Evaluate a kexpr expression
  --expr-file FILE            Read one expression from FILE
  --attribute-separator CHAR  Key/value separator [default: =]
  --decimal-separator CHAR    Decimal separator [default: .]
  --thousands-separator CHAR  Grouping separator [default: ,]
  --attribute-type KEY:TYPE   Force string|integer|float; may be repeated
  --duplicate-keys MODE       Resolve first|last|error [default: last]
  --invalid-value MODE        Failed typed conversion: false|error [default: false]

Input and output:
  -1, --r1 FILE              Paired-end R1 FASTQ
  -2, --r2 FILE              Paired-end R2 FASTQ
  --interleaved              Treat one input as interleaved FASTQ
  --pair-mode MODE           Match either or both mates: any|both [default: any]
  -o, --output FILE          Write to FILE (gzip if .gz)
  -O, --output-r2 FILE       Write selected R2 reads to FILE
  --interleaved-output       Override inferred R2 filename
  --gzip-level INT           Gzip compression level [default: 6]

Other:
  -v, --invert-match         Invert the final selection
  -t, --threads INT          Worker threads [default: 1]
  --batch-size INT           Records or pairs per batch [default: 4096]
  --stats                    Print counts to stderr
  --verbose                  Print input and output routing to stderr
  -h, --help                 Show this help
```

## Search comment text

A positional pattern is a pure Nim regular expression matched anywhere in the
comment. A command-line pattern or a pattern file can contain multiple
alternatives; `--logic all` requires all text patterns to match the same
comment. `-F` treats them as literal strings and `-x` matches the whole
comment.

```bash
seqfu by-comment 'complete genome' assemblies.fa
seqfu by-comment -i -F -e circular -e complete --logic all assemblies.fa
seqfu by-comment -f comment-patterns.txt reads.fastq.gz
seqfu by-comment --no-comment assemblies.fa
```

Pattern files contain one pattern per line. Blank lines and lines beginning
with `#` are ignored. With no input file, the command reads standard input;
`-` names it explicitly. Use `-e` when a positional pattern could be confused
with an input path.

## Compare attributes

The parser finds `key=value` fields anywhere in a comment. Keys begin with a
letter or `_` and can also contain digits, `_`, `-`, and `.`. Unquoted values
end at whitespace or `;`; single- or double-quoted values can contain spaces
and can escape their quote or a backslash with `\`. Other prose is ignored.

For example, `description="complete circular genome" len=2,203 gc=0.49`
contains three attributes. Numeric parsing is strict and independent of the
system locale: `2,203` is 2203, while malformed grouping such as `2,20`
remains a string for `--where` equality and regex tests. A numeric-looking
malformed value makes an expression false (or errors with `--invalid-value
error`). Integer overflow never wraps.

`--where` accepts these comparisons:

| Form | Meaning |
| --- | --- |
| `KEY = VALUE`, `KEY != VALUE` | Numeric equality when both values are numbers; otherwise raw string equality |
| `KEY < VALUE`, `<=`, `>`, `>=` | Numeric ordering |
| `KEY ~ REGEX`, `KEY !~ REGEX` | Pure Nim regex search on the raw value |
| `KEY exists`, `KEY missing` | Presence or absence |

Missing keys fail ordinary comparisons, including `!=` and `!~`. By default,
multiple `--where` tests use AND; `--where-logic any` switches to OR. Text,
`--where`, and `--expr` groups are combined with AND.

```bash
seqfu by-comment --where 'len >= 2000' --where 'gc < 0.5' assemblies.fa
seqfu by-comment --where 'status = complete' assemblies.fa
seqfu by-comment --where 'taxonomy exists' assemblies.fa
seqfu by-comment --where-file predicates.txt assemblies.fa
```

Use `--attribute-type sample:string` when `sample=001` must not compare
numerically equal to `sample=1`. `--duplicate-keys` chooses the first or last
value, or errors on a duplicate. `--invalid-value error` turns failed typed
conversion into a diagnostic. Custom decimal and thousands separators can be
supplied explicitly.

## Evaluate expressions

`--expr` uses kexpr for arithmetic, parentheses, comparisons, and boolean
operators. It uses `==` for equality, whereas `--where` uses `=`. An expression
can also be read from `--expr-file`; the two options are mutually exclusive.

```bash
seqfu by-comment --expr '(len >= 2000 && gc < 0.5) || score >= 3' assemblies.fa
seqfu by-comment --expr 'len * gc >= 1000' assemblies.fa
seqfu by-comment --expr 'status == "complete"' assemblies.fa
```

Expression variable names map `-` and `.` in attribute keys to `_`; for
example, `read-count` becomes `read_count`. A collision after mapping is an
error. A missing expression variable makes the expression false for that
record, not zero. Use `--where 'KEY missing'` for an explicit absence test.

## Paired reads and files

Pass two FASTQ files with `-1` and `-2`, or one interleaved FASTQ with
`--interleaved`. The complete predicate is tested on each mate. By default,
either mate may match; `--pair-mode both` requires both. Selected pairs are
always emitted together and are interleaved on standard output.

```bash
seqfu by-comment --where 'score >= 3' -1 reads_R1.fq.gz -2 reads_R2.fq.gz \
  -o selected_R1.fq.gz -O selected_R2.fq.gz
seqfu by-comment --expr 'len >= 2000' --interleaved reads.fq.gz \
  --pair-mode both -o selected.fq.gz
```

With `-o` but no `-O`, an R2 filename is inferred from `_R1`/`_R2` or
`_1.`/`_2.`. If neither pattern applies, pairs stay interleaved in the single
output file. `--interleaved-output` forces that behavior. A `.gz` output suffix
enables gzip compression. `-t` enables bounded, ordered parallel matching;
the default single-thread path avoids copying records into batches.
