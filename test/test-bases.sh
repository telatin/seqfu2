
#!/bin/bash

export SEQFU_QUIET=1
TEMPFILENAME=$(mktemp)
### SINGLE END
"$BINDIR"/seqfu bases "$FILES"/{base,base_extra,bases_lower}.fa > "$TEMPFILENAME"
"$BINDIR"/seqfu bases -c "$FILES"/{base,base_extra,bases_lower}.fa > "$TEMPFILENAME.raw"
"$BINDIR"/seqfu bases -u "$FILES"/upper-{lower,none,only}.fa > "$TEMPFILENAME.upper"
WC=$(getnumber $(cat "$TEMPFILENAME" | wc -l))


MSG="Counted files"
EXP=3
if [[ $EXP == $WC ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $WC)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $WC)"
    ERRORS=$((ERRORS+1))
fi 

# Check table
"$BINDIR"/fu-tabcheck "$TEMPFILENAME" > "$TEMPFILENAME.check"

IS_TABLE=$(cat "$TEMPFILENAME.check" | cut -f 2)
NUM_COLS=$(getnumber $(cat "$TEMPFILENAME.check" | cut -f 3))
MSG="Output is a table"
EXP="Pass"
if [[ $EXP == $IS_TABLE ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $IS_TABLE)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $IS_TABLE)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Output is a table with 9 columns"
EXP=9
if [[ $EXP == $NUM_COLS ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $NUM_COLS)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $NUM_COLS)"
    ERRORS=$((ERRORS+1))
fi 


### RAw checks
MSG="Raw counts of extra bases"
EXP=10
GOT=$(getnumber $(cat "$TEMPFILENAME.raw" | grep extra | cut -f 8 ))
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 


MSG="Raw counts of lowercase bases"
EXP=15
GOT=$(getnumber $(cat "$TEMPFILENAME.raw" | grep lower | cut -f 2 ))
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 
#///

MSG="Count ratio of As in bases_lower"
EXP="33.33"
GOT=$(cat "$TEMPFILENAME" | grep lower | cut -f 3 )
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Count ratio of As in base.fa"
EXP="50.00"
GOT=$(cat "$TEMPFILENAME" | grep base.fa | cut -f 3 )
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 


MSG="Count ratio of Gs in base.fa"
EXP="0.00"
GOT=$(cat "$TEMPFILENAME" | grep base.fa | cut -f 5 )
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 


MSG="Uppercase ratio: none"
EXP="0.00"
GOT=$(cat "$TEMPFILENAME.upper" | grep none | cut -f 10 )
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Uppercase ratio: all"
EXP="100.00"
GOT=$(cat "$TEMPFILENAME.upper" | grep only | cut -f 10 )
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 

MSG="Uppercase ratio: mixed"
EXP="50.00"
GOT=$(cat "$TEMPFILENAME.upper" | grep lower | cut -f 10 )
if [[ $EXP == $GOT ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $GOT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $GOT)"
    ERRORS=$((ERRORS+1))
fi 
rm "$TEMPFILENAME"*