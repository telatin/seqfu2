#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SEQFU_BIN="${BIN:-${BINDIR:-$DIR/../bin}/seqfu}"
FILES="${FILES:-$DIR/../data}"

OK="${OK:-\\033[0;32mOK\\033[0m}"
FAIL="${FAIL:-\\033[0;31mFAIL\\033[0m}"
if [[ -z ${PASS+x} ]]; then PASS=0; fi
if [[ -z ${ERRORS+x} ]]; then ERRORS=0; fi

INTERLEAVE_TMP=$(mktemp -d)

interleave_ok() {
  echo -e "$OK: $1"
  PASS=$((PASS+1))
}

interleave_fail() {
  echo -e "$FAIL: $1"
  ERRORS=$((ERRORS+1))
}

interleave_eq() {
  local msg="$1"
  local got="$2"
  local exp="$3"
  if [[ "$got" == "$exp" ]]; then
    interleave_ok "$msg"
  else
    interleave_fail "$msg: expected <$exp>, got <$got>"
  fi
}

R1_GZ="$FILES/illumina_1.fq.gz"
R2_GZ="$FILES/illumina_2.fq.gz"

gzip -dc "$R1_GZ" > "$INTERLEAVE_TMP/R1.fq"
gzip -dc "$R2_GZ" > "$INTERLEAVE_TMP/R2.fq"

"$SEQFU_BIN" interleave -1 "$R1_GZ" -2 "$R2_GZ" > "$INTERLEAVE_TMP/interleaved.fq" 2>"$INTERLEAVE_TMP/interleaved.err"
INTERLEAVE_CODE=$?
if [[ $INTERLEAVE_CODE -eq 0 ]]; then
  interleave_ok "Interleave exits successfully for existing R1/R2 gzip files"
else
  interleave_fail "Interleave failed for existing R1/R2 gzip files [exit=$INTERLEAVE_CODE err=$(cat "$INTERLEAVE_TMP/interleaved.err")]"
fi

awk -v r1="$INTERLEAVE_TMP/split_R1.fq" -v r2="$INTERLEAVE_TMP/split_R2.fq" '
  {
    rec = int((NR - 1) / 4)
    if (rec % 2 == 0) print > r1
    else print > r2
  }
' "$INTERLEAVE_TMP/interleaved.fq"

if diff -q "$INTERLEAVE_TMP/R1.fq" "$INTERLEAVE_TMP/split_R1.fq" >/dev/null 2>&1; then
  interleave_ok "Interleave preserves R1 records exactly"
else
  interleave_fail "Interleave changed R1 records"
fi

if diff -q "$INTERLEAVE_TMP/R2.fq" "$INTERLEAVE_TMP/split_R2.fq" >/dev/null 2>&1; then
  interleave_ok "Interleave preserves R2 records exactly"
else
  interleave_fail "Interleave changed R2 records"
fi

ILV_COUNT=$("$SEQFU_BIN" count "$INTERLEAVE_TMP/interleaved.fq" 2>/dev/null | cut -f 2)
EXP_COUNT=$(( $(wc -l < "$INTERLEAVE_TMP/R1.fq") / 4 + $(wc -l < "$INTERLEAVE_TMP/R2.fq") / 4 ))
interleave_eq "Interleaved output has expected read count" "$ILV_COUNT" "$EXP_COUNT"

cp "$INTERLEAVE_TMP/R1.fq" "$INTERLEAVE_TMP/sample_R1.fq"
cp "$INTERLEAVE_TMP/R2.fq" "$INTERLEAVE_TMP/sample_R2.fq"
AUTO_COUNT=$("$SEQFU_BIN" interleave -1 "$INTERLEAVE_TMP/sample_R1.fq" 2>/dev/null | "$SEQFU_BIN" count - 2>/dev/null | cut -f 2)
interleave_eq "Interleave autodetects _R1. / _R2. filenames" "$AUTO_COUNT" "$EXP_COUNT"

cat > "$INTERLEAVE_TMP/name_R1.fq" <<'EOF'
@same/1
ACGT
+
!!!!
EOF
cat > "$INTERLEAVE_TMP/name_R2.fq" <<'EOF'
@other/2
TGCA
+
####
EOF

"$SEQFU_BIN" interleave --check -1 "$INTERLEAVE_TMP/name_R1.fq" -2 "$INTERLEAVE_TMP/name_R2.fq" > "$INTERLEAVE_TMP/name.out" 2>"$INTERLEAVE_TMP/name.err"
NAME_CODE=$?
if [[ $NAME_CODE -ne 0 ]] && grep -qi 'mismatch\|Sequence error' "$INTERLEAVE_TMP/name.out" "$INTERLEAVE_TMP/name.err"; then
  interleave_ok "Interleave --check rejects mismatched mate names"
else
  interleave_fail "Interleave --check name mismatch handling [exit=$NAME_CODE out=$(cat "$INTERLEAVE_TMP/name.out") err=$(cat "$INTERLEAVE_TMP/name.err")]"
fi

head -n 4 "$INTERLEAVE_TMP/R2.fq" > "$INTERLEAVE_TMP/short_R2.fq"
"$SEQFU_BIN" interleave --check -1 "$INTERLEAVE_TMP/R1.fq" -2 "$INTERLEAVE_TMP/short_R2.fq" > "$INTERLEAVE_TMP/short-r2.out" 2>"$INTERLEAVE_TMP/short-r2.err"
SHORT_R2_CODE=$?
if [[ $SHORT_R2_CODE -ne 0 ]] && grep -q 'R2 ended prematurely' "$INTERLEAVE_TMP/short-r2.err"; then
  interleave_ok "Interleave --check rejects R2 shorter than R1"
else
  interleave_fail "Interleave R2-shorter handling [exit=$SHORT_R2_CODE err=$(cat "$INTERLEAVE_TMP/short-r2.err")]"
fi

head -n 4 "$INTERLEAVE_TMP/R1.fq" > "$INTERLEAVE_TMP/short_R1.fq"
"$SEQFU_BIN" interleave --check -1 "$INTERLEAVE_TMP/short_R1.fq" -2 "$INTERLEAVE_TMP/R2.fq" > "$INTERLEAVE_TMP/short-r1.out" 2>"$INTERLEAVE_TMP/short-r1.err"
SHORT_R1_CODE=$?
if [[ $SHORT_R1_CODE -ne 0 ]] && grep -q 'R1 ended prematurely' "$INTERLEAVE_TMP/short-r1.err"; then
  interleave_ok "Interleave --check rejects R1 shorter than R2"
else
  interleave_fail "Interleave R1-shorter handling [exit=$SHORT_R1_CODE err=$(cat "$INTERLEAVE_TMP/short-r1.err")]"
fi

rm -rf "$INTERLEAVE_TMP"

if [[ "${BASH_SOURCE[0]}" == "$0" ]] && [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
