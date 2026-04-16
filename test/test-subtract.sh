#!/bin/bash
# test-subtract.sh — integration tests for 'seqfu subtract'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# BIN can be set externally (e.g. pointing at a dev build); falls back to the
# installed seqfu in bin/ or whatever BINDIR resolves to.
if [[ -z ${BIN+x} ]]; then
  BIN="${BINDIR:-$DIR/../bin}/seqfu"
fi
FILES="${FILES:-$DIR/../data}"

OK='\033[0;32mOK\033[0m'
FAIL='\033[0;31mFAIL\033[0m'

# When sourced from mini.sh, reuse its global counters.
if [[ -z ${PASS+x} ]];   then PASS=0;   fi
if [[ -z ${ERRORS+x} ]]; then ERRORS=0; fi

IS_SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then IS_SOURCED=1; fi

# Portable temp directory: honours $TMPDIR, falls back to /tmp.
TMP=$(mktemp -d 2>/dev/null || { mkdir -p "${TMPDIR:-/tmp}/seqfu_sub_$$" && echo "${TMPDIR:-/tmp}/seqfu_sub_$$"; })
trap 'rm -rf "$TMP"' EXIT

pass() { echo -e "$OK: $1";   PASS=$((PASS+1));   }
fail() { echo -e "$FAIL: $1"; ERRORS=$((ERRORS+1)); }

check_eq() {
  # check_eq LABEL VALUE EXPECTED
  # Trim whitespace from VALUE (macOS wc -l pads with spaces)
  local val
  val=$(echo "$2" | tr -d ' ')
  if [[ "$val" -eq "$3" ]]; then pass "$1 (got $val)";
  else fail "$1: expected $3, got $val"; fi
}

# ── Input files ────────────────────────────────────────────────────────────────
# test.fa  – 12 sequences (filt.0 .. filt.11); some have comments/size tags
# illumina_nocomm.fq – 7 FASTQ reads, no comments, clean names
# comments.fasta – 4 sequences, all with comments (len= cov= fields)

FASTA="$FILES/test.fa"          # 12 FASTA sequences
FASTQ="$FILES/illumina_nocomm.fq"  # 7 FASTQ reads

# ── Sanity: help exits cleanly ─────────────────────────────────────────────────
"$BIN" subtract --help >/dev/null 2>&1
if [[ $? -eq 0 ]]; then pass "subtract --help exits 0"
else fail "subtract --help returned non-zero"; fi

# ── Test 1: Basic FASTA subtraction count ─────────────────────────────────────
"$BIN" head -n 4 "$FASTA" > "$TMP/head4.fa"
"$BIN" subtract "$FASTA" "$TMP/head4.fa" > "$TMP/rest8.fa" 2>/dev/null
COUNT=$(grep -c '^>' "$TMP/rest8.fa")
check_eq "FASTA: subtract 4 from 12 leaves 8" "$COUNT" 8

# ── Test 2: Subtracted names absent from output ───────────────────────────────
FIRST_SUBTRACTED=$(grep '^>' "$TMP/head4.fa" | head -n 1 | cut -c 2- | awk '{print $1}')
if ! grep -q "^>$FIRST_SUBTRACTED" "$TMP/rest8.fa" 2>/dev/null; then
  pass "FASTA: subtracted name absent from output"
else
  fail "FASTA: subtracted name '$FIRST_SUBTRACTED' still in output"
fi

# ── Test 3: Non-subtracted names present in output ────────────────────────────
LAST_SEQ=$(grep '^>' "$FASTA" | tail -n 1 | cut -c 2- | awk '{print $1}')
if grep -q "^>$LAST_SEQ" "$TMP/rest8.fa" 2>/dev/null; then
  pass "FASTA: non-subtracted name present in output"
else
  fail "FASTA: non-subtracted name '$LAST_SEQ' missing from output"
fi

# ── Test 4: Strict mode – file2 has name absent from file1 → exit 1 ───────────
printf '>notInFile\nACGT\n' > "$TMP/fake.fa"
"$BIN" subtract "$FASTA" "$TMP/fake.fa" >/dev/null 2>/dev/null
if [[ $? -eq 1 ]]; then pass "strict: exits 1 when file2 not a subset"
else fail "strict: expected exit 1 when file2 not a subset"; fi

# ── Test 5: Strict mode – error message on stderr ─────────────────────────────
STDERR=$("$BIN" subtract "$FASTA" "$TMP/fake.fa" 2>&1 >/dev/null)
if echo "$STDERR" | grep -q "not found in"; then
  pass "strict: informative error message on stderr"
else
  fail "strict: no error message on stderr (got: $STDERR)"
fi

# ── Test 6: Relaxed mode – file2 not subset → exit 0 ─────────────────────────
"$BIN" subtract --relaxed "$FASTA" "$TMP/fake.fa" >/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then pass "--relaxed: exits 0 when file2 not a subset"
else fail "--relaxed: expected exit 0"; fi

# ── Test 7: Relaxed mode – all file1 sequences still printed ──────────────────
COUNT=$("$BIN" subtract --relaxed "$FASTA" "$TMP/fake.fa" 2>/dev/null | grep -c '^>')
check_eq "--relaxed: all 12 sequences printed when nothing matches" "$COUNT" 12

# ── Test 8: Subtract file from itself → empty output, exit 0 ─────────────────
"$BIN" subtract "$FASTA" "$FASTA" > "$TMP/empty.fa" 2>/dev/null
if [[ $? -eq 0 ]]; then pass "self-subtract: exits 0"
else fail "self-subtract: expected exit 0"; fi
COUNT=$(grep -c '^>' "$TMP/empty.fa" 2>/dev/null; true)
COUNT=$(echo "$COUNT" | tr -d ' ')
check_eq "self-subtract: output is empty (0 sequences)" "${COUNT:-0}" 0

# ── Test 9: --by-seq – same sequence different name is still subtracted ────────
# Use synthetic data with known-unique sequences so the count is predictable.
printf '>seq1\nACGTACGT\n>seq2\nTTTTTTTT\n>seq3\nAAAAAAAA\n>seq4\nCCCCCCCC\n>seq5\nGGGGGGGG\n' \
  > "$TMP/unique5.fa"
# file2: seq3 content under a different name
printf '>totally_different_name\nAAAAAAAA\n' > "$TMP/renamed_unique.fa"
"$BIN" subtract --by-seq "$TMP/unique5.fa" "$TMP/renamed_unique.fa" > "$TMP/byseq_out.fa" 2>/dev/null
COUNT=$(grep -c '^>' "$TMP/byseq_out.fa")
check_eq "--by-seq: renamed sequence subtracted by content (4 remain)" "$COUNT" 4

# ── Test 10: Without --by-seq the renamed sequence is NOT subtracted ──────────
COUNT=$("$BIN" subtract --relaxed "$TMP/unique5.fa" "$TMP/renamed_unique.fa" 2>/dev/null | grep -c '^>')
check_eq "by-name (default): renamed seq not subtracted, all 5 remain" "$COUNT" 5

# ── Test 11: --strip-comment – default fails to match when comments differ ────
# comments.fasta: "SEQ1_BamHI-EcoRI len=67 cov=120" – key includes comment
printf '>SEQ1_BamHI-EcoRI\nACGT\n' > "$TMP/nocomment.fa"
COUNT=$("$BIN" subtract --relaxed "$FILES/comments.fasta" "$TMP/nocomment.fa" 2>/dev/null | grep -c '^>')
check_eq "--strip-comment absent: no match on name-only entry, all 4 remain" "$COUNT" 4

# ── Test 12: --strip-comment – name-only entry matches correctly ──────────────
"$BIN" subtract --strip-comment "$FILES/comments.fasta" "$TMP/nocomment.fa" > "$TMP/sc_out.fa" 2>/dev/null
COUNT=$(grep -c '^>' "$TMP/sc_out.fa")
check_eq "--strip-comment: matched by name, 3 sequences remain" "$COUNT" 3

# ── Test 13: --strip-comment output preserves comments ────────────────────────
if grep -q 'len=' "$TMP/sc_out.fa"; then
  pass "--strip-comment: comments preserved in output"
else
  fail "--strip-comment: comments missing from output"
fi

# ── Test 14: --strip-pair – no match without flag ─────────────────────────────
printf '>seq1/1\nACGT\n>seq2/1\nTTTT\n>seq3/1\nAAAA\n' > "$TMP/pairs.fa"
printf '>seq2\nTTTT\n' > "$TMP/todel.fa"
COUNT=$("$BIN" subtract --relaxed "$TMP/pairs.fa" "$TMP/todel.fa" 2>/dev/null | grep -c '^>')
check_eq "--strip-pair absent: /1 suffix prevents match, all 3 remain" "$COUNT" 3

# ── Test 15: --strip-pair – /1 suffix stripped before matching ────────────────
"$BIN" subtract --strip-pair "$TMP/pairs.fa" "$TMP/todel.fa" > "$TMP/pair_out.fa" 2>/dev/null
COUNT=$(grep -c '^>' "$TMP/pair_out.fa")
check_eq "--strip-pair: seq2/1 matched via seq2, 2 sequences remain" "$COUNT" 2

# ── Test 16: FASTQ – basic subtraction preserves format ───────────────────────
"$BIN" head -n 3 "$FASTQ" > "$TMP/head3.fq"
"$BIN" subtract "$FASTQ" "$TMP/head3.fq" > "$TMP/fastq_rest.fq" 2>/dev/null
LINES=$(wc -l < "$TMP/fastq_rest.fq")
if [[ $((LINES % 4)) -eq 0 ]]; then
  pass "FASTQ: output line count is multiple of 4 (format intact)"
else
  fail "FASTQ: output has $LINES lines (not multiple of 4)"
fi

# ── Test 17: FASTQ – correct count after subtraction ─────────────────────────
COUNT=$(( LINES / 4 ))
check_eq "FASTQ: subtract 3 from 7 leaves 4" "$COUNT" 4

# ── Test 18: FASTQ – quality line content preserved ──────────────────────────
QUAL_LINES=$(grep -c '^+$' "$TMP/fastq_rest.fq" 2>/dev/null || echo 0)
check_eq "FASTQ: quality separator lines present" "$QUAL_LINES" 4

# ── Test 19: FASTQ – subtract from itself → empty, exit 0 ────────────────────
"$BIN" subtract "$FASTQ" "$FASTQ" > "$TMP/fq_empty.fq" 2>/dev/null
if [[ $? -eq 0 ]]; then pass "FASTQ self-subtract: exits 0"
else fail "FASTQ self-subtract: expected exit 0"; fi
LINES=$(wc -l < "$TMP/fq_empty.fq")
check_eq "FASTQ self-subtract: output is empty" "$LINES" 0

# ── Test 20: ROUNDTRIP – A − B = C  →  A − C = B ─────────────────────────────
# file1 (A) = test.fa (12 seqs)
# file2 (B) = first 5 seqs
# C = remaining 7 seqs
# D = A − C should recover B exactly (same 5 sequence names)
"$BIN" head -n 5 "$FASTA" > "$TMP/rt_B.fa"
"$BIN" subtract "$FASTA" "$TMP/rt_B.fa" > "$TMP/rt_C.fa" 2>/dev/null
"$BIN" subtract "$FASTA" "$TMP/rt_C.fa" > "$TMP/rt_D.fa" 2>/dev/null

COUNT_B=$(grep -c '^>' "$TMP/rt_B.fa")
COUNT_D=$(grep -c '^>' "$TMP/rt_D.fa")
check_eq "roundtrip: D has same count as B ($COUNT_B)" "$COUNT_D" "$COUNT_B"

NAMES_B=$(grep '^>' "$TMP/rt_B.fa" | awk '{print $1}' | sort)
NAMES_D=$(grep '^>' "$TMP/rt_D.fa" | awk '{print $1}' | sort)
if [[ "$NAMES_B" = "$NAMES_D" ]]; then
  pass "roundtrip: D contains the same sequences as B"
else
  fail "roundtrip: sequence names differ between B and D"
fi

# ── Test 21: Verbose output goes to stderr ────────────────────────────────────
"$BIN" subtract --verbose "$FASTA" "$TMP/head4.fa" >/dev/null 2>"$TMP/verbose.txt"
if grep -q "Sequences loaded" "$TMP/verbose.txt"; then
  pass "--verbose: stats written to stderr"
else
  fail "--verbose: stats not found on stderr"
fi
if grep -q "Subtracted" "$TMP/verbose.txt"; then
  pass "--verbose: subtraction count in stderr stats"
else
  fail "--verbose: 'Subtracted' line missing from stderr"
fi

# ── Test 22: Missing file1 exits 1 ────────────────────────────────────────────
"$BIN" subtract "$TMP/nonexistent.fa" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -eq 1 ]]; then pass "missing file1: exits 1"
else fail "missing file1: expected exit 1"; fi

# ── Test 23: Missing file2 exits 1 ────────────────────────────────────────────
"$BIN" subtract "$FASTA" "$TMP/nonexistent.fa" >/dev/null 2>/dev/null
if [[ $? -eq 1 ]]; then pass "missing file2: exits 1"
else fail "missing file2: expected exit 1"; fi

# ── Standalone summary (when not sourced from mini.sh) ────────────────────────
if [[ $IS_SOURCED -eq 0 ]]; then
  echo ""
  echo -e "Results: $PASS passed, $ERRORS failed"
  if [[ $ERRORS -eq 0 ]]; then
    echo -e "$OK: All subtract tests passed"
  else
    exit 1
  fi
fi
