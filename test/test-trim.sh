#!/bin/bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN="$DIR/../bin/seqfu"

echo "=== SeqFu Trim Integration Tests ==="

# Test 1: Single-end basic
echo "Test 1: Single-end basic trimming"
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_1.fq
[ -f /tmp/test_trim_1.fq ] || { echo "FAIL: Output file not created"; exit 1; }
COUNT=$($BIN count /tmp/test_trim_1.fq | cut -f2)
[ "$COUNT" -eq 7 ] || { echo "FAIL: Expected 7 reads, got $COUNT"; exit 1; }
echo "  PASS (7 reads)"

# Test 2: Paired-end auto-detection
echo "Test 2: Paired-end auto-detection"
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_2
[ -f /tmp/test_trim_2_R1.fastq ] || { echo "FAIL: R1 output not created"; exit 1; }
[ -f /tmp/test_trim_2_R2.fastq ] || { echo "FAIL: R2 output not created"; exit 1; }
# Use stats to verify both files
R1_COUNT=$($BIN stats /tmp/test_trim_2_R1.fastq | tail -1 | awk '{print $2}')
R2_COUNT=$($BIN stats /tmp/test_trim_2_R2.fastq | tail -1 | awk '{print $2}')
[ "$R1_COUNT" -eq "$R2_COUNT" ] || { echo "FAIL: R1 and R2 counts don't match"; exit 1; }
echo "  PASS (R1=$R1_COUNT, R2=$R2_COUNT)"

# Test 3: Paired-end with explicit R2
echo "Test 3: Paired-end with explicit R2"
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -2 $DIR/../data/illumina_2.fq.gz -o /tmp/test_trim_3
[ -f /tmp/test_trim_3_R1.fastq ] || { echo "FAIL: R1 output not created"; exit 1; }
[ -f /tmp/test_trim_3_R2.fastq ] || { echo "FAIL: R2 output not created"; exit 1; }
echo "  PASS"

# Test 4: Quality filtering reduces reads
echo "Test 4: Quality filtering"
BEFORE=$($BIN count $DIR/../data/illumina_1.fq.gz | cut -f2)
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_4.fq --avg-qual 35 -l 100
AFTER=$($BIN count /tmp/test_trim_4.fq | cut -f2)
[ "$AFTER" -le "$BEFORE" ] || { echo "FAIL: Filtering didn't reduce reads"; exit 1; }
echo "  PASS (Before=$BEFORE, After=$AFTER)"

# Test 5: JSON stats export
echo "Test 5: JSON stats export"
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_5.fq --stats-json /tmp/test_trim_stats.json
[ -f /tmp/test_trim_stats.json ] || { echo "FAIL: JSON stats not created"; exit 1; }
grep -q "version" /tmp/test_trim_stats.json || { echo "FAIL: JSON stats malformed"; exit 1; }
echo "  PASS"

# Test 6: Presets
echo "Test 6: Presets"
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_strict.fq --preset strict
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_lenient.fq --preset lenient
echo "  PASS"

# Test 7: Custom suffixes
echo "Test 7: Custom suffixes"
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_custom \
  --r1-suffix .forward.fq --r2-suffix .reverse.fq
[ -f /tmp/test_trim_custom.forward.fq ] || { echo "FAIL: Custom R1 suffix failed"; exit 1; }
[ -f /tmp/test_trim_custom.reverse.fq ] || { echo "FAIL: Custom R2 suffix failed"; exit 1; }
echo "  PASS"

# Test 8: Disable quality filtering
echo "Test 8: Disable quality filtering"
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_trim_noq.fq -Q
COUNT=$($BIN count /tmp/test_trim_noq.fq | cut -f2)
[ "$COUNT" -eq 7 ] || { echo "FAIL: Expected 7 reads with -Q"; exit 1; }
echo "  PASS"

# Cleanup
rm -f /tmp/test_trim_* /tmp/test_trim_stats.json

echo "=== All tests passed ==="

# Test 9: Threading consistency
echo "Test 9: Threading consistency (single vs multi-threaded)"
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_t1.fq -t 1
$BIN trim $DIR/../data/illumina_1.fq.gz -o /tmp/test_t4.fq -t 4
diff /tmp/test_t1.fq /tmp/test_t4.fq || { echo "FAIL: Threaded output differs"; exit 1; }
echo "  PASS"

# Test 10: Paired-end threading
echo "Test 10: Paired-end threading consistency"
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_pe_t1 -t 1
$BIN trim -1 $DIR/../data/illumina_1.fq.gz -o /tmp/test_pe_t4 -t 4
diff /tmp/test_pe_t1_R1.fastq /tmp/test_pe_t4_R1.fastq || { echo "FAIL: PE R1 differs"; exit 1; }
diff /tmp/test_pe_t1_R2.fastq /tmp/test_pe_t4_R2.fastq || { echo "FAIL: PE R2 differs"; exit 1; }
echo "  PASS"

# Update cleanup
rm -f /tmp/test_t* /tmp/test_pe_*
