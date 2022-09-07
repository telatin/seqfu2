
#!/bin/bash

export SEQFU_QUIET=1
TEMPFILENAME=$(mktemp)
### SINGLE END
"$BINDIR"/seqfu check "$FILES"/illumina_nocomm.fq > "$TEMPFILENAME"
IS_OK=$(cat "$TEMPFILENAME" | grep -c "OK")
COUNT=$(cat "$TEMPFILENAME" |cut -f 4)
LIBRARY=$(cat "$TEMPFILENAME" |cut -f 2)
EXIT=$?


MSG="Checked single end exit status"
EXP=0
if [[ $EXIT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $EXIT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $EXIT)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked single end OK"
EXP=1
if [[ $IS_OK == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $IS_OK)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $IS_OK)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked single end libtype"
EXP="SE"
if [[ $LIBRARY == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $LIBRARY)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $LIBRARY)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked single end sequence count"
EXP=7
if [[ $COUNT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $COUNT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $COUNT)"
    ERRORS=$((ERRORS+1))
fi 


### PAIRED END
"$BINDIR"/seqfu check "$FILES"/illumina_1.fq.gz > "$TEMPFILENAME"
EXIT=$?
IS_OK=$(cat "$TEMPFILENAME" | grep -c "OK")
COUNT=$(cat "$TEMPFILENAME" |cut -f 4)
LIBRARY=$(cat "$TEMPFILENAME" |cut -f 2)

MSG="Checked paired end"
EXP=1
if [[ $IS_OK == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $IS_OK)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $IS_OK)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Checked paired end exit status"
EXP=0
if [[ $EXIT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $EXIT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $EXIT)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked paired end libtype"
EXP="PE"
if [[ $LIBRARY == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $LIBRARY)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $LIBRARY)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked single end sequence count (2xSE)"
EXP=14
if [[ $COUNT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $COUNT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $COUNT)"
    ERRORS=$((ERRORS+1))
fi 

## INVALID PE
"$BINDIR"/seqfu check "$FILES"/longerone_R1.fq.gz > "$TEMPFILENAME"
EXIT=$?
IS_OK=$(cat "$TEMPFILENAME" | grep -c "OK")
COUNT=$(cat "$TEMPFILENAME" |cut -f 4)
LIBRARY=$(cat "$TEMPFILENAME" |cut -f 2)

MSG="Checked INVALID paired end"
EXP=0
if [[ $IS_OK == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $IS_OK)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $IS_OK)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Checked INVALID paired end exit status"
EXP=0
if [[ $EXIT -gt $EXP ]]; then
    echo -e "$OK: $MSG (got $EXIT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (got $EXIT)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked INVALID paired end libtype"
EXP="PE"
if [[ $LIBRARY == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $LIBRARY)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $LIBRARY)"
    ERRORS=$((ERRORS+1))
fi 
 
MSG="Checked INVALID paired end sequence count (2xSE)"
EXP="-"
if [[ $COUNT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $COUNT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $COUNT)"
    ERRORS=$((ERRORS+1))
fi 

### CHECK INVALID DIR
LSDIR=$(ls -lh "$FILES"/primers)
$BINDIR/seqfu check --verbose --debug --dir "$FILES/primers" > "$TEMPFILENAME" 2> "$TEMPFILENAME.log"
EXIT=$?
WC=$(cat "$TEMPFILENAME" | wc -l)
WC_ERR=$(cat "$TEMPFILENAME" | grep -v OK | grep ERR | wc -l)

echo "--"
cat "$TEMPFILENAME.log"
echo "--"
MSG="Checked INVALID directory ($FILES/primers) exit status"
if [[ $EXIT -gt 0 ]]; then
    echo -e "$OK: $MSG (expected > 0, got $EXIT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected > 0, got $EXIT)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Checked INVALID directory line count"
EXP=12
if [[ $WC == $EXP ]]; then
    echo -e "$OK: $MSG (got $WC expected $EXP)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (got $WC expected $EXP)\n$(cat "$TEMPFILENAME")\n$LSDIR"
    ERRORS=$((ERRORS+1))
fi 


MSG="Checked INVALID directory line error count"
EXP=2
if [[ $WC_ERR == $EXP ]]; then
    echo -e "$OK: $MSG (got $WC_ERR expected $EXP)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (got $WC_ERR expected $EXP)\n$(cat "$TEMPFILENAME")\n$LSDIR"
    ERRORS=$((ERRORS+1))
fi 



### CHECK VALID DIR
$BINDIR/seqfu check  --verbose --debug --dir "$FILES/reads" > "$TEMPFILENAME" 2> "$TEMPFILENAME.log"
EXIT=$?
WC=$(cat "$TEMPFILENAME" | wc -l)
WC_ERR=$(cat "$TEMPFILENAME" | grep -v OK | grep ERR | wc -l)

echo "--"
cat "$TEMPFILENAME.log"
echo "--"

MSG="Checked valid directory exit status"
if [[ $EXIT -eq 0 ]]; then
    echo -e "$OK: $MSG (expected 0, got $EXIT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected 0, got $EXIT)\n$CHECKDIR\n$LSDIR"
    ERRORS=$((ERRORS+1))
fi 

MSG="Checked valid directory line count"
EXP=5
if [[ $WC == $EXP ]]; then
    echo -e "$OK: $MSG (got $WC expected $EXP)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (got $WC expected $EXP)"
    ERRORS=$((ERRORS+1))
fi 


MSG="Checked valid directory line error count"
EXP=0
if [[ $WC_ERR == $EXP ]]; then
    echo -e "$OK: $MSG (got $WC_ERR expected $EXP)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (got $WC_ERR expected $EXP)"
    ERRORS=$((ERRORS+1))
fi 


rm "$TEMPFILENAME"