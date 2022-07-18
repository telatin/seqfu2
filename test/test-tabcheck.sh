#!/bin/bash

# Single file
TABLE="$FILES"/table-demo.tsv
COMPR="$FILES"/tablegz.tsv.gz
WRONG="$FILES"/table2.tsv

for F in "$TABLE" "$COMPR" "$WRONG"; do
    if [[ -e "$F" ]]; then
        echo -e "$OK: Files exist: $F"
        PASS=$((PASS+1))
    else
        echo -e "$FAIL: Files do not exist: $F"
        ERRORS=$((ERRORS+1))
    fi
done


# -----------------------------------------------------------------------------
 
EXP=1
MSG="Check valid table"
OBS=$("$BINDIR"/fu-tabcheck "$TABLE" | grep Pass | wc -l | grep -o '[[:digit:]]\+')
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP=0
MSG="Check wrong table"
OBS=$("$BINDIR"/fu-tabcheck "$WRONG" | grep Pass | wc -l | grep -o '[[:digit:]]\+')
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP=0
MSG="Check details"
OBS=$("$BINDIR"/fu-tabcheck "$TABLE" -i | grep Pass | wc -l | grep -o '[[:digit:]]\+')
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi