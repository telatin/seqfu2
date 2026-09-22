#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN="$DIR/../bin/seqfu"

OK='\033[0;32mOK\033[0m'
FAIL='\033[0;31mFAIL\033[0m'
IS_SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    IS_SOURCED=1
fi

# When sourced from test/mini.sh, reuse global counters.
if [[ -z ${PASS+x} ]]; then
    PASS=0
fi
if [[ -z ${ERRORS+x} ]]; then
    ERRORS=0
fi

echo "=== SeqFu Trim Integration Tests ==="

# Test 1: Single-end basic
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_1.fq 2>/dev/null
COUNT=$($BIN count /tmp/test_trim_1.fq 2>/dev/null | cut -f2)
MSG="Single-end basic trimming: expected 7 reads, got <$COUNT>"
if [[ "$COUNT" -eq 7 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 2: Paired-end auto-detection
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_2 2>/dev/null
MSG="Paired-end auto-detection: R1 output created"
if [[ -f /tmp/test_trim_2_R1.fastq ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Paired-end auto-detection: R2 output created"
if [[ -f /tmp/test_trim_2_R2.fastq ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

R1_COUNT=$($BIN stats /tmp/test_trim_2_R1.fastq 2>/dev/null | tail -1 | awk '{print $2}')
R2_COUNT=$($BIN stats /tmp/test_trim_2_R2.fastq 2>/dev/null | tail -1 | awk '{print $2}')
MSG="Paired-end auto-detection: R1 and R2 counts match (R1=$R1_COUNT, R2=$R2_COUNT)"
if [[ "$R1_COUNT" -eq "$R2_COUNT" ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 2b: Paired-end auto-detection with _R1_ / _R2_ tags
TMP_TRIM_REGEX=$(mktemp -d)
gzip -dc "$DIR/../data/illumina_1.fq.gz" > "$TMP_TRIM_REGEX/sample_R1_unit.fq"
gzip -dc "$DIR/../data/illumina_2.fq.gz" > "$TMP_TRIM_REGEX/sample_R2_unit.fq"
$BIN trim -1 "$TMP_TRIM_REGEX/sample_R1_unit.fq" -o "$TMP_TRIM_REGEX/out" 2>/dev/null
R1_COUNT=$($BIN stats "$TMP_TRIM_REGEX/out_R1.fastq" 2>/dev/null | tail -1 | awk '{print $2}')
R2_COUNT=$($BIN stats "$TMP_TRIM_REGEX/out_R2.fastq" 2>/dev/null | tail -1 | awk '{print $2}')
MSG="Paired-end auto-detection: _R1_ and _R2_ regex tags match (R1=$R1_COUNT, R2=$R2_COUNT)"
if [[ -f "$TMP_TRIM_REGEX/out_R1.fastq" && -f "$TMP_TRIM_REGEX/out_R2.fastq" && "$R1_COUNT" -eq "$R2_COUNT" ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi
rm -rf "$TMP_TRIM_REGEX"

# Test 3: Paired-end with explicit R2
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -2 $DIR/../data/illumina_2.fq.gz -o /tmp/test_trim_3 2>/dev/null
MSG="Paired-end explicit R2: R1 output created"
if [[ -f /tmp/test_trim_3_R1.fastq ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Paired-end explicit R2: R2 output created"
if [[ -f /tmp/test_trim_3_R2.fastq ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 3b: Paired-end mismatched files fail while streaming
gzip -dc "$DIR/../data/illumina_1.fq.gz" > /tmp/test_trim_short_R1.fq
gzip -dc "$DIR/../data/illumina_2.fq.gz" | head -n 24 > /tmp/test_trim_short_R2.fq
$BIN trim -1 /tmp/test_trim_short_R1.fq -2 /tmp/test_trim_short_R2.fq -o /tmp/test_trim_short 2>/tmp/test_trim_short.err
RET=$?
MSG="Paired-end mismatched files fail (R2 shorter)"
if [[ $RET -ne 0 ]] && grep -q "R2 ended prematurely" /tmp/test_trim_short.err; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 4: Quality filtering reduces reads
BEFORE=$($BIN count $DIR/../data/illumina_1.fq.gz 2>/dev/null | cut -f2)
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_4.fq --avg-qual 35 -l 100 2>/dev/null
AFTER=$($BIN count /tmp/test_trim_4.fq 2>/dev/null | cut -f2)
MSG="Quality filtering reduces reads (before=$BEFORE, after=$AFTER)"
if [[ "$AFTER" -le "$BEFORE" ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 5: JSON stats export
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_5.fq --stats-json /tmp/test_trim_stats.json 2>/dev/null
MSG="JSON stats file created"
if [[ -f /tmp/test_trim_stats.json ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="JSON stats contains 'version' field"
if grep -q "version" /tmp/test_trim_stats.json 2>/dev/null; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 6: Presets
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_strict.fq --preset strict 2>/dev/null
RET=$?
MSG="Preset 'strict' exits successfully"
if [[ $RET -eq 0 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_lenient.fq --preset lenient 2>/dev/null
RET=$?
MSG="Preset 'lenient' exits successfully"
if [[ $RET -eq 0 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 7: Custom suffixes
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_custom \
  --r1-suffix .forward.fq --r2-suffix .reverse.fq 2>/dev/null
MSG="Custom R1 suffix (.forward.fq) created"
if [[ -f /tmp/test_trim_custom.forward.fq ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Custom R2 suffix (.reverse.fq) created"
if [[ -f /tmp/test_trim_custom.reverse.fq ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 8: Disable quality filtering
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_noq.fq -Q 2>/dev/null
COUNT=$($BIN count /tmp/test_trim_noq.fq 2>/dev/null | cut -f2)
MSG="Disable quality filtering (-Q): expected 7 reads, got <$COUNT>"
if [[ "$COUNT" -eq 7 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 8b: gzip output is valid and decompresses to the plain output
$BIN trim "$DIR/../data/illumina_1.fq.gz" -o /tmp/test_trim_compress.fq 2>/dev/null
$BIN trim "$DIR/../data/illumina_1.fq.gz" -o /tmp/test_trim_compress.fq.gz -z 2>/dev/null
MSG="Compressed single-end output is valid gzip and matches plain output"
if gzip -t /tmp/test_trim_compress.fq.gz 2>/dev/null && \
   cmp -s /tmp/test_trim_compress.fq <(gzip -dc /tmp/test_trim_compress.fq.gz); then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 8c: paired compression produces discoverable .gz outputs
$BIN trim -1 "$DIR/../data/illumina_1.fq.gz" -o /tmp/test_trim_compress_pe -z 2>/dev/null
MSG="Compressed paired-end outputs use .gz names and contain valid gzip streams"
if [[ -f /tmp/test_trim_compress_pe_R1.fastq.gz ]] && \
   [[ -f /tmp/test_trim_compress_pe_R2.fastq.gz ]] && \
   gzip -t /tmp/test_trim_compress_pe_R1.fastq.gz 2>/dev/null && \
   gzip -t /tmp/test_trim_compress_pe_R2.fastq.gz 2>/dev/null; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 8d: compressed stdout is a valid gzip stream
$BIN trim "$DIR/../data/illumina_1.fq.gz" -z > /tmp/test_trim_stdout.fq.gz 2>/dev/null
MSG="Compressed stdout is a valid gzip stream"
if gzip -t /tmp/test_trim_stdout.fq.gz 2>/dev/null; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 8e: --offset applies to quality filtering as well as trimming
cat > /tmp/test_trim_offset.fq <<'EOF'
@offset-test
ACGT
+
@@@@
EOF
$BIN trim /tmp/test_trim_offset.fq -o /tmp/test_trim_offset33.fq \
  --offset 33 --cut-tail-qual 0 --qualified-qual 15 -l 1 2>/dev/null
$BIN trim /tmp/test_trim_offset.fq -o /tmp/test_trim_offset64.fq \
  --offset 64 --cut-tail-qual 0 --qualified-qual 15 -l 1 2>/dev/null
COUNT33=$($BIN count /tmp/test_trim_offset33.fq 2>/dev/null | cut -f2)
COUNT64=$($BIN count /tmp/test_trim_offset64.fq 2>/dev/null | cut -f2)
MSG="Quality filtering honors --offset (Phred+33=$COUNT33, Phred+64=$COUNT64)"
if [[ "$COUNT33" -eq 1 && "$COUNT64" -eq 0 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 8f: malformed and out-of-range numeric options fail before output creation
INVALID_NUMERIC_CASES=(
  "--trim-tail -1"
  "--cut-tail-window 0"
  "--unqualified-percent 101"
  "--complexity-threshold nan"
  "--threads 0"
  "--batch-size 0"
  "--offset 40"
  "--min-length 20 --max-length 10"
  "--avg-qual nope"
)
NUMERIC_FAILURES=0
for invalid_args in "${INVALID_NUMERIC_CASES[@]}"; do
    rm -f /tmp/test_trim_invalid.fq
    # Intentional word splitting expands each option/value pair in this fixed test matrix.
    $BIN trim "$DIR/../data/illumina_1.fq.gz" -o /tmp/test_trim_invalid.fq $invalid_args \
      2>/tmp/test_trim_invalid.err
    RET=$?
    if [[ $RET -eq 0 || -e /tmp/test_trim_invalid.fq ]] || \
       ! grep -q "ERROR:" /tmp/test_trim_invalid.err; then
        NUMERIC_FAILURES=$((NUMERIC_FAILURES+1))
    fi
done
MSG="Invalid numeric options are rejected before output creation"
if [[ $NUMERIC_FAILURES -eq 0 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG ($NUMERIC_FAILURES cases accepted or created output)"
    ERRORS=$((ERRORS+1))
fi

# Cleanup intermediate files
rm -f /tmp/test_trim_* /tmp/test_trim_stats.json

# Test 9: Threading consistency (single vs multi-threaded)
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_t1.fq -t 1 2>/dev/null
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_t4.fq -t 4 --batch-size 2 2>/dev/null
MSG="Threading consistency: single vs multi-threaded output matches"
if diff -q /tmp/test_t1.fq /tmp/test_t4.fq >/dev/null 2>&1; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Test 10: Paired-end threading consistency
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_pe_t1 -t 1 2>/dev/null
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_pe_t4 -t 4 --batch-size 2 2>/dev/null
MSG="Paired-end threading: R1 matches across thread counts"
if diff -q /tmp/test_pe_t1_R1.fastq /tmp/test_pe_t4_R1.fastq >/dev/null 2>&1; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Paired-end threading: R2 matches across thread counts"
if diff -q /tmp/test_pe_t1_R2.fastq /tmp/test_pe_t4_R2.fastq >/dev/null 2>&1; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

rm -f /tmp/test_t* /tmp/test_pe_*

if [[ $IS_SOURCED -eq 0 ]]; then
    echo ""
    echo -e "Results: $PASS passed, $ERRORS failed"
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "$OK: All tests passed"
    else
        exit 1
    fi
fi
