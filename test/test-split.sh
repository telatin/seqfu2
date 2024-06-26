#!/bin/bash

PY=$(command -v python)
PYERR=$?
if [[ -e "$BINDIR"/fu-split ]] && [[ $PYERR == 0 ]]; then

python --version
export SEQFU_BIN="$BINDIR"/seqfu
# Single file
OUTDIR=$(mktemp -d)
echo " * Outdir: $OUTDIR"


if [[ ! -d "$OUTDIR" ]]; then
    echo "Error: output directory not created"
    exit 1
fi

touch "$OUTDIR"/test.txt
EXP=7

"$BINDIR"/fu-split -i "$i16S" -n $EXP  -o "$OUTDIR"/splitParts-00000.fa.gz
# --------------------------------------------------------------------------------
OBS=$(ls "$OUTDIR"/splitParts-*.fa.gz | wc -l | grep -o '[[:digit:]]\+')
MSG="Split in $EXP files: got $OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ls -lh "$OUTDIR"/splitParts-*.fa.gz
    ERRORS=$((ERRORS+1))
fi

EXP=$(count "$i16S")
OBS=$("$BINDIR"/seqfu cat "$OUTDIR"/splitParts-*.fa.gz | "$BINDIR"/seqfu count | cut -f 2)
MSG="Total sequences from splitParts-*.fa.gz equal source: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi


# Check total bases
BASES=500000
"$BINDIR"/fu-split -i "$i16S" -b $BASES  -o "$OUTDIR"/splitBases-00000.fa.gz
# --------------------------------------------------------------------------------
EXP=$(bp "$i16S")
OBS=$(bp "$OUTDIR"/splitBases-*.fa.gz)
MSG="Split by $BASES bases: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

EXP=4
OBS=$(ls "$OUTDIR"/splitBases-*.fa.gz | wc -l | grep -o '[[:digit:]]\+')
MSG="Split by bases: expecting $EXP files: got $OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    "$BINDIR"/seqfu stats -b -n "$OUTDIR"/splitBases-*.fa.gz
    ERRORS=$((ERRORS+1))
fi

# Each file should contain less than $BP bases
for FILE in "$OUTDIR"/splitBases*;
do
    F=$(basename "$FILE")
    BP=$(bp "$FILE")
    if [[ ! $BP -gt $BASES ]]; then
        echo -e "$OK: $F contains $BP bp: no more than $BASES"
        PASS=$((PASS+1))
    else
        echo -e "$FAIL: $F contains $BP bp: more than $BASES"
        ERRORS=$((ERRORS+1))
    fi
done
# ==============================================================================
# Check total seqs
SEQS=1000
"$BINDIR"/fu-split -i "$i16S" -s $SEQS  -o "$OUTDIR"/splitSeqs-00000.fa.gz
# --------------------------------------------------------------------------------
EXP=$(bp "$i16S")
OBS=$(bp "$OUTDIR"/splitSeqs-*.fa.gz)
MSG="Split by $SEQS seqs: exp=$EXP got=$OBS "
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Each file should contain less than $SEQS sequences
for FILE in "$OUTDIR"/splitSeqs*;
do
    COUNT=$(count "$FILE")
    F=$(basename "$FILE")
    if [[ ! $COUNT -gt $SEQS ]]; then
        echo -e "$OK: $F contains $COUNT sequences: no more than $SEQS"
        PASS=$((PASS+1))
    else
        echo -e "$FAIL: $F contains $COUNT sequences: more than $SEQS"
        ERRORS=$((ERRORS+1))
    fi
done

if [[ $ERRORS == 0 ]]; then
 rm -rf "$OUTDIR"
fi

else
    echo -e "SKIP: python not found ($PY) or fu-split not in $BINDIR"
fi
