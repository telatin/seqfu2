#!/bin/bash
# Tests for "seqfu head". Sourced by test/mini.sh, but can also run directly.

export SEQFU_QUIET=1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR="${BINDIR:-$DIR/../bin/}"
OK="${OK:-OK}"
FAIL="${FAIL:-FAIL}"
PASS="${PASS:-0}"
ERRORS="${ERRORS:-0}"

HEAD_TMP=$(mktemp -d)

head_check() {
  local MSG="$1" EXP="$2" OBS="$3"
  if [[ "$EXP" == "$OBS" ]]; then
    echo -e "$OK: head: $MSG"
    PASS=$((PASS+1))
  else
    echo -e "$FAIL: head: $MSG"
    echo "   exp: $EXP"
    echo "   got: $OBS"
    ERRORS=$((ERRORS+1))
  fi
}

NUMS="$DIR"/../data/numbers.fa        # 1000 FASTA sequences
ILV="$DIR"/../data/interleaved.fq.gz  # 14 FASTQ = 7 interleaved pairs
FQ="$DIR"/../data/dataset.fastq.gz

# --- Basic count ---
OBS=$("$BINDIR"/seqfu head -n 5 "$NUMS" | grep -c '^>')
head_check "-n 5 → 5 sequences" 5 "$OBS"

OBS=$("$BINDIR"/seqfu head "$NUMS" | grep -c '^>')
head_check "default -n 10 → 10 sequences" 10 "$OBS"

# --- Subsampling ---
OBS=$("$BINDIR"/seqfu head -n 50 -k 2 "$NUMS" | grep -c '^>')
head_check "-n 50 -k 2 → 50 sequences (every 2nd)" 50 "$OBS"

# --- Prefix rename ---
OBS=$("$BINDIR"/seqfu head -n 3 -p READ "$NUMS" | grep '^>' | awk '{print $1}')
EXP=$(printf ">READ_1\n>READ_2\n>READ_3")
head_check "-n 3 -p READ → names READ_1..READ_3" "$EXP" "$OBS"

# --- --print-last ---
LAST=$("$BINDIR"/seqfu head -n 3 -p X --print-last "$NUMS" 2>&1 >/dev/null)
head_check "--print-last emits Last:X_3 on stderr" "Last:X_3" "$LAST"

# --- Output to plain file ---
"$BINDIR"/seqfu head -n 8 -o "$HEAD_TMP"/out.fa "$NUMS"
OBS=$(grep -c '^>' "$HEAD_TMP"/out.fa)
head_check "-o FILE → file contains 8 sequences" 8 "$OBS"

# --- Output to gzip file ---
"$BINDIR"/seqfu head -n 6 -o "$HEAD_TMP"/out.fa.gz "$NUMS"
OBS=$(gunzip -c "$HEAD_TMP"/out.fa.gz | grep -c '^>')
head_check "-o FILE.gz → gz contains 6 sequences" 6 "$OBS"

# --- Interleaved: -n counts pairs → 2× records printed ---
OBS=$("$BINDIR"/seqfu head --interleaved -n 3 "$ILV" | grep -c '^@')
head_check "--interleaved -n 3 → 6 FASTQ records (3 pairs)" 6 "$OBS"

OBS=$("$BINDIR"/seqfu head --interleaved -n 7 "$ILV" | grep -c '^@')
head_check "--interleaved -n 7 → 14 FASTQ records (all 7 pairs)" 14 "$OBS"

# --- Interleaved + gzip output ---
"$BINDIR"/seqfu head --interleaved -n 2 -o "$HEAD_TMP"/ilv.fastq.gz "$ILV"
OBS=$(gunzip -c "$HEAD_TMP"/ilv.fastq.gz | grep -c '^@')
head_check "--interleaved -n 2 -o FILE.gz → gz has 4 records" 4 "$OBS"

# --- Force FASTA from FASTQ input ---
OBS=$("$BINDIR"/seqfu head -n 2 --fasta "$FQ" | grep -c '^>')
head_check "--fasta: FASTQ input converted to FASTA output" 2 "$OBS"

# --- Fewer-than-requested warning ---
WARN=$(SEQFU_QUIET="" "$BINDIR"/seqfu head -n 2000 "$NUMS" 2>&1 >/dev/null)
head_check "-n 2000 on 1000-seq file warns about fewer sequences" \
  1 "$(echo "$WARN" | grep -c WARNING)"

# --- --quiet suppresses warning ---
WARN=$(SEQFU_QUIET="" "$BINDIR"/seqfu head -n 2000 --quiet "$NUMS" 2>&1 >/dev/null)
head_check "--quiet suppresses fewer-than-requested warning" \
  0 "$(echo "$WARN" | grep -c WARNING)"

# --- --fatal exits non-zero when sequence count falls short ---
"$BINDIR"/seqfu head -n 2000 --fatal "$NUMS" >/dev/null 2>&1
head_check "--fatal exits non-zero when fewer sequences than requested" 1 $?

rm -rf "$HEAD_TMP"
