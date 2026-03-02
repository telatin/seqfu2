#!/bin/bash

# Single file
TMP=$(mktemp)
"$BINDIR"/seqfu stats --basename "$iAmpli" > "$TMP"

WC=$(cat "$TMP" | wc -l | grep -o '[[:digit:]]\+')
SEQS=$(cat "$TMP" | tail -n 1 | cut -f 2)
TOT=$(cat "$TMP" | tail -n 1 | cut -f 3)
N50=$(cat "$TMP" | tail -n 1 | cut -f 5)

MSG="Checking normal output expecting 2 lines: <$WC>"
if [[ $WC == 2 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi


MSG="Checking normal output expecting total seqs 78730: <$SEQS>"
if [[ "$SEQS" == 78730 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Checking normal output expecting total bases 24299931: <$TOT>"
if [[ "$TOT" == 24299931 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Checking normal N50 to be 316: <$N50>"
if [[ $N50 == 316 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --basename --csv "$iAmpli" > "$TMP"
N50=$(cat "$TMP" | tail -n 1 | cut -f 5 -d ,)
MSG="Checking CSV output N50 is 316, got: <$N50>"
if [[ $N50 == 316 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Nice output
"$BINDIR"/seqfu stats --basename --nice "$iAmpli" > "$TMP"
WC=$(cat "$TMP" | grep . | wc -l | grep -o '[[:digit:]]\+')
if [[ "$WC" == 5 ]]; then
    echo -e "$OK: Checking nice output expecting 5 lines: <$WC>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Checking nice output expecting 5 lines: <$WC>"
    ERRORS=$((ERRORS+1))
fi

# Json 
TMP2=$(mktemp)
"$BINDIR"/seqfu stats --basename --json --multiqc "$TMP2" "$iAmpli" > "$TMP"
WC=$(cat "$TMP" | grep . | wc -l | grep -o '[[:digit:]]\+')
WC2=$(cat "$TMP2" | grep . | wc -l | grep -o '[[:digit:]]\+')
if [[ "$WC2" == 39 ]]; then
    echo -e "$OK: Checking MultiQC output expecting 39 lines: <$WC2>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Checking MultiQC output expecting 39 lines: <$WC2>"
    ERRORS=$((ERRORS+1))
fi

if [[ $WC == 1 ]]; then
    echo -e "$OK: Experimental JSON output on 1 line: <$WC>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Experimental JSON output on 1 line: <$WC>"
    ERRORS=$((ERRORS+1))
fi
# Multi file 

# Default sort
"$BINDIR"/seqfu stats --basename  "$iAmpli" "$iSort" "$iMini" > "$TMP"
# Sort by N50 descending
"$BINDIR"/seqfu stats --basename  --sort n50 --reverse  "$iAmpli" "$iSort" "$iMini" > "$TMP2"

FILT=$(cat "$TMP" | head -n 2 | tail -n 1 | cut -f 1)
MSG="Checking default starting  by 'filt': <$FILT>"
if [[ "$FILT" == "filt" ]];  then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

FILT=$(cat "$TMP2" | head -n 2 |tail -n 1 | cut -f 1)
MSG="Checking default N50 starting by 'sort': <$FILT>"
if [[ "$FILT" == "sort" ]];  then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

#/////


"$BINDIR"/seqfu stats -a "$FILES"/prot.faa "$FILES"/prot2.faa "$FILES"/test.fa "$FILES"/test.fasta "$FILES"/test.fastq "$FILES"/test2.fastq "$FILES"/test_4.fa.gz | grep -v "Total bp" > "$TMP"

MSG="Check absolute paths"
if [[ $(grep ^/ "$TMP" | cut -c 1 | sort | head -n 1 ) == "/" ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: "
    ERRORS=$((ERRORS+1))
fi

MSG="Check sort orded when not specified"
A=$(basename $(head -n 1 "$TMP" | cut -f 1 ) )
if [[ "$A" == "prot.faa" ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $A"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats -a  --sort tot "$FILES"/prot.faa "$FILES"/prot2.faa "$FILES"/test.fa "$FILES"/test.fasta "$FILES"/test.fastq "$FILES"/test2.fastq "$FILES"/test_4.fa.gz | grep -v "Total bp" > "$TMP"
MSG="Check sort: tot seq sorted at 3300"
if [[ $(head -n 1 "$TMP" | cut -f 3 ) == 3300 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG:$(head -n 1 "$TMP" | cut -f 3 ) "
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats -a  --sort tot --reverse "$FILES"/prot.faa "$FILES"/prot2.faa "$FILES"/test.fa "$FILES"/test.fasta "$FILES"/test.fastq "$FILES"/test2.fastq "$FILES"/test_4.fa.gz | grep -v "Total bp" > "$TMP"
MSG="Check reverse sort: tot seq sorted at 3300"
if [[ $(tail -n 1 "$TMP" | cut -f 3 ) == 3300 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG:$(head -n 1 "$TMP" | cut -f 3 ) "
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --gc "$FILES"/gc/1.fa | grep -v "Total bp" > "$TMP"
MSG="%GC check at 1.00"
OUT=$(cut -f 11 "$TMP" )
if [[ "$OUT" == 1.00 ]]; then
   echo -e "$OK: $MSG: <$OUT>"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG expected 1.00 got $OUT"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --gc "$FILES"/gc/2.fa | grep -v "Total bp" > "$TMP"
MSG="%GC check at 0.00"
OUT=$(cut -f 11 "$TMP" )
if [[ "$OUT" == 0.00 ]]; then
   echo -e "$OK: $MSG: <$OUT>"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG expected 0.00 got $OUT"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --gc "$FILES"/gc/3.fa | grep -v "Total bp" > "$TMP"
MSG="%GC check at 0.50"
OUT=$(cut -f 11 "$TMP" )
if [[ "$OUT" == 0.50 ]]; then
   echo -e "$OK: $MSG: <$OUT>"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG expected 0.50 got $OUT"
    ERRORS=$((ERRORS+1))
fi

# Invalid sort key must fail with non-zero exit status.
"$BINDIR"/seqfu stats --sort-by definitely_not_a_key "$iAmpli" >/dev/null 2>/dev/null
RET=$?
MSG="Invalid --sort-by exits non-zero"
if [[ $RET -ne 0 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Malformed input must not be rendered as a fake all-zero data row.
BAD=$(mktemp)
echo "this_is_not_fastx" > "$BAD"
"$BINDIR"/seqfu stats "$BAD" > "$TMP" 2>/dev/null
RET=$?
ROWS=$(tail -n +2 "$TMP" | grep -c . || true)
MSG="Malformed input does not produce a data row and exits non-zero"
if [[ $RET -ne 0 && $ROWS -eq 0 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (ret=$RET rows=$ROWS)"
    ERRORS=$((ERRORS+1))
fi
rm -f "$BAD"

# MultiQC output must include numeric GC values even when --gc is not set.
TMPMQC=$(mktemp)
"$BINDIR"/seqfu stats --multiqc "$TMPMQC" "$iAmpli" > /dev/null
GCVAL=$(tail -n 1 "$TMPMQC" | cut -f 11)
MSG="MultiQC GC is not NaN without --gc"
if [[ "$GCVAL" != "NaN" && "$GCVAL" != "nan" && -n "$GCVAL" ]]; then
   echo -e "$OK: $MSG (<$GCVAL>)"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (<$GCVAL>)"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMPMQC"

# Threaded stats must match single-thread output (input order and sorted order).
TMPTH1=$(mktemp)
TMPTH2=$(mktemp)
"$BINDIR"/seqfu stats --threads 1 "$iAmpli" "$iSort" "$iMini" > "$TMPTH1"
"$BINDIR"/seqfu stats --threads 2 "$iAmpli" "$iSort" "$iMini" > "$TMPTH2"
MSG="--threads 2 matches --threads 1 in default output"
if diff -q "$TMPTH1" "$TMPTH2" >/dev/null; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --sort-by n50 --threads 1 "$iAmpli" "$iSort" "$iMini" > "$TMPTH1"
"$BINDIR"/seqfu stats --sort-by n50 --threads 2 "$iAmpli" "$iSort" "$iMini" > "$TMPTH2"
MSG="--threads 2 matches --threads 1 with sorting"
if diff -q "$TMPTH1" "$TMPTH2" >/dev/null; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMPTH1" "$TMPTH2"

# Invalid thread count must fail.
"$BINDIR"/seqfu stats --threads 0 "$iAmpli" >/dev/null 2>/dev/null
RET=$?
MSG="Invalid --threads exits non-zero"
if [[ $RET -ne 0 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# JSON output should keep numeric fields as numbers (not quoted strings).
TMPJSON=$(mktemp)
"$BINDIR"/seqfu stats --json "$iAmpli" > "$TMPJSON"
HAS_NUMERIC_COUNT=$(jq -r '.[0].Count | type' "$TMPJSON" 2>/dev/null || true)
HAS_STRING_FILENAME=$(jq -r '.[0].Filename | type' "$TMPJSON" 2>/dev/null || true)
MSG="JSON Count is numeric and Filename is string"
if [[ "$HAS_NUMERIC_COUNT" == "number" && "$HAS_STRING_FILENAME" == "string" ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (CountType=$HAS_NUMERIC_COUNT FilenameType=$HAS_STRING_FILENAME)"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMPJSON"
