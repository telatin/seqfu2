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

# Cleanup intermediate files
rm -f /tmp/test_trim_* /tmp/test_trim_stats.json

# Test 9: Threading consistency (single vs multi-threaded)
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_t1.fq -t 1 2>/dev/null
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_t4.fq -t 4 2>/dev/null
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
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_pe_t4 -t 4 2>/dev/null
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
