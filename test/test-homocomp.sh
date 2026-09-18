TMP_HOMOCOMP_DIR=$(mktemp -d)
HOMO_FASTA="$TMP_HOMOCOMP_DIR/input.fa"
HOMO_FASTQ="$TMP_HOMOCOMP_DIR/input.fq"
HOMO_FASTQ_GZ="$TMP_HOMOCOMP_DIR/input.fq.gz"
HOMO_EXPECTED_FASTA="$TMP_HOMOCOMP_DIR/expected.fa"
HOMO_EXPECTED_FASTQ="$TMP_HOMOCOMP_DIR/expected.fq"
HOMO_EMPTY_FASTA="$TMP_HOMOCOMP_DIR/empty.fa"
HOMO_EXPECTED_EMPTY="$TMP_HOMOCOMP_DIR/expected-empty.fa"
HOMO_EMPTY_FASTQ="$TMP_HOMOCOMP_DIR/empty.fq"
HOMO_EXPECTED_EMPTY_FASTQ="$TMP_HOMOCOMP_DIR/expected-empty.fq"

printf '>fasta comment\nAAACCCGTTTTA\n' > "$HOMO_FASTA"
printf '@fastq comment\nAAACCCGTTTTA\n+\n123456789ABC\n' > "$HOMO_FASTQ"
gzip -c "$HOMO_FASTQ" > "$HOMO_FASTQ_GZ"
printf '>fasta comment\nACGTA\n' > "$HOMO_EXPECTED_FASTA"
printf '@fastq comment\nACGTA\n+\n1478C\n' > "$HOMO_EXPECTED_FASTQ"
printf '>empty comment\n>nonempty\nAAAA\n' > "$HOMO_EMPTY_FASTA"
printf '>empty comment\n>nonempty\nA\n' > "$HOMO_EXPECTED_EMPTY"
printf '@empty comment\n\n+\n\n@nonempty\nAAAA\n+\n1234\n' > "$HOMO_EMPTY_FASTQ"
printf '@empty comment\n\n+\n\n@nonempty\nA\n+\n1\n' > "$HOMO_EXPECTED_EMPTY_FASTQ"

HOMO_FASTA_OUT="$TMP_HOMOCOMP_DIR/fasta.out"
"$BIN" homocomp "$HOMO_FASTA" > "$HOMO_FASTA_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp preserves FASTA names/comments and collapses runs"
if [[ $RET -eq 0 ]] && cmp -s "$HOMO_EXPECTED_FASTA" "$HOMO_FASTA_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

HOMO_EMPTY_FASTQ_OUT="$TMP_HOMOCOMP_DIR/empty-fastq.out"
"$BIN" homocomp "$HOMO_EMPTY_FASTQ" > "$HOMO_EMPTY_FASTQ_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp preserves empty FASTQ records and format"
if [[ $RET -eq 0 ]] && cmp -s "$HOMO_EXPECTED_EMPTY_FASTQ" "$HOMO_EMPTY_FASTQ_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

HOMO_EMPTY_OUT="$TMP_HOMOCOMP_DIR/empty.out"
"$BIN" homocomp "$HOMO_EMPTY_FASTA" > "$HOMO_EMPTY_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp preserves empty FASTA records"
if [[ $RET -eq 0 ]] && cmp -s "$HOMO_EXPECTED_EMPTY" "$HOMO_EMPTY_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

HOMO_FASTQ_OUT="$TMP_HOMOCOMP_DIR/fastq.out"
"$BIN" homocomp "$HOMO_FASTQ" > "$HOMO_FASTQ_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp keeps the first quality score from each FASTQ run"
if [[ $RET -eq 0 ]] && cmp -s "$HOMO_EXPECTED_FASTQ" "$HOMO_FASTQ_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

HOMO_STDIN_OUT="$TMP_HOMOCOMP_DIR/stdin.out"
"$BIN" homocomp < "$HOMO_FASTQ" > "$HOMO_STDIN_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp reads FASTQ from stdin"
if [[ $RET -eq 0 ]] && cmp -s "$HOMO_EXPECTED_FASTQ" "$HOMO_STDIN_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

HOMO_GZIP_OUT="$TMP_HOMOCOMP_DIR/gzip.out"
"$BIN" homocomp "$HOMO_FASTQ_GZ" > "$HOMO_GZIP_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp reads gzip-compressed FASTQ"
if [[ $RET -eq 0 ]] && cmp -s "$HOMO_EXPECTED_FASTQ" "$HOMO_GZIP_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

HOMO_T1_OUT="$TMP_HOMOCOMP_DIR/threads1.out"
HOMO_T2_OUT="$TMP_HOMOCOMP_DIR/threads2.out"
"$BIN" homocomp "$HOMO_FASTA" "$HOMO_FASTQ" "$HOMO_FASTA" "$HOMO_FASTQ" \
  --threads 1 --batch-size 1 > "$HOMO_T1_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET1=$?
"$BIN" homocomp "$HOMO_FASTA" "$HOMO_FASTQ" "$HOMO_FASTA" "$HOMO_FASTQ" \
  --threads 2 --batch-size 1 > "$HOMO_T2_OUT" 2> "$TMP_HOMOCOMP_DIR/err"
RET2=$?
MSG="homocomp --threads 2 matches --threads 1 and preserves input order"
if [[ $RET1 -eq 0 ]] && [[ $RET2 -eq 0 ]] && cmp -s "$HOMO_T1_OUT" "$HOMO_T2_OUT"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (threads1=$RET1 threads2=$RET2 err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" homocomp "$TMP_HOMOCOMP_DIR/missing.fq" > /dev/null 2> "$TMP_HOMOCOMP_DIR/err"
RET=$?
MSG="homocomp rejects missing input files"
if [[ $RET -ne 0 ]] && grep -q 'input file not found' "$TMP_HOMOCOMP_DIR/err"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$TMP_HOMOCOMP_DIR/err"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" homocomp "$HOMO_FASTA" --threads 0 > /dev/null 2> "$TMP_HOMOCOMP_DIR/err"
RET_THREADS=$?
"$BIN" homocomp "$HOMO_FASTA" --batch-size banana > /dev/null 2> "$TMP_HOMOCOMP_DIR/err.batch"
RET_BATCH=$?
MSG="homocomp validates thread and batch options"
if [[ $RET_THREADS -ne 0 ]] && [[ $RET_BATCH -ne 0 ]] && \
   grep -q -- '--threads must be >= 1' "$TMP_HOMOCOMP_DIR/err" && \
   grep -q -- 'must be integers' "$TMP_HOMOCOMP_DIR/err.batch"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (threads=$RET_THREADS batch=$RET_BATCH)"
  ERRORS=$((ERRORS+1))
fi

rm -rf "$TMP_HOMOCOMP_DIR"
