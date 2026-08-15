#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR="$DIR/../bin"
VIRFILTER_TMP="$(mktemp -d)"
VIRFILTER_PREVERR=${ERRORS:-0}

: "${OK:=OK}"
: "${FAIL:=FAIL}"
: "${PASS:=0}"
: "${ERRORS:=0}"

virfilter_ok() {
  local msg="$1"
  echo -e "$OK: $msg"
  PASS=$((PASS+1))
}

virfilter_fail() {
  local msg="$1"
  echo -e "$FAIL: $msg"
  ERRORS=$((ERRORS+1))
}

if [[ ! -e "$BINDIR/fu-virfilter" ]]; then
  virfilter_fail "fu-virfilter binary exists"
  rm -rf "$VIRFILTER_TMP"
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    exit 1
  fi
  return 0
fi

cat > "$VIRFILTER_TMP/virfinder.csv" <<'CSV'
name,score,pvalue,length
keep one,0.95,0.01,120
low_score,0.70,0.01,120
high_pvalue,0.95,0.10,120
too_short,0.95,0.01,80
too_long,0.95,0.01,1000001
CSV

cat > "$VIRFILTER_TMP/input.fa" <<'FASTA'
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

MSG="VirFinder CSV filters by score, pvalue, and length"
"$BINDIR/fu-virfilter" "$VIRFILTER_TMP/virfinder.csv" "$VIRFILTER_TMP/input.fa" > "$VIRFILTER_TMP/out.fa" 2>"$VIRFILTER_TMP/out.err"
RET=$?
OBS=$(grep -c '^>' "$VIRFILTER_TMP/out.fa" 2>/dev/null || true)
if [[ $RET -eq 0 ]] && [[ "$OBS" -eq 1 ]]; then
  virfilter_ok "$MSG"
else
  virfilter_fail "$MSG (exit=$RET seqs=$OBS err=$(cat "$VIRFILTER_TMP/out.err"))"
fi

MSG="VirFinder CSV preserves the matching FASTA record"
if grep -q '^>keep$' "$VIRFILTER_TMP/out.fa"; then
  virfilter_ok "$MSG"
else
  virfilter_fail "$MSG"
fi

cat > "$VIRFILTER_TMP/virfinder.tsv" <<'TSV'
name	score	pvalue	length
keep	0.95	0.01	120
TSV

MSG="VirFinder TSV input is supported with --sep"
"$BINDIR/fu-virfilter" --sep $'\t' "$VIRFILTER_TMP/virfinder.tsv" "$VIRFILTER_TMP/input.fa" > "$VIRFILTER_TMP/out-tab.fa" 2>"$VIRFILTER_TMP/out-tab.err"
RET=$?
if [[ $RET -eq 0 ]] && grep -q '^>keep$' "$VIRFILTER_TMP/out-tab.fa"; then
  virfilter_ok "$MSG"
else
  virfilter_fail "$MSG (exit=$RET err=$(cat "$VIRFILTER_TMP/out-tab.err"))"
fi

rm -rf "$VIRFILTER_TMP"

if [[ "${BASH_SOURCE[0]}" == "$0" ]] && [[ $ERRORS -gt $VIRFILTER_PREVERR ]]; then
  exit 1
fi
