#!/bin/bash
# test-longtrim.sh - Integration tests for seqfu longtrim
# Can be sourced by test/mini.sh or run standalone.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN="$DIR/../bin/seqfu"

OK='\033[0;32mOK\033[0m'
FAIL='\033[0;31mFAIL\033[0m'

IS_SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  IS_SOURCED=1
fi

# Reuse global counters when sourced; initialise when run standalone.
if [[ -z ${PASS+x} ]]; then
  PASS=0
fi
if [[ -z ${ERRORS+x} ]]; then
  ERRORS=0
fi

echo "=== SeqFu Longtrim Integration Tests ==="

# ---------------------------------------------------------------------------
# Helper: create a 300 bp FASTQ read with uniform quality character Q
# Usage: make_read NAME SEQ_CHAR QUAL_CHAR
# ---------------------------------------------------------------------------
make_read() {
  local name="$1"
  local seqchar="${2:-A}"
  local qualchar="${3:-5}"  # '5' = Phred 20
  local len="${4:-300}"
  local seq
  local qual
  seq=$(python3 -c "print('${seqchar}' * ${len})")
  qual=$(python3 -c "print('${qualchar}' * ${len})")
  printf "@%s\n%s\n+\n%s\n" "$name" "$seq" "$qual"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Test 1: Help exits 0
# ---------------------------------------------------------------------------
"$BIN" longtrim --help >/dev/null 2>&1
MSG="Help exits 0"
if [[ $? -eq 0 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 2: Basic passthrough (-L -Q disables all filtering)
# ---------------------------------------------------------------------------
{
  make_read read1 A 5 300
  make_read read2 C 5 300
  make_read read3 G 5 300
} > "$TMP/basic.fq"

COUNT=$("$BIN" longtrim -L -Q --no-json "$TMP/basic.fq" 2>/dev/null | grep -c '^@')
MSG="Basic passthrough: expected 3 reads, got <$COUNT>"
if [[ "$COUNT" -eq 3 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 3: Length filter (--min-length 200) drops short reads
# ---------------------------------------------------------------------------
{
  make_read short1 A 5 50
  make_read short2 A 5 50
  make_read long1  A 5 300
} > "$TMP/lengths.fq"

COUNT=$("$BIN" longtrim --min-length 200 -Q --no-json "$TMP/lengths.fq" 2>/dev/null | grep -c '^@')
MSG="Length filter --min-length 200: expected 1 read, got <$COUNT>"
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 4: Max length filter (--max-length 250) drops reads > 250bp
# ---------------------------------------------------------------------------
{
  make_read r1 A 5 200
  make_read r2 A 5 300
  make_read r3 A 5 400
} > "$TMP/maxlen.fq"

COUNT=$("$BIN" longtrim --min-length 1 --max-length 250 -Q --no-json "$TMP/maxlen.fq" 2>/dev/null | grep -c '^@')
MSG="Max length filter --max-length 250: expected 1 read, got <$COUNT>"
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 5: Quality filter (unqual%): reads with many bad bases fail
# ---------------------------------------------------------------------------
# '!' = Phred 0 (bad), 'I' = Phred 40 (good)
# Build a 300bp read: 200 bad bases + 100 good = 66.7% bad > 10% limit
BAD_SEQ=$(python3 -c "print('A'*300)")
BAD_QUAL=$(python3 -c "print('!'*200 + 'I'*100)")
GOOD_QUAL=$(python3 -c "print('I'*300)")

{
  printf "@badread\n%s\n+\n%s\n" "$BAD_SEQ" "$BAD_QUAL"
  printf "@goodread\n%s\n+\n%s\n" "$BAD_SEQ" "$GOOD_QUAL"
} > "$TMP/qualfilt.fq"

COUNT=$("$BIN" longtrim -L --unqual-limit 10 --qual-threshold 15 --no-json "$TMP/qualfilt.fq" 2>/dev/null | grep -c '^@')
MSG="Quality filter --unqual-limit 10: expected 1 read, got <$COUNT>"
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 6: Mean quality filter --min-qual 20
# ---------------------------------------------------------------------------
# Phred '5'=20, Phred '+'=10, 'I'=40
HIGH_QUAL=$(python3 -c "print('I'*300)")   # mean=40
LOW_QUAL=$(python3 -c "print('+'*300)")    # mean=10

{
  printf "@highq\n%s\n+\n%s\n" "$BAD_SEQ" "$HIGH_QUAL"
  printf "@lowq\n%s\n+\n%s\n"  "$BAD_SEQ" "$LOW_QUAL"
} > "$TMP/meanqual.fq"

COUNT=$("$BIN" longtrim -L --min-qual 20 --no-json "$TMP/meanqual.fq" 2>/dev/null | grep -c '^@')
MSG="Mean quality filter --min-qual 20: expected 1 read (high Q), got <$COUNT>"
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 7: Fixed trim --trim-front 10 --trim-tail 10 on 300bp → 280bp
# ---------------------------------------------------------------------------
SEQ300=$(python3 -c "print('A'*300)")
QUAL300=$(python3 -c "print('I'*300)")
printf "@r1\n%s\n+\n%s\n" "$SEQ300" "$QUAL300" > "$TMP/fixedtrim.fq"

OUTLEN=$("$BIN" longtrim -L -Q --trim-front 10 --trim-tail 10 --no-json "$TMP/fixedtrim.fq" 2>/dev/null \
         | awk 'NR==2{print length($0)}')
MSG="Fixed trim --trim-front 10 --trim-tail 10: expected 280bp, got <$OUTLEN>"
if [[ "$OUTLEN" -eq 280 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 8: Cut-tail trims low-quality 3' end
# ---------------------------------------------------------------------------
# 200 good bases (Phred 40) + 100 bad (Phred 0)
MIXED_SEQ=$(python3 -c "print('A'*300)")
MIXED_QUAL=$(python3 -c "print('I'*200 + '!'*100)")
printf "@mixed\n%s\n+\n%s\n" "$MIXED_SEQ" "$MIXED_QUAL" > "$TMP/cuttail.fq"

OUTLEN=$("$BIN" longtrim -L -Q --cut-tail --window-size 4 --window-qual 20 --no-json "$TMP/cuttail.fq" 2>/dev/null \
         | awk 'NR==2{print length($0)}')
MSG="Cut-tail trims low-quality 3' end: output len should be < 300, got <$OUTLEN>"
if [[ "$OUTLEN" -lt 300 && "$OUTLEN" -gt 0 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 9: Poly-X trim removes 3' poly-A tail
# ---------------------------------------------------------------------------
# 280 normal bases + 20 A's
POLYX_SEQ=$(python3 -c "print('ACGT'*70 + 'A'*20)")
POLYX_QUAL=$(python3 -c "print('I'*300)")
printf "@polyx\n%s\n+\n%s\n" "$POLYX_SEQ" "$POLYX_QUAL" > "$TMP/polyx.fq"

OUTLEN=$("$BIN" longtrim -L -Q --trim-poly-x --poly-x-min 10 --no-json "$TMP/polyx.fq" 2>/dev/null \
         | awk 'NR==2{print length($0)}')
MSG="Poly-X trim removes poly-A tail: output len should be < 300, got <$OUTLEN>"
if [[ "$OUTLEN" -lt 300 && "$OUTLEN" -gt 0 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 10: GC filter --min-gc 50 --max-gc 70
# ---------------------------------------------------------------------------
# All A's = 0% GC → fail low GC
# All G's = 100% GC → fail high GC
# ACGT repeated = 50% GC → pass
SEQ_LOW_GC=$(python3 -c "print('A'*300)")
SEQ_HIGH_GC=$(python3 -c "print('G'*300)")
SEQ_MID_GC=$(python3 -c "print('ACGT'*75)")
QUAL300=$(python3 -c "print('I'*300)")

{
  printf "@low_gc\n%s\n+\n%s\n"  "$SEQ_LOW_GC"  "$QUAL300"
  printf "@high_gc\n%s\n+\n%s\n" "$SEQ_HIGH_GC" "$QUAL300"
  printf "@mid_gc\n%s\n+\n%s\n"  "$SEQ_MID_GC"  "$QUAL300"
} > "$TMP/gc.fq"

COUNT=$("$BIN" longtrim -L -Q --min-gc 50 --max-gc 70 --no-json "$TMP/gc.fq" 2>/dev/null | grep -c '^@')
MSG="GC filter --min-gc 50 --max-gc 70: expected 1 read, got <$COUNT>"
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 11: Low complexity filter on homopolymer read
# ---------------------------------------------------------------------------
# All A's → 0% complexity → should fail with -y
SEQ_HOMO=$(python3 -c "print('A'*300)")
QUAL300=$(python3 -c "print('I'*300)")
printf "@homo\n%s\n+\n%s\n" "$SEQ_HOMO" "$QUAL300" > "$TMP/homo.fq"

COUNT=$("$BIN" longtrim -L -Q --low-complexity --complexity 30 --no-json "$TMP/homo.fq" 2>/dev/null | grep -c '^@')
MSG="Low complexity filter: homopolymer read fails (-y), expected 0, got <$COUNT>"
if [[ "$COUNT" -eq 0 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 12: --failed-out writes failing reads to separate file
# ---------------------------------------------------------------------------
{
  make_read short_read A 5 50
  make_read long_read  A 5 300
} > "$TMP/failed_out_input.fq"

"$BIN" longtrim --min-length 200 -Q --no-json \
  --failed-out "$TMP/failed.fq" \
  "$TMP/failed_out_input.fq" >/dev/null 2>/dev/null

FAIL_COUNT=$(grep -c '^@' "$TMP/failed.fq" 2>/dev/null || echo 0)
MSG="--failed-out: failing reads written to file, expected 1, got <$FAIL_COUNT>"
if [[ "$FAIL_COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# Check failure reason is annotated in the read name
FAIL_REASON=$(grep '^@' "$TMP/failed.fq" 2>/dev/null | grep -c 'FAIL')
MSG="--failed-out: failure reason in read name"
if [[ "$FAIL_REASON" -ge 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 13: JSON output contains required keys
# ---------------------------------------------------------------------------
{
  make_read r1 A 5 300
} > "$TMP/json_test.fq"

"$BIN" longtrim -L -Q --json "$TMP/out.json" "$TMP/json_test.fq" >/dev/null 2>/dev/null

MSG="JSON output: file created"
if [[ -f "$TMP/out.json" ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

MSG="JSON output: contains seqfu_version key"
if grep -q '"seqfu_version"' "$TMP/out.json" 2>/dev/null; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

MSG="JSON output: contains summary key"
if grep -q '"summary"' "$TMP/out.json" 2>/dev/null; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

MSG="JSON output: contains histograms key"
if grep -q '"histograms"' "$TMP/out.json" 2>/dev/null; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 14: --no-json skips JSON report
# ---------------------------------------------------------------------------
{
  make_read r1 A 5 300
} > "$TMP/nojson_test.fq"

"$BIN" longtrim -L -Q --no-json --json "$TMP/nojson_out.json" "$TMP/nojson_test.fq" >/dev/null 2>/dev/null

MSG="--no-json: JSON file not written"
if [[ ! -f "$TMP/nojson_out.json" ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 15: stdin passthrough
# ---------------------------------------------------------------------------
{
  make_read r1 A 5 300
  make_read r2 C 5 300
} > "$TMP/stdin_test.fq"

COUNT=$(cat "$TMP/stdin_test.fq" | "$BIN" longtrim -L -Q --no-json 2>/dev/null | grep -c '^@')
MSG="stdin passthrough: expected 2 reads, got <$COUNT>"
if [[ "$COUNT" -eq 2 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 16: --filt-top 0.5 keeps top half by quality from 4 reads
# ---------------------------------------------------------------------------
# Two reads with high quality (I=Phred40), two with low quality (+=Phred10)
SEQBASE=$(python3 -c "print('ACGT'*75)")
HQ=$(python3 -c "print('I'*300)")
LQ=$(python3 -c "print('+'*300)")

{
  printf "@hq1\n%s\n+\n%s\n" "$SEQBASE" "$HQ"
  printf "@hq2\n%s\n+\n%s\n" "$SEQBASE" "$HQ"
  printf "@lq1\n%s\n+\n%s\n" "$SEQBASE" "$LQ"
  printf "@lq2\n%s\n+\n%s\n" "$SEQBASE" "$LQ"
} > "$TMP/filttop.fq"

COUNT=$("$BIN" longtrim -L -Q --filt-top 0.5 --no-json "$TMP/filttop.fq" 2>/dev/null | grep -c '^@')
MSG="--filt-top 0.5: expected 2 reads from 4, got <$COUNT>"
if [[ "$COUNT" -eq 2 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 17: --filt-top with stdin must fail with error
# ---------------------------------------------------------------------------
"$BIN" longtrim --filt-top 0.5 --no-json 2>&1 </dev/null | grep -qi "error"
MSG="--filt-top with stdin returns error message"
if [[ $? -eq 0 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 18: gzip input accepted
# ---------------------------------------------------------------------------
{
  make_read gz1 A 5 300
  make_read gz2 C 5 300
} | gzip > "$TMP/gzin.fq.gz"

COUNT=$("$BIN" longtrim -L -Q --no-json "$TMP/gzin.fq.gz" 2>/dev/null | grep -c '^@')
MSG="gzip input: expected 2 reads, got <$COUNT>"
if [[ "$COUNT" -eq 2 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Test 19: N base filter --max-n-pct 5
# ---------------------------------------------------------------------------
# Read with 50% N bases
N_SEQ=$(python3 -c "print('N'*150 + 'A'*150)")
GOOD_QUAL=$(python3 -c "print('I'*300)")
CLEAN_SEQ=$(python3 -c "print('A'*300)")

{
  printf "@highN\n%s\n+\n%s\n" "$N_SEQ"   "$GOOD_QUAL"
  printf "@cleanN\n%s\n+\n%s\n" "$CLEAN_SEQ" "$GOOD_QUAL"
} > "$TMP/nfilt.fq"

COUNT=$("$BIN" longtrim -L --max-n-pct 5 --no-json "$TMP/nfilt.fq" 2>/dev/null | grep -c '^@')
MSG="N filter --max-n-pct 5: expected 1 read, got <$COUNT>"
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# Final summary (only when run standalone)
# ---------------------------------------------------------------------------
if [[ "$IS_SOURCED" -eq 0 ]]; then
  echo ""
  if [[ "$ERRORS" -eq 0 ]]; then
    echo -e "$OK: All $PASS longtrim tests passed"
  else
    echo -e "$FAIL: $ERRORS test(s) failed ($PASS passed)"
    exit 1
  fi
fi
