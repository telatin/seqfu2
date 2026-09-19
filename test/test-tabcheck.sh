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

MSG="Explicit separator preserves diagnostics"
OBS=$("$BINDIR"/seqfu tabcheck -s tab "$WRONG")
if echo "$OBS" | grep -q "row=" && echo "$OBS" | grep -q "expected=" && echo "$OBS" | grep -q "observed="; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi

TMP_BAD_TSV="$(mktemp)"
printf "name\tvalue\nA\t1\nB\n" > "$TMP_BAD_TSV"
MSG="Auto separator keeps malformed TSV diagnostics"
OBS=$("$BINDIR"/seqfu tabcheck "$TMP_BAD_TSV")
if echo "$OBS" | grep -q "expected=2" && echo "$OBS" | grep -q "observed=1" && echo "$OBS" | grep -q "reason=inconsistent-column-count"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMP_BAD_TSV"

TMP_BAD_CSV="$(mktemp)"
printf "name,value\nA,1\nB\n" > "$TMP_BAD_CSV"
MSG="Auto separator keeps malformed CSV diagnostics"
OBS=$("$BINDIR"/seqfu tabcheck "$TMP_BAD_CSV")
if echo "$OBS" | grep -q "expected=2" && echo "$OBS" | grep -q "observed=1" && echo "$OBS" | grep -q "reason=inconsistent-column-count"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMP_BAD_CSV"

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

MSG="Inspect reports inferred column profiles"
OBS=$("$BINDIR"/fu-tabcheck --inspect --header "$TABLE")
if echo "$OBS" | grep -q $'^Column\tType\tDescription$' && \
   echo "$OBS" | grep -q $'^Name\tstring\ttotal=7; distinct=7;' && \
   echo "$OBS" | grep -q $'^Month\tstring\ttotal=7; distinct=2; top3=May: 5 (71.4%), Jan: 2 (28.6%)$'; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
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

TMP_TYPES="$(mktemp)"
printf "sample\tcount\tratio\tdate\nA\t1\t1.5\t2024-01-03\nB\t3\t2.5\t2024-01-01\nB\t5\t3.5\t2024-01-02\n" > "$TMP_TYPES"
MSG="Inspect infers numeric and date columns"
OBS=$("$BINDIR"/seqfu tabcheck --inspect "$TMP_TYPES")
if echo "$OBS" | grep -q $'^count\tint\tmin=1; max=5; average=3$' && \
   echo "$OBS" | grep -q $'^ratio\tfloat\tmin=1.5; max=3.5; average=2.5$' && \
   echo "$OBS" | grep -q $'^date\tdate\tmin=2024-01-01; max=2024-01-03$'; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMP_TYPES"

TMP_NO_HEADER="$(mktemp)"
printf "1\t2.5\n3\t4.5\n" > "$TMP_NO_HEADER"
MSG="Inspect numbers columns when no header is detected"
OBS=$("$BINDIR"/seqfu tabcheck --inspect "$TMP_NO_HEADER")
if echo "$OBS" | grep -q $'^1\tint\t' && echo "$OBS" | grep -q $'^2\tfloat\t'; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMP_NO_HEADER"

MSG="Inspect rejects multiple input tables"
if "$BINDIR"/seqfu tabcheck --inspect "$TABLE" "$COMPR" >/dev/null 2>&1; then
    echo -e "$FAIL: $MSG: command unexpectedly succeeded"
    ERRORS=$((ERRORS+1))
else
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
fi

MSG="Inspect reports validation diagnostics"
OBS=$("$BINDIR"/seqfu tabcheck --inspect "$WRONG" 2>&1)
if echo "$OBS" | grep -q "row=" && echo "$OBS" | grep -q "reason=inconsistent-column-count"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: got '$OBS'"
    ERRORS=$((ERRORS+1))
fi
