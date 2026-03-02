#!/bin/bash

R1="$FILES"/illumina_1.fq.gz
R2="$FILES"/illumina_2.fq.gz

check_ok() {
    local msg="$1"
    echo -e "$OK: $msg"
    PASS=$((PASS + 1))
}

check_fail() {
    local msg="$1"
    echo -e "$FAIL: $msg"
    ERRORS=$((ERRORS + 1))
}

for F in "$R1" "$R2"; do
    if [[ -e "$F" ]]; then
        check_ok "Files exist: $F"
    else
        check_fail "Files do not exist: $F"
    fi
done

#
# Empty/single-end edge case
#
TMP_EMPTY=$(mktemp)
: > "$TMP_EMPTY"
EMPTY_TYPE=$("$BINDIR"/seqfu count "$TMP_EMPTY" | cut -f 3)
EMPTY_COUNT=$("$BINDIR"/seqfu count "$TMP_EMPTY" | cut -f 2)
rm -f "$TMP_EMPTY"
if [[ "$EMPTY_TYPE" == "SE" ]] && [[ "$EMPTY_COUNT" == "0" ]]; then
    check_ok "Empty single-end file is reported as SE with 0 reads"
else
    check_fail "Empty single-end file classification [type=$EMPTY_TYPE count=$EMPTY_COUNT]"
fi

#
# Thread option validation and semantics
#
TMP_T0_OUT=$(mktemp)
TMP_T0_ERR=$(mktemp)
"$BINDIR"/seqfu count --threads 0 "$R1" >"$TMP_T0_OUT" 2>"$TMP_T0_ERR"
T0_CODE=$?
T0_MSG=$(cat "$TMP_T0_ERR")
rm -f "$TMP_T0_OUT" "$TMP_T0_ERR"
if [[ $T0_CODE -ne 0 ]] && echo "$T0_MSG" | grep -q -- "--threads must be >= 1"; then
    check_ok "Invalid --threads value is rejected"
else
    check_fail "Invalid --threads handling [exit=$T0_CODE msg=$T0_MSG]"
fi

TMP_TBAD_OUT=$(mktemp)
TMP_TBAD_ERR=$(mktemp)
"$BINDIR"/seqfu count --threads banana "$R1" >"$TMP_TBAD_OUT" 2>"$TMP_TBAD_ERR"
TBAD_CODE=$?
TBAD_MSG=$(cat "$TMP_TBAD_ERR")
rm -f "$TMP_TBAD_OUT" "$TMP_TBAD_ERR"
if [[ $TBAD_CODE -ne 0 ]] && echo "$TBAD_MSG" | grep -q -- "--threads must be an integer"; then
    check_ok "Non-integer --threads value is rejected"
else
    check_fail "Non-integer --threads handling [exit=$TBAD_CODE msg=$TBAD_MSG]"
fi

COUNT_T1=$("$BINDIR"/seqfu count --threads 1 "$R1" "$R2" | sort)
COUNT_T2=$("$BINDIR"/seqfu count --threads 2 "$R1" "$R2" | sort)
if [[ "$COUNT_T1" == "$COUNT_T2" ]]; then
    check_ok "Parallel count matches single-thread output"
else
    check_fail "Parallel count output differs from single-thread"
fi

STDIN_COUNT=$(printf ">x\nACTG\n" | "$BINDIR"/seqfu count --threads 4 - 2>/dev/null | cut -f 2)
if [[ "$STDIN_COUNT" == "1" ]]; then
    check_ok "STDIN input works with --threads > 1 (sequential fallback)"
else
    check_fail "STDIN with threads fallback failed [count=$STDIN_COUNT]"
fi

#
# Sort mode validation
#
TMP_SORT_DIR=$(mktemp -d)
cp "$R1" "$TMP_SORT_DIR"/zeta.fq.gz
cp "$R1" "$TMP_SORT_DIR"/alpha.fq.gz

SORT_DEFAULT=$("$BINDIR"/seqfu count "$TMP_SORT_DIR"/zeta.fq.gz "$TMP_SORT_DIR"/alpha.fq.gz | cut -f 1 | paste -sd, -)
SORT_INPUT=$("$BINDIR"/seqfu count --sort input "$TMP_SORT_DIR"/zeta.fq.gz "$TMP_SORT_DIR"/alpha.fq.gz | cut -f 1 | paste -sd, -)
SORT_NAME=$("$BINDIR"/seqfu count --sort name "$TMP_SORT_DIR"/zeta.fq.gz "$TMP_SORT_DIR"/alpha.fq.gz | cut -f 1 | paste -sd, -)
if [[ "$SORT_DEFAULT" == "$SORT_INPUT" ]] && [[ "$SORT_NAME" == "$TMP_SORT_DIR/alpha.fq.gz,$TMP_SORT_DIR/zeta.fq.gz" ]]; then
    check_ok "Sort mode default/input/name works as expected"
else
    check_fail "Sort mode default/input/name [default=$SORT_DEFAULT input=$SORT_INPUT name=$SORT_NAME]"
fi

: > "$TMP_SORT_DIR"/empty.fq.gz
cp "$R1" "$TMP_SORT_DIR"/full.fq.gz
SORT_COUNTS=$("$BINDIR"/seqfu count --sort counts "$TMP_SORT_DIR"/empty.fq.gz "$TMP_SORT_DIR"/full.fq.gz | cut -f 1 | paste -sd, -)
SORT_COUNTS_REV=$("$BINDIR"/seqfu count --sort counts --reverse-sort "$TMP_SORT_DIR"/empty.fq.gz "$TMP_SORT_DIR"/full.fq.gz | cut -f 1 | paste -sd, -)
if [[ "$SORT_COUNTS" == "$TMP_SORT_DIR/full.fq.gz,$TMP_SORT_DIR/empty.fq.gz" ]] && [[ "$SORT_COUNTS_REV" == "$TMP_SORT_DIR/empty.fq.gz,$TMP_SORT_DIR/full.fq.gz" ]]; then
    check_ok "Sort mode counts and --reverse-sort work as expected"
else
    check_fail "Sort mode counts [counts=$SORT_COUNTS reverse=$SORT_COUNTS_REV]"
fi

SORT_NONE=$("$BINDIR"/seqfu count --threads 2 --sort none "$TMP_SORT_DIR"/zeta.fq.gz "$TMP_SORT_DIR"/alpha.fq.gz | cut -f 1 | sort | paste -sd, -)
if [[ "$SORT_NONE" == "$TMP_SORT_DIR/alpha.fq.gz,$TMP_SORT_DIR/zeta.fq.gz" ]]; then
    check_ok "Sort mode none returns all expected rows"
else
    check_fail "Sort mode none failed [rows=$SORT_NONE]"
fi

TMP_SORT_BAD_OUT=$(mktemp)
TMP_SORT_BAD_ERR=$(mktemp)
"$BINDIR"/seqfu count --sort invalid "$TMP_SORT_DIR"/zeta.fq.gz >"$TMP_SORT_BAD_OUT" 2>"$TMP_SORT_BAD_ERR"
SORT_BAD_CODE=$?
SORT_BAD_MSG=$(cat "$TMP_SORT_BAD_ERR")
rm -f "$TMP_SORT_BAD_OUT" "$TMP_SORT_BAD_ERR"
if [[ $SORT_BAD_CODE -ne 0 ]] && echo "$SORT_BAD_MSG" | grep -q -- "--sort must be one of"; then
    check_ok "Invalid --sort mode is rejected"
else
    check_fail "Invalid --sort handling [exit=$SORT_BAD_CODE msg=$SORT_BAD_MSG]"
fi
rm -rf "$TMP_SORT_DIR"

#
# Custom strand tags / pair classification
#
TMP_PAIR_DIR=$(mktemp -d)
cp "$R1" "$TMP_PAIR_DIR"/sample.fwd.fq.gz
cp "$R2" "$TMP_PAIR_DIR"/sample.rev.fq.gz

UNPAIR_TYPES=$("$BINDIR"/seqfu count -u --for-tag .fwd --rev-tag .rev "$TMP_PAIR_DIR"/sample.fwd.fq.gz "$TMP_PAIR_DIR"/sample.rev.fq.gz | cut -f 3 | sort | paste -sd, -)
if [[ "$UNPAIR_TYPES" == "Paired,Paired:R2" ]]; then
    check_ok "Custom tags are respected in --unpair output"
else
    check_fail "Custom tag unpair classification [types=$UNPAIR_TYPES]"
fi

PAIRED_TAGS=$("$BINDIR"/seqfu count --for-tag .fwd --rev-tag .rev "$TMP_PAIR_DIR"/sample.fwd.fq.gz "$TMP_PAIR_DIR"/sample.rev.fq.gz | cut -f 3)
if [[ "$PAIRED_TAGS" == "Paired" ]]; then
    check_ok "Custom tags are respected in paired aggregation mode"
else
    check_fail "Custom tag paired classification [type=$PAIRED_TAGS]"
fi
rm -rf "$TMP_PAIR_DIR"

#
# Reverse-only error path
#
TMP_OUT=$(mktemp)
TMP_ERR=$(mktemp)
"$BINDIR"/seqfu count "$R2" >"$TMP_OUT" 2>"$TMP_ERR"
REV_ONLY_CODE=$?
REV_ONLY_MSG=$(cat "$TMP_ERR")
REV_ONLY_OUT=$(cat "$TMP_OUT")
rm -f "$TMP_OUT" "$TMP_ERR"
if [[ $REV_ONLY_CODE -ne 0 ]] && echo "$REV_ONLY_MSG" | grep -q "Reverse file without matching forward file"; then
    check_ok "Reverse-only input raises explicit error"
else
    check_fail "Reverse-only input error handling [exit=$REV_ONLY_CODE msg=$REV_ONLY_MSG out=$REV_ONLY_OUT]"
fi

#
# Read-failure handling: never report failed R1/R2 as Paired
#
TMP_FAIL_DIR=$(mktemp -d)
FAIL_R1="$TMP_FAIL_DIR"/broken_1.fq.gz
FAIL_R2="$TMP_FAIL_DIR"/broken_2.fq.gz
printf "@r1\nACGT\n+\n!!!!\n" > "$FAIL_R1"
printf "@r2\nTGCA\n+\n!!!!\n" > "$FAIL_R2"
chmod 000 "$FAIL_R1" "$FAIL_R2"

TMP_FAIL_OUT=$(mktemp)
TMP_FAIL_ERR=$(mktemp)
"$BINDIR"/seqfu count "$FAIL_R1" "$FAIL_R2" >"$TMP_FAIL_OUT" 2>"$TMP_FAIL_ERR"
FAIL_CODE=$?
FAIL_OUT=$(cat "$TMP_FAIL_OUT")
FAIL_ERR=$(cat "$TMP_FAIL_ERR")
rm -f "$TMP_FAIL_OUT" "$TMP_FAIL_ERR"
chmod 600 "$FAIL_R1" "$FAIL_R2"
rm -rf "$TMP_FAIL_DIR"

if [[ $FAIL_CODE -ne 0 ]] && ! echo "$FAIL_OUT" | grep -q $'\tPaired$' && echo "$FAIL_ERR" | grep -q "Unable to count reads in"; then
    check_ok "Read failures are reported as errors (never Paired)"
else
    check_fail "Read failure handling [exit=$FAIL_CODE out=$FAIL_OUT err=$FAIL_ERR]"
fi
