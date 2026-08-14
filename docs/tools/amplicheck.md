---
layout: default
title: seqfu amplicheck
parent: Core Tools
---

# seqfu amplicheck

`seqfu amplicheck` inspects paired-end amplicon FASTQ files and writes a JSON
report with DADA2-style quality-control recommendations. It does not run DADA2
or R.

```text
Usage:
  amplicheck [options] <FASTQ>...

Options:
  --fwd-tag STR             Forward read tag for batch pairing [default: _R1]
  --rev-tag STR             Reverse read tag for batch pairing [default: _R2]
  --max-reads INT           Stop after INT scanned read pairs per sample; 0 = all [default: 500000]
  --subsample FLOAT         Deterministic fraction of scanned pairs to analyze [default: 1.0]
  --only STAGES             Run only comma-separated stages: primers,length,quality,merge,sweep
  --skip STAGES             Skip comma-separated stages; "overlap" is accepted as "merge"
  --sweep                   Run truncLen/maxEE sweep
  --truncLen-grid LIST      Comma-separated truncLen values for --sweep; 0 = no truncation
  --maxEE-grid LIST         Comma-separated maxEE values for --sweep
  --amplicon MODE           One of auto, 16s, its [default: auto]
  --outdir DIR              Output directory [default: amplicheck_out]
  --no-json                 Do not write JSON report
  --text                    Write human-readable report.txt
  --plot                    Write self-contained HTML quality plots
  -v, --verbose             Print parsing progress and per-sample summaries
```

## Examples

Inspect one pair:

```bash
seqfu amplicheck sample_R1.fastq.gz sample_R2.fastq.gz --text
```

Inspect multiple pairs by tag substitution:

```bash
seqfu amplicheck data/*.fastq.gz --fwd-tag _R1 --rev-tag _R2
```

Scan up to 500,000 read pairs but analyze one every ten:

```bash
seqfu amplicheck sample_R1.fastq.gz sample_R2.fastq.gz --max-reads 500000 --subsample 0.1
```

Scan the whole pair and analyze one every hundred:

```bash
seqfu amplicheck sample_R1.fastq.gz sample_R2.fastq.gz --max-reads 0 --subsample 0.01
```

`--max-reads` counts scanned read pairs. `--subsample` is deterministic periodic
thinning over those scanned pairs: `0.1` keeps 1 every 10, `0.2` keeps 2 every
10, and `0.01` keeps 1 every 100.

Use `-v` to print one start line per sample, periodic scanned/sampled progress,
a parse completion line, and a compact per-sample summary on stderr. Report files
remain clean.

## Output

By default, output is written to:

```text
amplicheck_out/
└── report.json
```

With `--plot`, HTML output is added:

```text
amplicheck_out/
├── report.json
└── plots/
    ├── index.html
    └── sample.html
```

With `--text`, `report.txt` is written alongside JSON.
With `--plot`, SeqFu writes one standalone HTML quality report per sample under
`plots/`, plus `plots/index.html`. The index page is a self-contained sortable,
paged sample table with quality-report links and summary fields such as primer
detection, read counts, mean quality, average overlap, merge rate, and suggested
truncation settings. `--plot` can also be used as the only output format with
`--no-json`.

The JSON report includes:

1. input pair and sample identifier
2. `n_reads_scanned`, `n_reads_sampled`, and `n_reads_total` when known
3. primer detection and bundled primer-table labels
4. read-length summaries
5. per-position quality means and binned-quality classification
6. native overlap estimates
7. recommendation fields: `truncLen`, `maxEE`, `truncQ`, and strategy

The HTML quality pages contain the sampled per-cycle Q-score count matrix and
render mean/median/quantile curves plus a Q-score heatmap in the browser. Reads
longer than 10,000 bases are skipped for quality plotting/profile accumulation.
