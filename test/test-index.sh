#!/bin/bash

# Single file
TMP=$(mktemp)
echo "    Temp file: $TMP"
"$BINDIR"/fu-index "$iPair1" "$iPair2" > "$TMP"


MSG="Checking output expecting 2 lines:"
EXP=2
OBS=$(cat "$TMP" | wc -l | grep -o "[[:digit:]]\+" | head -n 1)
if [[ $OBS -eq $EXP ]]; then
    echo -e "$OK: $MSG: exp=$EXP obs=$OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP obs=$OBS"
    cat "$TMP"
    echo ---
    #cat "$TMP" | wc -l | '[[:digit:]]\+'
    ERRORS=$((ERRORS+1))
fi
 

MSG="Got expected index:"
EXP="TACGCTGC+CTATTAAG"
OBS=$(cat "$TMP" | cut -f 2 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $EXP / $OBS"
    ERRORS=$((ERRORS+1))
fi
 
MSG="Got expected index ratio:"
EXP="1.00"
OBS=$(cat "$TMP" | cut -f 3 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $EXP / $OBS: $(cat "$TMP")"
    ERRORS=$((ERRORS+1))
fi

MSG="Got expected pass:"
EXP="PASS"
OBS=$(cat "$TMP" | cut -f 4 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $EXP / $OBS: $(cat "$TMP")"
    ERRORS=$((ERRORS+1))
fi


MSG="Got expected instrument:"
EXP="A00709"
OBS=$(cat "$TMP" | cut -f 5 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $EXP / $OBS: $(cat "$TMP")"
    ERRORS=$((ERRORS+1))
fi

MSG="Got expected flowcell:"
EXP="HYG25DSXX"
OBS=$(cat "$TMP" | cut -f 7 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $EXP / $OBS: $(cat "$TMP")"
    ERRORS=$((ERRORS+1))
fi

# ---

"$BINDIR"/fu-index "$iAmpli" > "$TMP"

MSG="Checking output expecting 1 line:"
EXP=1
OBS=$(wc -l "$TMP" | grep -o '[[:digit:]]\+'  | head -n 1)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: exp=$EXP / got=$OBS"
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

"$BINDIR"/fu-index --min-ratio 0.50 "$FILES"/mixed_index.fq.gz > "$TMP"
MSG="Minimum ratio accepts exact threshold:"
EXP="PASS"
OBS=$(cat "$TMP" | cut -f 4 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/fu-index --min-ratio 0.51 "$FILES"/mixed_index.fq.gz > "$TMP"
MSG="Minimum ratio rejects values below threshold:"
EXP="--"
OBS=$(cat "$TMP" | cut -f 4 | sort | uniq)
if [[ "$OBS" == "$EXP" ]]; then
    echo -e "$OK: $MSG: $EXP / $OBS"
    PASS=$((PASS+1))
else
    echo -e ""$FAIL: $MSG: $EXP / $OBS: $(cat $TMP)""
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/fu-index "$FILES"/missing-index-test.fq.gz > "$TMP" 2> "$TMP.err"
RET=$?
MSG="Missing input returns non-zero:"
if [[ $RET -ne 0 ]] && grep -q "not found" "$TMP.err"; then
    echo -e "$OK: $MSG exit=$RET"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG exit=$RET stderr=$(cat "$TMP.err")"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/fu-index --max-reads=-1 "$iPair1" > "$TMP" 2> "$TMP.err"
RET=$?
MSG="Invalid --max-reads returns non-zero:"
if [[ $RET -ne 0 ]] && grep -q "max-reads" "$TMP.err"; then
    echo -e "$OK: $MSG exit=$RET"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG exit=$RET stderr=$(cat "$TMP.err")"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/fu-index --min-ratio=1.1 "$iPair1" > "$TMP" 2> "$TMP.err"
RET=$?
MSG="Invalid --min-ratio returns non-zero:"
if [[ $RET -ne 0 ]] && grep -q "min-ratio" "$TMP.err"; then
    echo -e "$OK: $MSG exit=$RET"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG exit=$RET stderr=$(cat "$TMP.err")"
    ERRORS=$((ERRORS+1))
fi

PARSER_CACHE=$(mktemp -d)
PARSER_BIN="$PARSER_CACHE/test_fu_index_parser"
nim c -r --nimcache:"$PARSER_CACHE" --out:"$PARSER_BIN" test/test_fu_index_parser.nim > "$TMP.parser.out" 2> "$TMP.parser.err"
RET=$?
MSG="CASAVA comment parser unit test:"
if [[ $RET -eq 0 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG exit=$RET"
    cat "$TMP.parser.out"
    cat "$TMP.parser.err"
    ERRORS=$((ERRORS+1))
fi
