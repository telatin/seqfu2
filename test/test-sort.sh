#!/bin/bash
# Tests for "seqfu sort". Sourced by test/mini.sh, but can also run directly.

export SEQFU_QUIET=1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR="${BINDIR:-$DIR/../bin/}"
OK="${OK:-OK}"
FAIL="${FAIL:-FAIL}"
PASS="${PASS:-0}"
ERRORS="${ERRORS:-0}"

SORT_TMP=$(mktemp -d)
printf ">a1 c1\nAAAA\n>a2 c2\nCCCC\n>a3\nGGGG\n>dup\nAAAA\n>t\nTTTTTT\n" > "$SORT_TMP"/x.fa
printf ">b1\nAAAA\n>b2\nACGTACGTAC\n" > "$SORT_TMP"/y.fa
printf "@q1\nACGT\n+\nIIII\n" > "$SORT_TMP"/q.fq

sort_check() {
  local MSG="$1" EXP="$2" OBS="$3"
  if [[ "$EXP" == "$OBS" ]]; then
    echo -e "$OK: sort: $MSG"
    PASS=$((PASS+1))
  else
    echo -e "$FAIL: sort: $MSG"
    echo "   exp: $(echo "$EXP" | tr '\n' ' ')"
    echo "   got: $(echo "$OBS" | tr '\n' ' ')"
    ERRORS=$((ERRORS+1))
  fi
}

# Descending, first name kept for duplicates, equal lengths in input order, comments kept
EXP=$(printf ">t\nTTTTTT\n>a1 c1\nAAAA\n>a2 c2\nCCCC\n>a3\nGGGG")
OBS=$("$BINDIR"/seqfu sort "$SORT_TMP"/x.fa)
sort_check "descending, first name kept, stable ties" "$EXP" "$OBS"

# Ascending with stripped comments
EXP=$(printf ">a1\nAAAA\n>a2\nCCCC\n>a3\nGGGG\n>t\nTTTTTT")
OBS=$("$BINDIR"/seqfu sort --asc -s "$SORT_TMP"/x.fa)
sort_check "ascending, --strip-comments" "$EXP" "$OBS"

# Multiple files are pooled: cross-file duplicates removed, prefix counter is global
EXP=$(printf ">S1\nACGTACGTAC\n>S2\nTTTTTT\n>S3\nAAAA\n>S4\nCCCC\n>S5\nGGGG")
OBS=$("$BINDIR"/seqfu sort -s -p S "$SORT_TMP"/x.fa "$SORT_TMP"/y.fa)
sort_check "multiple files pooled with --prefix" "$EXP" "$OBS"

# --keep-duplicates keeps identical sequences as separate records
EXP=$(printf ">t\nTTTTTT\n>a1\nAAAA\n>a2\nCCCC\n>a3\nGGGG\n>dup\nAAAA")
OBS=$("$BINDIR"/seqfu sort -k -s "$SORT_TMP"/x.fa)
sort_check "--keep-duplicates" "$EXP" "$OBS"

# FASTQ input: converted to FASTA with a warning
EXP=$(printf ">q1\nACGT")
OBS=$("$BINDIR"/seqfu sort "$SORT_TMP"/q.fq 2>/dev/null)
sort_check "FASTQ input printed as FASTA" "$EXP" "$OBS"
OBS=$("$BINDIR"/seqfu sort "$SORT_TMP"/q.fq 2>&1 >/dev/null | grep -c "WARNING")
sort_check "FASTQ input warning" "1" "$OBS"

# Missing input file fails with a message
OBS=$("$BINDIR"/seqfu sort "$SORT_TMP"/missing.fa 2>&1; echo "exit=$?")
if [[ "$OBS" == *"not found"* && "$OBS" == *"exit=1" ]]; then
  sort_check "missing file error" "1" "1"
else
  sort_check "missing file error" "not found / exit=1" "$OBS"
fi

rm -rf "$SORT_TMP"
