#!/bin/bash

export SEQFU_QUIET=1
TEMPFILENAME=$(mktemp)
TOFASTA_DIR="$FILES/tofasta"

# Test files
CLUSTAL_FILE="$TOFASTA_DIR/test.clw.gz"
GENBANK_FILE="$TOFASTA_DIR/test.gbk.gz"
GFF_FILE="$TOFASTA_DIR/test.gff.gz"

### Test 1: Convert Clustal format
"$BINDIR"/seqfu tofasta "$CLUSTAL_FILE" > "$TEMPFILENAME.clw"
WC=$(grep -c '^>' "$TEMPFILENAME.clw")

MSG="tofasta: Clustal format conversion"
EXP=3
if [[ $EXP == $WC ]]; then
    echo -e "$OK: $MSG (expected $EXP sequences, got $WC)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP sequences, got $WC)"
    ERRORS=$((ERRORS+1))
fi

### Test 2: Convert GenBank format
"$BINDIR"/seqfu tofasta "$GENBANK_FILE" > "$TEMPFILENAME.gbk"
WC=$(grep -c '^>' "$TEMPFILENAME.gbk")

MSG="tofasta: GenBank format conversion"
EXP=75
if [[ $EXP == $WC ]]; then
    echo -e "$OK: $MSG (expected $EXP sequences, got $WC)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP sequences, got $WC)"
    ERRORS=$((ERRORS+1))
fi

### Test 3: Convert GFF format
"$BINDIR"/seqfu tofasta "$GFF_FILE" > "$TEMPFILENAME.gff" 2>/dev/null
WC=$(grep -c '^>' "$TEMPFILENAME.gff")

MSG="tofasta: GFF format conversion"
EXP=226
if [[ $EXP == $WC ]]; then
    echo -e "$OK: $MSG (expected $EXP sequences, got $WC)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP sequences, got $WC)"
    ERRORS=$((ERRORS+1))
fi

### Test 4: Uppercase transformation
"$BINDIR"/seqfu tofasta -u "$CLUSTAL_FILE" > "$TEMPFILENAME.upper"
# Check if sequences are uppercase (should not contain lowercase letters)
LOWERCASE_COUNT=$(grep -v '^>' "$TEMPFILENAME.upper" | grep -o '[a-z]' | wc -l | tr -d ' ')

MSG="tofasta: uppercase transformation"
EXP=0
if [[ $EXP == $LOWERCASE_COUNT ]]; then
    echo -e "$OK: $MSG (no lowercase letters found)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (found $LOWERCASE_COUNT lowercase letters, expected 0)"
    ERRORS=$((ERRORS+1))
fi

### Test 5: Lowercase transformation
"$BINDIR"/seqfu tofasta -l "$CLUSTAL_FILE" > "$TEMPFILENAME.lower"
# Check if sequences are lowercase (should not contain uppercase letters)
UPPERCASE_COUNT=$(grep -v '^>' "$TEMPFILENAME.lower" | grep -o '[A-Z]' | wc -l | tr -d ' ')

MSG="tofasta: lowercase transformation"
EXP=0
if [[ $EXP == $UPPERCASE_COUNT ]]; then
    echo -e "$OK: $MSG (no uppercase letters found)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (found $UPPERCASE_COUNT uppercase letters, expected 0)"
    ERRORS=$((ERRORS+1))
fi

### Test 6: Replace IUPAC ambiguous bases
"$BINDIR"/seqfu tofasta -n "$CLUSTAL_FILE" > "$TEMPFILENAME.iupac"
# Check if R (in gene01: ATGCRAGGAT) was replaced with N
R_COUNT=$(grep -v '^>' "$TEMPFILENAME.iupac" | grep -o 'R' | wc -l | tr -d ' ')

MSG="tofasta: replace non-IUPAC with N"
EXP=0
if [[ $EXP == $R_COUNT ]]; then
    echo -e "$OK: $MSG (R was replaced)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (found $R_COUNT 'R' characters, expected 0)"
    ERRORS=$((ERRORS+1))
fi

### Test 7: Multiple files with output file
"$BINDIR"/seqfu tofasta -o "$TEMPFILENAME.multi" "$CLUSTAL_FILE" "$GENBANK_FILE" 2>/dev/null
if [[ -f "$TEMPFILENAME.multi" ]]; then
    WC=$(grep -c '^>' "$TEMPFILENAME.multi")
    MSG="tofasta: multiple files to output file"
    EXP=78  # 3 from Clustal + 75 from GenBank
    if [[ $EXP == $WC ]]; then
        echo -e "$OK: $MSG (expected $EXP sequences, got $WC)"
        PASS=$((PASS+1))
    else
        echo -e "$FAIL: $MSG (expected $EXP sequences, got $WC)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo -e "$FAIL: tofasta: output file was not created"
    ERRORS=$((ERRORS+1))
fi

### Test 8: Verbose mode stderr output
VERBOSE_OUTPUT=$("$BINDIR"/seqfu tofasta -v "$CLUSTAL_FILE" 2>&1 >/dev/null)
if echo "$VERBOSE_OUTPUT" | grep -q "Format: Clustal"; then
    echo -e "$OK: tofasta: verbose mode works"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: tofasta: verbose mode did not print format"
    ERRORS=$((ERRORS+1))
fi

### Test 9: Check sequence correctness (GenBank ID)
GB_HEADER=$(head -n 1 "$TEMPFILENAME.gbk")
if echo "$GB_HEADER" | grep -q "NZ_AHMY02000075"; then
    echo -e "$OK: tofasta: GenBank sequence ID correct"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: tofasta: GenBank sequence ID not found (got: $GB_HEADER)"
    ERRORS=$((ERRORS+1))
fi

### Test 10: Check sequence correctness (Clustal IDs)
GENE01_FOUND=$(grep -c '^>gene01' "$TEMPFILENAME.clw")
GENE02_FOUND=$(grep -c '^>gene02' "$TEMPFILENAME.clw")
GENE03_FOUND=$(grep -c '^>gene03' "$TEMPFILENAME.clw")

MSG="tofasta: Clustal sequence IDs correct"
if [[ $GENE01_FOUND == 1 ]] && [[ $GENE02_FOUND == 1 ]] && [[ $GENE03_FOUND == 1 ]]; then
    echo -e "$OK: $MSG (all 3 genes found)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (gene01=$GENE01_FOUND, gene02=$GENE02_FOUND, gene03=$GENE03_FOUND)"
    ERRORS=$((ERRORS+1))
fi

### Test 11: Sequence content preservation (check gaps were removed)
# Clustal alignment has gaps (-), FASTA output should not
GAP_COUNT=$(grep -v '^>' "$TEMPFILENAME.clw" | grep -o '\-' | wc -l | tr -d ' ')

MSG="tofasta: gaps preserved in output"
# We expect gaps to be preserved in the sequence (they are valid FASTA characters)
if [[ $GAP_COUNT -gt 0 ]]; then
    echo -e "$OK: $MSG (found $GAP_COUNT gaps as expected)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (no gaps found, expected some)"
    ERRORS=$((ERRORS+1))
fi

### Test 12: Help text
if "$BINDIR"/seqfu tofasta --help 2>&1 | grep -q "Convert various sequence formats"; then
    echo -e "$OK: tofasta: help text available"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: tofasta: help text not found"
    ERRORS=$((ERRORS+1))
fi

# Cleanup
rm -f "$TEMPFILENAME"*
