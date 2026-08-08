#!/bin/bash

# Single file
TMP=$(mktemp)
echo "    Temp file: $TMP"


## Get SEQ3
EXP=1
MSG="Extracting one exact match (SEQ3)"
OBS=$("$BINDIR"/seqfu grep -n SEQ3 "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Get SEQ3 (-v)
EXP=4
MSG="Extracting one exact match (SEQ3), invert (-v)"
OBS=$("$BINDIR"/seqfu grep -v -n SEQ3 "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi
## Get SEQ
EXP=5
MSG="Get all SEQ matches"
OBS=$("$BINDIR"/seqfu grep -n SEQ "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Get seq *none*
EXP=0
MSG="Extracting all 'seq' matches"
OBS=$("$BINDIR"/seqfu grep -n seq "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Get seq *none*
EXP=5
MSG="Extracting all 'seq' matches, but case insensitive"
OBS=$("$BINDIR"/seqfu grep -i -n seq "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Get seq with regex
EXP=10
MSG="Regex '1.3' matches (-r)"
OBS=$("$BINDIR"/seqfu grep -r 1.3 "$iNum" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Get seq full
EXP=1
MSG="Full '13' matches (-f)"
OBS=$("$BINDIR"/seqfu grep -n 13 -f "$iNum" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi


## Search patter
EXP=0
MSG="Search 'two' (is only in comments)"
OBS=$("$BINDIR"/seqfu grep -n two "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Search in comments
EXP=3
MSG="Search 'two' (INCLUDING comments)"
OBS=$("$BINDIR"/seqfu grep -c -n two "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Search oligo
EXP=1
MSG="Search oligo"
OBS=$("$BINDIR"/seqfu grep -o ACGTACGTACGTAGCTGATCGATCGTACGTAGCTGACA "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi



EXP=1
MSG="Search oligo, revcompl and lowercase"
OBS=$("$BINDIR"/seqfu grep -o tgtcagctacgtacgatcgatcagctacgtacgtacgt "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP=1
MSG="Search oligo (lower case in UC seq)"
OBS=$("$BINDIR"/seqfu grep -o acgtacgtacgtagctgatcgatcgtacgtagctgaca "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP=1
MSG="Search oligo (partial with 'N' inside)"
OBS=$("$BINDIR"/seqfu grep -o tacgtacgtagctgatcNatcgtacgtagctgaca "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP=1
MSG="Search oligo (partial with 'IUPAC' inside)"
OBS=$("$BINDIR"/seqfu grep -o acgtacgtacgtaSStgatcgatcgtacgtagctgaca "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Test -w (word boundary) with numeric names
EXP=1
MSG="Word match: search '1' with -w (should match only seq 1, not 10, 11, etc.)"
OBS=$("$BINDIR"/seqfu grep -n 1 -w "$iNum" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Test substring match (default) with numeric names
EXP=272
MSG="Substring match: search '1' without -w (should match 1, 10-19, 100-199, 210-219, etc.)"
OBS=$("$BINDIR"/seqfu grep -n 1 "$iNum" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Test -w with word in comment
EXP=1
MSG="Word match in comment: search 'has' with -w -c (should match SEQ1 only)"
OBS=$("$BINDIR"/seqfu grep -n has -w -c "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Test -w does not match partial words in comments
EXP=1
MSG="Word match in comment: search 'tabbed' with -w -c (should match SEQ2 'tabbed_comment')"
OBS=$("$BINDIR"/seqfu grep -n tabbed -w -c "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

## Test substring match in comments (for comparison)
EXP=1
MSG="Substring match in comment: search 'tabbed' with -c (should match SEQ2 only)"
OBS=$("$BINDIR"/seqfu grep -n tabbed -c "$iComments" | "$BINDIR"/seqfu count | cut -f 2 )
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi
 