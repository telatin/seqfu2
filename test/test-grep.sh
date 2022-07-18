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
 