#!/usr/bin/env bash

BYCOMMENT_BIN="${BINDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/}/seqfu"
BYCOMMENT_TMP=$(mktemp -d)
PASS=${PASS:-0}
ERRORS=${ERRORS:-0}

bycomment_ok() {
  echo "OK: by-comment: $1"
  PASS=$((PASS+1))
}

bycomment_fail() {
  echo "FAIL: by-comment: $1"
  ERRORS=$((ERRORS+1))
}

bycomment_expect_names() {
  local label=$1 expected=$2
  shift 2
  local actual
  if ! "$BYCOMMENT_BIN" by-comment "$@" > "$BYCOMMENT_TMP/names.out"; then
    bycomment_fail "$label (command failed)"
    return
  fi
  actual=$(awk '/^[>@]/{sub(/^[>@]/, "", $1); print $1}' "$BYCOMMENT_TMP/names.out" | paste -sd, -)
  if [[ "$actual" == "$expected" ]]; then
    bycomment_ok "$label"
  else
    bycomment_fail "$label (expected '$expected', got '$actual')"
  fi
}

bycomment_expect_error() {
  local label=$1
  shift
  if "$BYCOMMENT_BIN" by-comment "$@" > "$BYCOMMENT_TMP/error.out" 2> "$BYCOMMENT_TMP/error.err"; then
    bycomment_fail "$label (unexpected success)"
  else
    bycomment_ok "$label"
  fi
}

cat > "$BYCOMMENT_TMP/records.fa" <<'EOF'
>alpha complete genome len=2,203 gc=0.49 score=3 status=complete sample=001 description="complete circular genome"
ACG
>beta draft len=1,999 gc=0.55 score=1 status=draft sample=002
TTT
>gamma malformed len=2,20 gc=0.40 score=4 status=complete
GGA
>delta prose without attributes
CCC
>zeta large len=3,000,000,000 gc=0.80 status=big
ATA
>empty
TAC
EOF

cat > "$BYCOMMENT_TMP/more.fa" <<'EOF'
>extra complete len=2,500 gc=0.40
ATG
EOF

cat > "$BYCOMMENT_TMP/patterns.txt" <<'EOF'
# Text patterns
complete
draft
EOF

cat > "$BYCOMMENT_TMP/predicates.txt" <<'EOF'
# Numeric predicates
len >= 2000
gc < 0.5
EOF

cat > "$BYCOMMENT_TMP/expression.txt" <<'EOF'
(len >= 2000 && gc < 0.5) || status == "draft"
EOF

cat > "$BYCOMMENT_TMP/duplicates.fa" <<'EOF'
>dup len=1 len=2
ACG
EOF

cat > "$BYCOMMENT_TMP/custom.fa" <<'EOF'
>custom len:2.203; gc:0,49 note:"a \"quoted\" value"
ACG
EOF

cat > "$BYCOMMENT_TMP/numbers.fa" <<'EOF'
>precise len=9,007,199,254,740,993 gc=-1.2e-4
ACG
>previous len=9,007,199,254,740,992 gc=0.1
TTT
>overflow len=99,999,999,999,999,999,999,999
GGG
>mapped read-count=12 read.depth=7
CCC
>collision read-count=12 read.count=7
AAA
EOF

cat > "$BYCOMMENT_TMP/R1.fq" <<'EOF'
@pair_001/1 len=2,500 score=3
ACG
+
III
@pair_002/1 len=100 score=1
TTT
+
###
@pair_003/1 len=3,000 score=2
GGA
+
I!I
EOF

cat > "$BYCOMMENT_TMP/R2.fq" <<'EOF'
@pair_001/2 len=100 score=1
TGC
+
JJJ
@pair_002/2 len=2,700 score=4
AAA
+
$$$
@pair_003/2 len=3,200 score=5
TCC
+
J!J
EOF

cat > "$BYCOMMENT_TMP/interleaved.fq" <<'EOF'
@pair_001/1 len=2,500 score=3
ACG
+
III
@pair_001/2 len=100 score=1
TGC
+
JJJ
@pair_002/1 len=100 score=1
TTT
+
###
@pair_002/2 len=2,700 score=4
AAA
+
$$$
@pair_003/1 len=3,000 score=2
GGA
+
I!I
@pair_003/2 len=3,200 score=5
TCC
+
J!J
EOF

bycomment_expect_names "regex on raw comment" "alpha,extra" \
  'complete.*len=2,' "$BYCOMMENT_TMP/records.fa" "$BYCOMMENT_TMP/more.fa"
bycomment_expect_names "case-insensitive text" "alpha,gamma" \
  -i -F -e COMPLETE "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "text patterns OR" "alpha,beta,gamma" \
  -f "$BYCOMMENT_TMP/patterns.txt" -F "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "text patterns AND" "alpha" \
  -e complete -e circular --logic all "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "has comment" "alpha,beta,gamma,delta,zeta" \
  --has-comment "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "no comment" "empty" \
  --no-comment "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "invert final selection" "beta,gamma,delta,zeta,empty" \
  -e circular -v "$BYCOMMENT_TMP/records.fa"

bycomment_expect_names "integer grouping and numeric comparison" "alpha,zeta" \
  --where 'len >= 2000' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "where AND by default" "alpha" \
  --where 'len >= 2000' --where 'gc < 0.5' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "where OR" "alpha,beta,zeta" \
  --where 'len >= 2000' --where 'status = draft' --where-logic any "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "where file" "alpha" \
  --where-file "$BYCOMMENT_TMP/predicates.txt" "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "where exists" "alpha,beta,gamma,zeta" \
  --where 'len exists' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "where missing" "delta,empty" \
  --where 'len missing' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "malformed grouping does not pass numeric comparison" "alpha,beta,zeta" \
  --where 'len > 1000' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "string equality" "alpha,gamma" \
  --where 'status = complete' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "string regex on raw numeric value" "alpha" \
  --where 'len ~ ^2,203$' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "negative regex requires present attribute" "beta,zeta" \
  --where 'status !~ ^complete$' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "quoted string attribute" "alpha" \
  --where 'description = "complete circular genome"' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "numeric equality ignores leading zeroes" "alpha" \
  --where 'sample = 1' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "forced string keeps leading zeroes" "" \
  --attribute-type sample:string --where 'sample = 1' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "repeated attribute types" "alpha" \
  --attribute-type sample:string --attribute-type len:integer \
  --where 'sample = 001' --where 'len >= 2000' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "custom numeric separators" "custom" \
  --attribute-separator : --decimal-separator , --thousands-separator . \
  --where 'len >= 2000' --where 'gc < 0,5' "$BYCOMMENT_TMP/custom.fa"
bycomment_expect_names "escaped quote in attribute" "custom" \
  --attribute-separator : --where 'note = "a \"quoted\" value"' "$BYCOMMENT_TMP/custom.fa"
bycomment_expect_names "duplicate keys use last" "dup" \
  --where 'len = 2' "$BYCOMMENT_TMP/duplicates.fa"
bycomment_expect_names "duplicate keys can use first" "dup" \
  --duplicate-keys first --where 'len = 1' "$BYCOMMENT_TMP/duplicates.fa"
bycomment_expect_names "integer comparisons stay exact past 2^53" "precise" \
  --where 'len = 9007199254740993' "$BYCOMMENT_TMP/numbers.fa"
bycomment_expect_names "scientific notation is numeric" "precise" \
  --where 'gc < 0' "$BYCOMMENT_TMP/numbers.fa"
bycomment_expect_names "overflowing integers never wrap" "" \
  --where 'len > 9007199254740993' "$BYCOMMENT_TMP/numbers.fa"

bycomment_expect_names "expression arithmetic and boolean" "alpha" \
  --expr 'len * gc >= 1000 && status == "complete"' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "expression file" "alpha,beta" \
  --expr-file "$BYCOMMENT_TMP/expression.txt" "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "expression uses full int64 values" "zeta" \
  --expr 'len > 2147483647' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "unrelated malformed attribute does not fail expression" "alpha,gamma" \
  --expr 'status == "complete"' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "malformed numeric-looking expression value is not zero" "" \
  --expr 'len < 100' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "missing expression variable evaluates false" "" \
  --expr 'unknown >= 0' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "text where and expression combine" "alpha" \
  -e complete --where 'len >= 2000' --expr 'gc < 0.5' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_names "expression maps punctuation in attribute keys" "mapped" \
  --where 'read.depth exists' --expr 'read_count == 12 && read_depth == 7' "$BYCOMMENT_TMP/numbers.fa"

bycomment_expect_names "paired any keeps both mates" "pair_001/1,pair_001/2,pair_002/1,pair_002/2,pair_003/1,pair_003/2" \
  --where 'len >= 2000' -1 "$BYCOMMENT_TMP/R1.fq" -2 "$BYCOMMENT_TMP/R2.fq"
bycomment_expect_names "paired both requires both comments" "pair_003/1,pair_003/2" \
  --where 'len >= 2000' --pair-mode both -1 "$BYCOMMENT_TMP/R1.fq" -2 "$BYCOMMENT_TMP/R2.fq"
bycomment_expect_names "interleaved paired input" "pair_003/1,pair_003/2" \
  --expr 'len >= 2000' --pair-mode both --interleaved "$BYCOMMENT_TMP/interleaved.fq"

"$BYCOMMENT_BIN" by-comment --has-comment -1 "$BYCOMMENT_TMP/R1.fq" -2 "$BYCOMMENT_TMP/R2.fq" \
  -o "$BYCOMMENT_TMP/out_R1.fq.gz"
if gzip -t "$BYCOMMENT_TMP/out_R1.fq.gz" && gzip -t "$BYCOMMENT_TMP/out_R2.fq.gz" &&
   cmp -s "$BYCOMMENT_TMP/R1.fq" <(gzip -cd "$BYCOMMENT_TMP/out_R1.fq.gz") &&
   cmp -s "$BYCOMMENT_TMP/R2.fq" <(gzip -cd "$BYCOMMENT_TMP/out_R2.fq.gz"); then
  bycomment_ok "inferred split gzip preserves paired FASTQ payloads"
else
  bycomment_fail "inferred split gzip preserves paired FASTQ payloads"
fi

"$BYCOMMENT_BIN" by-comment --where 'len >= 2000' -t 2 --batch-size 1 \
  -1 "$BYCOMMENT_TMP/R1.fq" -2 "$BYCOMMENT_TMP/R2.fq" -o "$BYCOMMENT_TMP/threaded.fq"
"$BYCOMMENT_BIN" by-comment --where 'len >= 2000' \
  -1 "$BYCOMMENT_TMP/R1.fq" -2 "$BYCOMMENT_TMP/R2.fq" -o "$BYCOMMENT_TMP/sequential.fq"
if cmp -s "$BYCOMMENT_TMP/threaded.fq" "$BYCOMMENT_TMP/sequential.fq"; then
  bycomment_ok "threaded paired output is ordered and exact"
else
  bycomment_fail "threaded paired output is ordered and exact"
fi

"$BYCOMMENT_BIN" by-comment --has-comment -1 "$BYCOMMENT_TMP/R1.fq" -2 "$BYCOMMENT_TMP/R2.fq" \
  -o "$BYCOMMENT_TMP/combined.fq"
if cmp -s "$BYCOMMENT_TMP/interleaved.fq" "$BYCOMMENT_TMP/combined.fq"; then
  bycomment_ok "paired -o without inferred R2 stays interleaved"
else
  bycomment_fail "paired -o without inferred R2 stays interleaved"
fi

"$BYCOMMENT_BIN" by-comment --expr 'len >= 2000' -t 2 --batch-size 1 \
  "$BYCOMMENT_TMP/records.fa" > "$BYCOMMENT_TMP/threaded.fa"
"$BYCOMMENT_BIN" by-comment --expr 'len >= 2000' \
  "$BYCOMMENT_TMP/records.fa" > "$BYCOMMENT_TMP/sequential.fa"
if cmp -s "$BYCOMMENT_TMP/threaded.fa" "$BYCOMMENT_TMP/sequential.fa"; then
  bycomment_ok "threaded expression output matches sequential"
else
  bycomment_fail "threaded expression output matches sequential"
fi

cat "$BYCOMMENT_TMP/records.fa" | "$BYCOMMENT_BIN" by-comment --where 'status = draft' > "$BYCOMMENT_TMP/stdin.fa"
if [[ $(awk '/^>/{print $1}' "$BYCOMMENT_TMP/stdin.fa") == '>beta' ]]; then
  bycomment_ok "implicit stdin"
else
  bycomment_fail "implicit stdin"
fi

bycomment_expect_error "conflicting presence switches" --has-comment --no-comment "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "attribute separator cannot be a key character" --attribute-separator . \
  --where 'len exists' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "invalid where syntax" --where 'len >> 2' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "invalid where regex" --where 'status ~ [' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "malformed grouping can error" --invalid-value error --where 'len >= 2000' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "malformed expression value can error" --invalid-value error \
  --expr 'len < 100' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "duplicate keys can error" --duplicate-keys error --where 'len exists' "$BYCOMMENT_TMP/duplicates.fa"
bycomment_expect_error "invalid forced integer can error" --attribute-type len:integer --invalid-value error \
  --where 'len exists' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "mapped expression key collision errors" \
  --expr 'read_count > 0' "$BYCOMMENT_TMP/numbers.fa"
bycomment_expect_error "invalid expression syntax" --expr '(len >= 2000' "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "expression interfaces are exclusive" --expr 'len > 1' \
  --expr-file "$BYCOMMENT_TMP/expression.txt" "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "paired input requires both files" --has-comment -1 "$BYCOMMENT_TMP/R1.fq"
bycomment_expect_error "output cannot overwrite input" --has-comment -o "$BYCOMMENT_TMP/records.fa" "$BYCOMMENT_TMP/records.fa"
bycomment_expect_error "output cannot overwrite predicate file" --where-file "$BYCOMMENT_TMP/predicates.txt" \
  -o "$BYCOMMENT_TMP/predicates.txt" "$BYCOMMENT_TMP/records.fa"

rm -r "$BYCOMMENT_TMP"
