#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR="$DIR/../bin"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/virfinder.csv" <<'CSV'
name,score,pvalue,length
keep one,0.95,0.01,120
low_score,0.70,0.01,120
high_pvalue,0.95,0.10,120
too_short,0.95,0.01,80
too_long,0.95,0.01,1000001
CSV

cat > "$TMPDIR/input.fa" <<'FASTA'
>keep
ACGT
>low_score
AAAA
>high_pvalue
CCCC
>too_short
GGGG
>too_long
TTTT
FASTA

"$BINDIR/fu-virfilter" "$TMPDIR/virfinder.csv" "$TMPDIR/input.fa" > "$TMPDIR/out.fa"

if [[ "$(grep -c '^>' "$TMPDIR/out.fa")" -ne 1 ]]; then
  echo "Expected one filtered sequence" >&2
  exit 1
fi

if ! grep -q '^>keep$' "$TMPDIR/out.fa"; then
  echo "Expected sequence named keep" >&2
  exit 1
fi

cat > "$TMPDIR/virfinder.tsv" <<'TSV'
name	score	pvalue	length
keep	0.95	0.01	120
TSV

"$BINDIR/fu-virfilter" --sep $'\t' "$TMPDIR/virfinder.tsv" "$TMPDIR/input.fa" > "$TMPDIR/out-tab.fa"

if ! grep -q '^>keep$' "$TMPDIR/out-tab.fa"; then
  echo "Expected tab-separated input to be supported" >&2
  exit 1
fi
