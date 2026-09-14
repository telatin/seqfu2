#!/bin/bash

if [[ -z ${DIR+x} ]]; then
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
fi
if [[ -z ${BINDIR+x} ]]; then BINDIR="$DIR/../bin"; fi
if [[ -z ${OK+x} ]]; then OK='\033[0;32mOK\033[0m'; fi
if [[ -z ${FAIL+x} ]]; then FAIL='\033[0;31mFAIL\033[0m'; fi
if [[ -z ${PASS+x} ]]; then PASS=0; fi
if [[ -z ${ERRORS+x} ]]; then ERRORS=0; fi

FU_REGION="${BINDIR%/}/fu-16Sregion"
TMP_REGION_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_REGION_DIR"' EXIT

REGION_FQ="$TMP_REGION_DIR/v3_strands.fq"
cat > "$REGION_FQ" <<'EOF'
@forward
ACTCCTACGGGAGGCAGCAGTGGGGAATATTGCACAATGGGCGCAAGCCTGATGCAGCCATGCCGCGTGTATGAAGAAGGCCTTCGGGTTGTAAAGTACTTTCAGCGGGGAGGAAGGGAGTAAAGTTAATACCTTTGCTCATTGACGTTACCCGCAGAAGAAGCACCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACG
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
@reverse
CGTATTACCGCGGCTGCTGGCACGGAGTTAGCCGGTGCTTCTTCTGCGGGTAACGTCAATGAGCAAAGGTATTAACTTTACTCCCTTCCTCCCCGCTGAAAGTACTTTACAACCCGAAGGCCTTCTTCATACACGCGGCATGGCTGCATCAGGCTTGCGCCCATTGTGCAATATTCCCCACTGCTGCCTCCCGTAGGAGT
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
EOF

MSG="fu-16Sregion classifies reverse-complement reads"
OBS=$("$FU_REGION" --max-reads 2 --min-score 1000 --min-fraction 0 --min-coverage 0.4 "$REGION_FQ" 2>/dev/null)
if [[ "$(echo "$OBS" | cut -f 1-2)" == $'V3\t100.00' ]] && [[ "$(echo "$OBS" | cut -f 5)" == "V3" ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (got: $OBS)"
  ERRORS=$((ERRORS+1))
fi

MSG="fu-16Sregion --max-reads denominator counts processed reads only"
OBS=$("$FU_REGION" --max-reads 1 --min-score 1000 --min-fraction 0.75 --min-coverage 0.4 "$REGION_FQ" 2>/dev/null)
if [[ "$(echo "$OBS" | cut -f 1-4)" == $'V3\t100.00\t1\t1' ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (got: $OBS)"
  ERRORS=$((ERRORS+1))
fi

PARTIAL_FQ="$TMP_REGION_DIR/partial_v4.fq"
cat > "$PARTIAL_FQ" <<'EOF'
@partial_v4
TGTTAAGTCAGATGTGAAATCCCCGGGCTCAACCTGGG
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
EOF

MSG="fu-16Sregion appends interval calls without changing leading output columns"
OBS=$("$FU_REGION" --max-reads 1 --min-score 100 --min-fraction 0 --min-coverage 0.4 "$PARTIAL_FQ" 2>/dev/null)
if [[ "$(echo "$OBS" | cut -f 1-2)" == $'Unclassified\t100.00' ]] && [[ "$(echo "$OBS" | cut -f 5)" == "partial-V4" ]]; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (got: $OBS)"
  ERRORS=$((ERRORS+1))
fi

MSG="fu-16Sregion verbose output includes interval call"
if "$FU_REGION" --max-reads 1 --min-score 100 --min-fraction 0 --min-coverage 0.4 -v "$PARTIAL_FQ" >/dev/null 2>"$TMP_REGION_DIR/partial.err" &&
    grep -q $'regions:Unclassified\tFail\tinterval_call:partial-V4' "$TMP_REGION_DIR/partial.err"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG"
  ERRORS=$((ERRORS+1))
fi

MSG="fu-16Sregion missing input exits nonzero"
RET=0
"$FU_REGION" "$TMP_REGION_DIR/missing.fq" > /dev/null 2>"$TMP_REGION_DIR/missing.err" || RET=$?
if [[ $RET -ne 0 ]] && grep -q "Input file not found" "$TMP_REGION_DIR/missing.err"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET)"
  ERRORS=$((ERRORS+1))
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]] && [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
