#!/bin/bash

# Single file
TMP=$(mktemp)
"$BINDIR"/fu-index "$iPair1" "$iPair2" > "$TMP"


MSG="Checking output expecting 2 lines:"
EXP=2
OBS=$(cat "$TMP" | wc -l)
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    cat "$TMP"
    echo ---
    cat "$TMP" | wc -l | '[[:digit:]]\+'
    ERRORS=$((ERRORS+1))
fi
 

MSG="Got expected index:"
EXP="TACGCTGC+CTATTAAG"
OBS=$(cat "$TMP" | cut -f 2 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi
 
MSG="Got expected index ratio:"
EXP="1.00"
OBS=$(cat "$TMP" | cut -f 3 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

MSG="Got expected pass:"
EXP="PASS"
OBS=$(cat "$TMP" | cut -f 4 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi


MSG="Got expected instrument:"
EXP="A00709"
OBS=$(cat "$TMP" | cut -f 5 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

MSG="Got expected flowcell:"
EXP="HYG25DSXX"
OBS=$(cat "$TMP" | cut -f 7 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

# ---

"$BINDIR"/fu-index "$iAmpli" > "$TMP"

MSG="Checking output expecting 1 line:"
EXP=1
OBS=$(cat "$TMP" | wc -l)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

MSG="Checking failed sample (no index):"
EXP=""
OBS=$(cat "$TMP" | cut -f 2 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

MSG="Checking failed sample (status):"
EXP="--"
OBS=$(cat "$TMP" | cut -f 4 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi


# ---

"$BINDIR"/fu-index "$FILES"/mixed_index.fq.gz > "$TMP"
MSG="Checking failed sample (ratio):"
EXP="0.50"
OBS=$(cat "$TMP" | cut -f 3 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi
