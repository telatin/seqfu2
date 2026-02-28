#!/bin/bash

# Single file
TABLE="$FILES"/table-demo.tsv
COMPR="$FILES"/tablegz.tsv.gz
WRONG="$FILES"/table2.tsv
CSV="$FILES"/table.csv

for F in "$TABLE" "$COMPR" "$WRONG" "$CSV"; do
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

MSG="Wrong table reports diagnostics"
OBS=$("$BINDIR"/seqfu tabcheck "$WRONG")
if echo "$OBS" | grep -q "row=" && echo "$OBS" | grep -q "expected=" && echo "$OBS" | grep -q "observed="; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi

EXP=1
MSG="Auto separator detects CSV"
OBS=$("$BINDIR"/seqfu tabcheck "$CSV" | grep Pass | wc -l | grep -o '[[:digit:]]\+')
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

EXP=1
MSG="Check valid table (seqfu tabcheck)"
OBS=$("$BINDIR"/seqfu tabcheck "$TABLE" | grep Pass | wc -l | grep -o '[[:digit:]]\+')
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP=0
MSG="Check wrong table (seqfu tabcheck)"
OBS=$("$BINDIR"/seqfu tabcheck "$WRONG" | grep Pass | wc -l | grep -o '[[:digit:]]\+')
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

TMP_COMMENT="$(mktemp)"
printf "# comment line with wrong\tcolumn\tcount\nname\tvalue\nA\t1\n# trailing comment\ttoo\tmany\tcols\nB\t2\n" > "$TMP_COMMENT"
EXP=1
MSG="Check default comment handling"
OBS=$("$BINDIR"/seqfu tabcheck "$TMP_COMMENT" | grep Pass | wc -l | grep -o '[[:digit:]]\+')
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMP_COMMENT"

EXP=1
MSG="Inspect header printed once"
OBS=$("$BINDIR"/seqfu tabcheck --inspect --header "$TABLE" "$COMPR" | grep -c "^File[[:space:]]\+ColID[[:space:]]\+ColName")
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi

EXP="table-demo.tsv"
MSG="Inspect output preserves input order"
OBS=$("$BINDIR"/seqfu tabcheck --inspect "$TABLE" "$COMPR" | head -n 1 | cut -f 1)
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    ERRORS=$((ERRORS+1))
fi
