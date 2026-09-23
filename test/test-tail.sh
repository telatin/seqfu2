#!/bin/bash
# Tests for "seqfu tail". Sourced by test/mini.sh, but can also run directly.

export SEQFU_QUIET=1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR="${BINDIR:-$DIR/../bin/}"
OK="${OK:-OK}"
FAIL="${FAIL:-FAIL}"
PASS="${PASS:-0}"
ERRORS="${ERRORS:-0}"

TAIL_TMP=$(mktemp -d)

tail_check() {
  local MSG="$1" EXP="$2" OBS="$3"
  if [[ "$EXP" == "$OBS" ]]; then
    echo -e "$OK: tail: $MSG"
    PASS=$((PASS+1))
  else
    echo -e "$FAIL: tail: $MSG"
    echo "   exp: $EXP"
    echo "   got: $OBS"
    ERRORS=$((ERRORS+1))
  fi
}

NUMS="$DIR"/../data/numbers.fa        # 1000 FASTA sequences
ILV="$DIR"/../data/interleaved.fq.gz  # 14 FASTQ = 7 interleaved pairs
FQ="$DIR"/../data/dataset.fastq.gz

# --- Basic count ---
OBS=$("$BINDIR"/seqfu tail "$NUMS" | grep -c '^>')
tail_check "default -n 10 → 10 sequences" 10 "$OBS"

OBS=$("$BINDIR"/seqfu tail -n 50 "$NUMS" | grep -c '^>')
tail_check "-n 50 → 50 sequences" 50 "$OBS"

# --- Subsampling ---
OBS=$("$BINDIR"/seqfu tail -n 30 -k 2 "$NUMS" | grep -c '^>')
tail_check "-n 30 -k 2 → 30 sequences (every 2nd)" 30 "$OBS"

# --- Prefix rename ---
# With prefix, names reflect absolute position in file (seq 998, 999, 1000 → _998, _999, _1000)
OBS=$("$BINDIR"/seqfu tail -n 3 -p TAIL "$NUMS" | grep '^>' | awk '{print $1}')
EXP=$(printf ">TAIL_998\n>TAIL_999\n>TAIL_1000")
tail_check "-n 3 -p TAIL → names reflect position in file" "$EXP" "$OBS"

# --- Output to plain file ---
"$BINDIR"/seqfu tail -n 8 -o "$TAIL_TMP"/out.fa "$NUMS"
OBS=$(grep -c '^>' "$TAIL_TMP"/out.fa)
tail_check "-o FILE → file contains 8 sequences" 8 "$OBS"

# --- Output to gzip file ---
"$BINDIR"/seqfu tail -n 6 -o "$TAIL_TMP"/out.fa.gz "$NUMS"
OBS=$(gunzip -c "$TAIL_TMP"/out.fa.gz | grep -c '^>')
tail_check "-o FILE.gz → gz contains 6 sequences" 6 "$OBS"

# --- Interleaved: -n counts pairs → 2× records printed ---
OBS=$("$BINDIR"/seqfu tail --interleaved -n 3 "$ILV" | grep -c '^@')
tail_check "--interleaved -n 3 → 6 FASTQ records (last 3 pairs)" 6 "$OBS"

OBS=$("$BINDIR"/seqfu tail --interleaved -n 7 "$ILV" | grep -c '^@')
tail_check "--interleaved -n 7 → 14 FASTQ records (all 7 pairs)" 14 "$OBS"

# --- Interleaved + gzip output ---
"$BINDIR"/seqfu tail --interleaved -n 2 -o "$TAIL_TMP"/ilv.fastq.gz "$ILV"
OBS=$(gunzip -c "$TAIL_TMP"/ilv.fastq.gz | grep -c '^@')
tail_check "--interleaved -n 2 -o FILE.gz → gz has 4 records" 4 "$OBS"

# --- Force FASTA from FASTQ input ---
OBS=$("$BINDIR"/seqfu tail -n 2 --fasta "$FQ" | grep -c '^>')
tail_check "--fasta: FASTQ input converted to FASTA output" 2 "$OBS"

rm -rf "$TAIL_TMP"
