#!/bin/bash
# test-list.sh — integration tests for 'seqfu list'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ -z ${BIN+x} ]]; then
  BIN="${BINDIR:-$DIR/../bin}/seqfu"
fi
FILES="${FILES:-$DIR/../data}"

OK='\033[0;32mOK\033[0m'
FAIL='\033[0;31mFAIL\033[0m'

if [[ -z ${PASS+x} ]];   then PASS=0;   fi
if [[ -z ${ERRORS+x} ]]; then ERRORS=0; fi

IS_SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then IS_SOURCED=1; fi

TMP=$(mktemp -d 2>/dev/null || { mkdir -p "${TMPDIR:-/tmp}/seqfu_list_$$" && echo "${TMPDIR:-/tmp}/seqfu_list_$$"; })
trap 'rm -rf "$TMP"' EXIT

pass() { echo -e "$OK: $1";   PASS=$((PASS+1));   }
fail() { echo -e "$FAIL: $1"; ERRORS=$((ERRORS+1)); }

check_eq() {
  local val
  val=$(echo "$2" | tr -d ' ')
  if [[ "$val" -eq "$3" ]]; then pass "$1 (got $val)";
  else fail "$1: expected $3, got $val"; fi
}

# ── Input files ────────────────────────────────────────────────────────────────
# test.fa        – 12 FASTA sequences (filt.0 .. filt.11), some with comments
# comments.fasta – 4 sequences, all with comments (len= cov= fields)
# comments.fastq – 5 FASTQ reads, some with tabbed comments

FASTA="$FILES/test.fa"
COMMENTS_FA="$FILES/comments.fasta"
COMMENTS_FQ="$FILES/comments.fastq"

# ── Sanity: help exits cleanly ─────────────────────────────────────────────────
"$BIN" list --help >/dev/null 2>&1
if [[ $? -eq 0 ]]; then pass "list --help exits 0"
else fail "list --help returned non-zero"; fi

# ── Test 1: Basic name matching ────────────────────────────────────────────────
printf 'filt.4\nfilt.8\nfilt.10\n' > "$TMP/names.txt"
COUNT=$("$BIN" list "$TMP/names.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "basic: 3 names from list found in FASTA" "$COUNT" 3

# ── Test 2: Only listed names appear in output ────────────────────────────────
OUT=$("$BIN" list "$TMP/names.txt" "$FASTA" 2>/dev/null)
if echo "$OUT" | grep -q '^>filt\.0'; then
  fail "basic: unlisted name filt.0 appeared in output"
else
  pass "basic: unlisted name absent from output"
fi

# ── Test 3: List entries with leading '>' are accepted ────────────────────────
printf '>filt.4\n>filt.8\n>filt.10\n' > "$TMP/gt_names.txt"
COUNT=$("$BIN" list "$TMP/gt_names.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "leading '>': still matches 3 sequences" "$COUNT" 3

# ── Test 4: List entries with leading '@' are accepted ────────────────────────
# Use FASTQ file and '@'-prefixed names
FIRST_FQ=$("$BIN" head -n 1 "$COMMENTS_FQ" 2>/dev/null | grep '^@' | head -1 | cut -c2- | awk '{print $1}')
printf '@%s\n' "$FIRST_FQ" > "$TMP/at_names.txt"
COUNT=$("$BIN" list "$TMP/at_names.txt" "$COMMENTS_FQ" 2>/dev/null | grep -c '^@')
check_eq "leading '@': matches 1 FASTQ sequence" "$COUNT" 1

# ── Test 5: '#' lines in list are treated as comments (ignored) ───────────────
printf '# this is a comment\nfilt.3\n# another comment\nfilt.7\n' > "$TMP/comments.txt"
COUNT=$("$BIN" list "$TMP/comments.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "list comments: '#' lines ignored, 2 sequences matched" "$COUNT" 2

# ── Test 6: Empty lines in list are skipped (defensive fix) ───────────────────
printf 'filt.8\n\nfilt.11\n\n' > "$TMP/empty_lines.txt"
COUNT=$("$BIN" list "$TMP/empty_lines.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "empty lines: skipped, 2 sequences matched" "$COUNT" 2

# ── Test 7: Bare '>' or '@' line in list does not crash ───────────────────────
printf '>\nfilt.4\n' > "$TMP/bare_gt.txt"
COUNT=$("$BIN" list "$TMP/bare_gt.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "bare '>': skipped, 1 valid entry matched" "$COUNT" 1

# ── Test 8: Names absent from FASTA produce no output ────────────────────────
printf 'does_not_exist\nalso_absent\n' > "$TMP/absent.txt"
COUNT=$("$BIN" list "$TMP/absent.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "absent names: no sequences in output" "$COUNT" 0

# ── Test 9: Without --with-comments, name-only entry matches commented seq ────
# comments.fasta has ">SEQ1_BamHI-EcoRI len=67 cov=120"; list has just the name
printf 'SEQ1_BamHI-EcoRI\n' > "$TMP/nameonly.txt"
COUNT=$("$BIN" list "$TMP/nameonly.txt" "$COMMENTS_FA" 2>/dev/null | grep -c '^>')
check_eq "no --with-comments: name-only matches commented sequence" "$COUNT" 1

# ── Test 10: --with-comments, name-only entry does NOT match (key differs) ────
COUNT=$("$BIN" list --with-comments "$TMP/nameonly.txt" "$COMMENTS_FA" 2>/dev/null | grep -c '^>')
check_eq "--with-comments: name-only entry does not match full name+comment key" "$COUNT" 0

# ── Test 11: --with-comments, full name+comment entry matches correctly ────────
printf 'SEQ1_BamHI-EcoRI len=67 cov=120\n' > "$TMP/fullcomment.txt"
COUNT=$("$BIN" list --with-comments "$TMP/fullcomment.txt" "$COMMENTS_FA" 2>/dev/null | grep -c '^>')
check_eq "--with-comments: full name+comment entry matched" "$COUNT" 1

# ── Test 12: --with-comments output preserves the comment ─────────────────────
OUT=$("$BIN" list --with-comments "$TMP/fullcomment.txt" "$COMMENTS_FA" 2>/dev/null)
if echo "$OUT" | grep -q 'len=67'; then
  pass "--with-comments: comment preserved in output header"
else
  fail "--with-comments: comment missing from output header"
fi

# ── Test 13: --min-len skips short list entries ────────────────────────────────
# "ab" (len 2) should be skipped when --min-len 3; "filt.6" (len 6) passes
printf 'ab\nfilt.6\n' > "$TMP/mixed_len.txt"
COUNT=$("$BIN" list --min-len 3 "$TMP/mixed_len.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "--min-len 3: entry shorter than 3 skipped, 1 matched" "$COUNT" 1

# ── Test 14: FASTQ input – output is valid FASTQ ─────────────────────────────
FIRST_FQ=$("$BIN" head -n 1 "$COMMENTS_FQ" 2>/dev/null | grep '^@' | head -1 | cut -c2- | awk '{print $1}')
printf '%s\n' "$FIRST_FQ" > "$TMP/fq_list.txt"
LINES=$("$BIN" list "$TMP/fq_list.txt" "$COMMENTS_FQ" 2>/dev/null | wc -l | tr -d ' ')
if [[ $((LINES % 4)) -eq 0 && $LINES -gt 0 ]]; then
  pass "FASTQ: output line count is multiple of 4 (format intact)"
else
  fail "FASTQ: output has $LINES lines (not valid FASTQ)"
fi

# ── Test 15: --report goes to stderr, not stdout ──────────────────────────────
printf 'filt.4\nfilt.6\n' > "$TMP/rep_list.txt"
STDOUT=$("$BIN" list --report "$TMP/rep_list.txt" "$FASTA" 2>/dev/null)
STDERR=$("$BIN" list --report "$TMP/rep_list.txt" "$FASTA" 2>&1 >/dev/null)
if echo "$STDERR" | grep -q "SEQUENCES REPORT"; then
  pass "--report: report written to stderr"
else
  fail "--report: report not found on stderr"
fi
if echo "$STDOUT" | grep -q "SEQUENCES REPORT"; then
  fail "--report: report leaked to stdout"
else
  pass "--report: report absent from stdout"
fi

# ── Test 16: --report fires once across multiple input files (bug fix) ─────────
# Before the fix, report was printed after each file (inside the file loop).
printf 'filt.4\nfilt.6\n' > "$TMP/rep2_list.txt"
REPORT_COUNT=$("$BIN" list --report "$TMP/rep2_list.txt" "$FASTA" "$FASTA" 2>&1 >/dev/null | grep -c "SEQUENCES REPORT")
check_eq "--report: fires exactly once across 2 input files" "$REPORT_COUNT" 1

# ── Test 17: --report counts are cumulative across files ─────────────────────
# Running the same file twice means filt.4 should be found 2 times total.
FOUND_LINE=$("$BIN" list --report "$TMP/rep2_list.txt" "$FASTA" "$FASTA" 2>&1 >/dev/null | grep "filt\.4")
if echo "$FOUND_LINE" | grep -q "2 times"; then
  pass "--report: cumulative count correct across 2 files (found 2 times)"
else
  fail "--report: expected 'found 2 times' for filt.4 in '$FOUND_LINE'"
fi

# ── Test 18: Missing list file exits non-zero ─────────────────────────────────
"$BIN" list "$TMP/nonexistent_list.txt" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -ne 0 ]]; then pass "missing list file: exits non-zero"
else fail "missing list file: expected non-zero exit"; fi

# ── Test 19: Missing sequence file skips with warning, continues ──────────────
printf 'filt.2\n' > "$TMP/simple.txt"
STDERR=$("$BIN" list "$TMP/simple.txt" "$TMP/nonexistent.fa" 2>&1 >/dev/null)
if echo "$STDERR" | grep -qi "not found\|error"; then
  pass "missing seq file: warning on stderr"
else
  fail "missing seq file: no warning on stderr (got: $STDERR)"
fi

# ── Test 20: Multiple sequence files – names matched across both ───────────────
# Split test.fa into two halves via head/tail by count
"$BIN" head -n 6 "$FASTA" > "$TMP/half1.fa" 2>/dev/null
"$BIN" tail -n 6 "$FASTA" > "$TMP/half2.fa" 2>/dev/null
# Pick one name from each half
NAME1=$(grep '^>' "$TMP/half1.fa" | head -1 | cut -c2- | awk '{print $1}')
NAME2=$(grep '^>' "$TMP/half2.fa" | head -1 | cut -c2- | awk '{print $1}')
printf '%s\n%s\n' "$NAME1" "$NAME2" > "$TMP/cross_list.txt"
COUNT=$("$BIN" list "$TMP/cross_list.txt" "$TMP/half1.fa" "$TMP/half2.fa" 2>/dev/null | grep -c '^>')
check_eq "multiple files: 1 name from each file, 2 matched total" "$COUNT" 2

# ── Test 21: --partial-match: substring matches multiple sequences ─────────────
# "filt.1" is a substring of filt.10, filt.11, and filt.1;size=1000 → 3 hits
printf 'filt.1\n' > "$TMP/partial.txt"
COUNT=$("$BIN" list --partial-match "$TMP/partial.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "--partial-match: 'filt.1' matches 3 sequences (filt.1x, filt.10, filt.11)" "$COUNT" 3

# ── Test 22: --partial-match: exact name still works ─────────────────────────
printf 'filt.4\n' > "$TMP/partial_exact.txt"
COUNT=$("$BIN" list --partial-match "$TMP/partial_exact.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "--partial-match: exact name 'filt.4' matches 1 sequence" "$COUNT" 1

# ── Test 23: --partial-match: multiple list entries matching same sequence ─────
# "filt.1" and "size=" both match "filt.1;size=1000" — should print it only once
printf 'filt.1\nsize=\n' > "$TMP/multi_entry.txt"
# filt.1 matches: filt.1;size=1000, filt.10, filt.11
# size= matches:  filt.1;size=1000, filt.2;size=2
# union = 4 unique sequences, filt.1;size=1000 must not be duplicated
COUNT=$("$BIN" list --partial-match "$TMP/multi_entry.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "--partial-match: sequence matching 2 entries printed once (4 total)" "$COUNT" 4

# ── Test 24: without --partial-match, same entry is exact (no substring hit) ──
printf 'filt.1\n' > "$TMP/exact_only.txt"
COUNT=$("$BIN" list "$TMP/exact_only.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "exact (default): 'filt.1' matches 0 (actual name is filt.1;size=1000)" "$COUNT" 0

# ── Test 25: --partial-match + --strict: no match → exit 1 ───────────────────
printf 'no_such_substring\n' > "$TMP/partial_miss.txt"
"$BIN" list --partial-match --strict "$TMP/partial_miss.txt" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -eq 1 ]]; then pass "--partial-match + --strict: exits 1 when substring never matched"
else fail "--partial-match + --strict: expected exit 1"; fi

# ── Test 26: --partial-match + --strict: match found → exit 0 ────────────────
printf 'filt.1\n' > "$TMP/partial_hit.txt"
"$BIN" list --partial-match --strict "$TMP/partial_hit.txt" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then pass "--partial-match + --strict: exits 0 when substring matched"
else fail "--partial-match + --strict: expected exit 0"; fi

# ── Test 27: --strict exits 0 when all listed names are found ─────────────────
printf 'filt.4\nfilt.8\n' > "$TMP/strict_all.txt"
"$BIN" list --strict "$TMP/strict_all.txt" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then pass "--strict: exits 0 when all names found"
else fail "--strict: expected exit 0 when all names found"; fi

# ── Test 28: --strict exits 1 when a listed name is absent ────────────────────
printf 'filt.4\ndoes_not_exist\n' > "$TMP/strict_miss.txt"
"$BIN" list --strict "$TMP/strict_miss.txt" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -eq 1 ]]; then pass "--strict: exits 1 when a name is missing"
else fail "--strict: expected exit 1 when a name is missing"; fi

# ── Test 29: --strict error message names the missing sequence ────────────────
STDERR=$("$BIN" list --strict "$TMP/strict_miss.txt" "$FASTA" 2>&1 >/dev/null)
if echo "$STDERR" | grep -q "does_not_exist"; then
  pass "--strict: error message identifies the missing name"
else
  fail "--strict: missing name not mentioned in error (got: $STDERR)"
fi

# ── Test 30: --strict still prints matched sequences before erroring ──────────
COUNT=$("$BIN" list --strict "$TMP/strict_miss.txt" "$FASTA" 2>/dev/null | grep -c '^>')
check_eq "--strict: matched sequences printed despite missing name" "$COUNT" 1

# ── Multi-output mode ─────────────────────────────────────────────────────────
OUTDIR="$TMP/multiout"

# ── Test 31: output files created with correct .fasta extension ───────────────
printf 'filt.4\nfilt.8\n'        > "$TMP/mA.txt"
printf 'filt.0\nfilt.6\nfilt.10\n' > "$TMP/mB.txt"
"$BIN" list --outdir "$OUTDIR" --lists "$TMP/mA.txt" --lists "$TMP/mB.txt" "$FASTA" 2>/dev/null
if [[ -f "$OUTDIR/mA.fasta" && -f "$OUTDIR/mB.fasta" ]]; then
  pass "multi: output files named <listbasename>.fasta for FASTA input"
else
  fail "multi: expected mA.fasta and mB.fasta in $OUTDIR"
fi

# ── Test 32: correct sequence counts in each output file ─────────────────────
COUNT_A=$(grep -c '^>' "$OUTDIR/mA.fasta" 2>/dev/null)
COUNT_B=$(grep -c '^>' "$OUTDIR/mB.fasta" 2>/dev/null)
check_eq "multi: mA.fasta contains 2 sequences" "$COUNT_A" 2
check_eq "multi: mB.fasta contains 3 sequences" "$COUNT_B" 3

# ── Test 33: sequences routed to correct file, not cross-contaminated ─────────
if grep -q '^>filt\.0' "$OUTDIR/mA.fasta" 2>/dev/null; then
  fail "multi: filt.0 (mB only) appeared in mA.fasta"
else
  pass "multi: no cross-contamination between output files"
fi

# ── Test 34: FASTQ input → .fastq extension, .gz stripped ────────────────────
OUTDIR2="$TMP/multiout_fq"
FIRST_FQ=$("$BIN" head -n 1 "$COMMENTS_FQ" 2>/dev/null | grep '^@' | head -1 | cut -c2- | awk '{print $1}')
printf '%s\n' "$FIRST_FQ" > "$TMP/fq_list.txt"
"$BIN" list --outdir "$OUTDIR2" --lists "$TMP/fq_list.txt" "$COMMENTS_FQ" 2>/dev/null
if [[ -f "$OUTDIR2/fq_list.fastq" ]]; then
  pass "multi: FASTQ input produces .fastq output"
else
  fail "multi: expected fq_list.fastq in $OUTDIR2 (got: $(ls $OUTDIR2 2>/dev/null))"
fi

# ── Test 35: outdir is created if it doesn't exist ────────────────────────────
"$BIN" list --outdir "$TMP/brand_new_dir" --lists "$TMP/mA.txt" "$FASTA" 2>/dev/null
if [[ -d "$TMP/brand_new_dir" ]]; then
  pass "multi: output directory created automatically"
else
  fail "multi: output directory not created"
fi

# ── Test 36: refuses to overwrite without --force ─────────────────────────────
# mA.fasta already exists from test 31
"$BIN" list --outdir "$OUTDIR" --lists "$TMP/mA.txt" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -ne 0 ]]; then pass "multi: exits non-zero when output file exists without --force"
else fail "multi: should have refused to overwrite existing file"; fi

# ── Test 37: --force overwrites existing files ────────────────────────────────
"$BIN" list --outdir "$OUTDIR" --force --lists "$TMP/mA.txt" "$FASTA" 2>/dev/null
if [[ $? -eq 0 ]]; then pass "multi: --force allows overwriting existing file"
else fail "multi: --force failed to overwrite"; fi

# ── Test 38: --strict in multi mode catches missing names ─────────────────────
printf 'filt.4\nno_such_seq\n' > "$TMP/strict_multi.txt"
"$BIN" list --outdir "$TMP/strict_out" --lists "$TMP/strict_multi.txt" --strict "$FASTA" >/dev/null 2>/dev/null
if [[ $? -eq 1 ]]; then pass "multi + --strict: exits 1 when a name is missing"
else fail "multi + --strict: expected exit 1"; fi

# ── Test 39: missing --lists with --outdir exits non-zero ─────────────────────
"$BIN" list --outdir "$TMP/x" "$FASTA" >/dev/null 2>/dev/null
if [[ $? -ne 0 ]]; then pass "multi: exits non-zero when --outdir given without --lists"
else fail "multi: should error when --outdir without --lists"; fi

# ── Standalone summary ────────────────────────────────────────────────────────
if [[ $IS_SOURCED -eq 0 ]]; then
  echo ""
  echo -e "Results: $PASS passed, $ERRORS failed"
  if [[ $ERRORS -eq 0 ]]; then
    echo -e "$OK: All list tests passed"
  else
    exit 1
  fi
fi
