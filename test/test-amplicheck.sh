TMP_AMPLICHECK_DIR=$(mktemp -d)
AMP_ERR="$TMP_AMPLICHECK_DIR/err.log"

AMP_SINGLE_OUT="$TMP_AMPLICHECK_DIR/single"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz \
  --max-reads 0 --subsample 0.5 --min-recommend-reads 1 \
  --outdir "$AMP_SINGLE_OUT" --text --plot -v \
  > /dev/null 2>"$AMP_ERR"
RET=$?
R2_NULLS=$(grep -c '"r2": null' "$AMP_SINGLE_OUT/report.json" 2>/dev/null || true)
TRUNC_LEN=$(grep '"truncLen":' "$AMP_SINGLE_OUT/report.json" | grep -o '[0-9]\+' || true)
TRUNC_LEN_FWD=$(grep '"truncLen_fwd":' "$AMP_SINGLE_OUT/report.json" | grep -o '[0-9]\+' || true)
MSG="amplicheck automatically analyzes one single-end FASTQ"
if [[ $RET -eq 0 ]] && [[ $R2_NULLS -eq 4 ]] && \
   [[ "$TRUNC_LEN" == "$TRUNC_LEN_FWD" ]] && \
   grep -q '"sample_id": "art"' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '"read_layout": "single_end"' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '"n_reads_scanned": 8' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '"n_reads_sampled": 4' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '"truncLen_rev": null' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '"truncLen":' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '"maxEE": 2.0' "$AMP_SINGLE_OUT/report.json" && \
   grep -q '^  Input:' "$AMP_SINGLE_OUT/report.txt" && \
   ! grep -q '^  R2:' "$AMP_SINGLE_OUT/report.txt" && \
   grep -q '<h2>Read</h2>' "$AMP_SINGLE_OUT/plots/art.html" && \
   ! grep -q '<canvas id="chartR"' "$AMP_SINGLE_OUT/plots/art.html" && \
   grep -q "SINGLE_END ? 'Length' : 'R1 len'" "$AMP_SINGLE_OUT/plots/index.html" && \
   grep -q 'single-end mode: pair-only merge and sweep stages are disabled' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_SINGLE_BATCH_OUT="$TMP_AMPLICHECK_DIR/single-batch"
"$BIN" amplicheck --single-end \
  "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/pico_R1.fq.gz \
  --max-reads 2 --outdir "$AMP_SINGLE_BATCH_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
NSAMPLES=$(grep -c '"sample_id"' "$AMP_SINGLE_BATCH_OUT/report.json" 2>/dev/null || true)
MSG="amplicheck --single-end treats each FASTQ as a sample and strips the forward tag"
if [[ $RET -eq 0 ]] && [[ $NSAMPLES -eq 2 ]] && \
   grep -q '"sample_id": "art"' "$AMP_SINGLE_BATCH_OUT/report.json" && \
   grep -q '"sample_id": "pico"' "$AMP_SINGLE_BATCH_OUT/report.json" && \
   ! grep -q '"read_layout": "paired_end"' "$AMP_SINGLE_BATCH_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET samples=$NSAMPLES err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_SINGLE_T1_OUT="$TMP_AMPLICHECK_DIR/single-t1"
AMP_SINGLE_T2_OUT="$TMP_AMPLICHECK_DIR/single-t2"
"$BIN" amplicheck --single-end \
  "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/pico_R1.fq.gz \
  --max-reads 10 --threads 1 --outdir "$AMP_SINGLE_T1_OUT" \
  > /dev/null 2>"$AMP_ERR"
RET1=$?
"$BIN" amplicheck --single-end \
  "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/pico_R1.fq.gz \
  --max-reads 10 --threads 2 --outdir "$AMP_SINGLE_T2_OUT" -v \
  > /dev/null 2>"$AMP_ERR"
RET2=$?
MSG="amplicheck single-end --threads 2 matches --threads 1 in input order"
if [[ $RET1 -eq 0 ]] && [[ $RET2 -eq 0 ]] && \
   cmp -s "$AMP_SINGLE_T1_OUT/report.json" "$AMP_SINGLE_T2_OUT/report.json" && \
   grep -q 'processing 2 samples with 2 threads' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (threads1=$RET1 threads2=$RET2 err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_PAIRED_T1_OUT="$TMP_AMPLICHECK_DIR/paired-t1"
AMP_PAIRED_T2_OUT="$TMP_AMPLICHECK_DIR/paired-t2"
"$BIN" amplicheck \
  "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 10 --threads 1 --outdir "$AMP_PAIRED_T1_OUT" \
  > /dev/null 2>"$AMP_ERR"
RET1=$?
"$BIN" amplicheck \
  "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 10 --threads 2 --outdir "$AMP_PAIRED_T2_OUT" \
  > /dev/null 2>"$AMP_ERR"
RET2=$?
MSG="amplicheck paired --threads 2 matches --threads 1 in input order"
if [[ $RET1 -eq 0 ]] && [[ $RET2 -eq 0 ]] && \
   cmp -s "$AMP_PAIRED_T1_OUT/report.json" "$AMP_PAIRED_T2_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (threads1=$RET1 threads2=$RET2 err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_THREAD_ERROR_INPUT="$TMP_AMPLICHECK_DIR/thread-error-input"
mkdir -p "$AMP_THREAD_ERROR_INPUT"
cp "$FILES"/primers/art_R1.fq.gz "$AMP_THREAD_ERROR_INPUT/good_R1.fq.gz"
cp "$FILES"/primers/art_R2.fq.gz "$AMP_THREAD_ERROR_INPUT/good_R2.fq.gz"
cp "$FILES"/primers/art_R1.fq.gz "$AMP_THREAD_ERROR_INPUT/bad_R1.fq.gz"
cp "$FILES"/primers/pico_R2.fq.gz "$AMP_THREAD_ERROR_INPUT/bad_R2.fq.gz"
cp "$FILES"/primers/art_R1.fq.gz "$AMP_THREAD_ERROR_INPUT/later_R1.fq.gz"
cp "$FILES"/primers/art_R2.fq.gz "$AMP_THREAD_ERROR_INPUT/later_R2.fq.gz"
AMP_THREAD_ERROR_OUT="$TMP_AMPLICHECK_DIR/thread-error-out"
"$BIN" amplicheck "$AMP_THREAD_ERROR_INPUT"/*.fq.gz --threads 2 \
  --text --plot -v --outdir "$AMP_THREAD_ERROR_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck propagates worker errors without writing partial reports"
if [[ $RET -ne 0 ]] && [[ ! -e "$AMP_THREAD_ERROR_OUT" ]] && \
   grep -q 'ERROR: sample bad: R2 has more reads than R1' "$AMP_ERR" && \
   ! grep -q 'sample later: start' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_SINGLE_PRIMER_OUT="$TMP_AMPLICHECK_DIR/single-primer"
"$BIN" amplicheck "$FILES"/primers/16S_R1.fq.gz \
  --max-reads 100 --subsample 0.1 --only primers --outdir "$AMP_SINGLE_PRIMER_OUT" \
  > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck reports one-sided primer detection for single-end reads"
if [[ $RET -eq 0 ]] && \
   grep -q '"fwd_label": "341F"' "$AMP_SINGLE_PRIMER_OUT/report.json" && \
   grep -q '"orientation_consistent": null' "$AMP_SINGLE_PRIMER_OUT/report.json" && \
   grep -q '"r2": null' "$AMP_SINGLE_PRIMER_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz --only merge \
  --outdir "$TMP_AMPLICHECK_DIR/bad-single-stage" > /dev/null 2>"$AMP_ERR"
RET=$?
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz --only overlap --skip-overlap \
  --outdir "$TMP_AMPLICHECK_DIR/bad-single-alias" > /dev/null 2>"$AMP_ERR.alias"
RET_ALIAS=$?
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz --sweep \
  --truncLen-grid 0,100 --maxEE-grid 1,2 \
  --outdir "$TMP_AMPLICHECK_DIR/bad-single-sweep" > /dev/null 2>"$AMP_ERR.sweep"
RET_SWEEP=$?
MSG="amplicheck rejects pair-only stages for single-end input"
if [[ $RET -ne 0 ]] && [[ $RET_ALIAS -ne 0 ]] && [[ $RET_SWEEP -ne 0 ]] && \
   grep -q 'merge and sweep stages require paired-end input' "$AMP_ERR" && \
   grep -q 'merge and sweep stages require paired-end input' "$AMP_ERR.alias" && \
   grep -q 'merge and sweep stages require paired-end input' "$AMP_ERR.sweep"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_ART_OUT="$TMP_AMPLICHECK_DIR/art"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --max-reads 0 --subsample 0.5 --min-recommend-reads 1 \
  --outdir "$AMP_ART_OUT" --text > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck direct pair writes JSON/text and honors --max-reads 0 with --subsample"
if [[ $RET -eq 0 ]] && \
   [[ -s "$AMP_ART_OUT/report.json" ]] && \
   [[ -s "$AMP_ART_OUT/report.txt" ]] && \
   grep -q '"read_layout": "paired_end"' "$AMP_ART_OUT/report.json" && \
   grep -q '"maxEE": \[' "$AMP_ART_OUT/report.json" && \
   grep -q '"truncLen_rev":' "$AMP_ART_OUT/report.json" && \
   grep -q '"n_reads_total": 8' "$AMP_ART_OUT/report.json" && \
   grep -q '"n_reads_scanned": 8' "$AMP_ART_OUT/report.json" && \
   grep -q '"n_reads_sampled": 4' "$AMP_ART_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_PICO_OUT="$TMP_AMPLICHECK_DIR/pico"
"$BIN" amplicheck "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 10 --subsample 0.2 --only length,quality --no-json --text \
  --outdir "$AMP_PICO_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck bounded scan samples periodically across scanned pairs"
if [[ $RET -eq 0 ]] && \
   [[ ! -e "$AMP_PICO_OUT/report.json" ]] && \
   grep -q 'Reads: scanned=10 sampled=2' "$AMP_PICO_OUT/report.txt"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_VERBOSE_OUT="$TMP_AMPLICHECK_DIR/verbose"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --max-reads 4 --subsample 0.5 --min-recommend-reads 1 \
  --only length,quality,merge --no-json --text -v \
  --outdir "$AMP_VERBOSE_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck verbose mode reports progress and sample summary"
if [[ $RET -eq 0 ]] && \
   grep -q 'amplicheck: sample art: start' "$AMP_ERR" && \
   grep -q 'progress scanned=2 sampled=1' "$AMP_ERR" && \
   grep -q 'parsed scanned=4 sampled=2' "$AMP_ERR" && \
   grep -q 'amplicheck: sample art: summary' "$AMP_ERR" && \
   grep -q '  length:' "$AMP_ERR" && \
   grep -q '  quality:' "$AMP_ERR" && \
   grep -q '  overlap:' "$AMP_ERR" && \
   grep -q '  recommendation:' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_PLOT_OUT="$TMP_AMPLICHECK_DIR/plot"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 4 --plot --no-json --outdir "$AMP_PLOT_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck --plot writes standalone HTML quality reports as an output format"
if [[ $RET -eq 0 ]] && \
   [[ ! -e "$AMP_PLOT_OUT/report.json" ]] && \
   [[ -s "$AMP_PLOT_OUT/plots/index.html" ]] && \
   [[ -s "$AMP_PLOT_OUT/plots/art.html" ]] && \
   [[ -s "$AMP_PLOT_OUT/plots/pico.html" ]] && \
    grep -q 'const SAMPLE =' "$AMP_PLOT_OUT/plots/art.html" && \
    grep -q 'drawQualityHeatmap' "$AMP_PLOT_OUT/plots/art.html" && \
    grep -q '<canvas id="chartR"' "$AMP_PLOT_OUT/plots/art.html" && \
   grep -q 'const INDEX_ROWS =' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q '"sample_id":"art"' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q '"sample_id":"pico"' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q 'Avg overlap' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q 'pageSize' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q 'sortBy' "$AMP_PLOT_OUT/plots/index.html"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --only primers --plot --outdir "$TMP_AMPLICHECK_DIR/bad-plot" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck --plot requires quality stage"
if [[ $RET -ne 0 ]] && grep -q -- '--plot requires the quality stage' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_BATCH_OUT="$TMP_AMPLICHECK_DIR/batch"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 2 --outdir "$AMP_BATCH_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
NSAMPLES=$(grep -c '"sample_id"' "$AMP_BATCH_OUT/report.json" 2>/dev/null || true)
MSG="amplicheck batch mode pairs files by tag substitution"
if [[ $RET -eq 0 ]] && [[ $NSAMPLES -eq 2 ]] && \
   grep -q '"n_reads_scanned": 2' "$AMP_BATCH_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET samples=$NSAMPLES err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_16S_OUT="$TMP_AMPLICHECK_DIR/16s"
"$BIN" amplicheck "$FILES"/primers/16S_R1.fq.gz "$FILES"/primers/16S_R2.fq.gz \
  --max-reads 100 --subsample 0.1 --only primers --outdir "$AMP_16S_OUT" \
  > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck labels known primers from bundled TSV"
if [[ $RET -eq 0 ]] && \
   grep -q '"fwd_label": "341F"' "$AMP_16S_OUT/report.json" && \
   grep -q '"rev_label": "785R/805R"' "$AMP_16S_OUT/report.json" && \
   grep -q '"orientation_consistent": true' "$AMP_16S_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_CUSTOM_OUT="$TMP_AMPLICHECK_DIR/custom-primers"
"$BIN" amplicheck "$FILES"/primers/16S_R1.fq.gz "$FILES"/primers/16S_R2.fq.gz \
  --max-reads 100 --only primers \
  --fwd-primers CCTACGGGNGGCWGCAG \
  --rev-primers GACTACHVGGGTATCTAATCC \
  --outdir "$AMP_CUSTOM_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck checks only user-supplied primers when provided"
if [[ $RET -eq 0 ]] && \
   grep -q '"fwd_label": "custom_fwd_1"' "$AMP_CUSTOM_OUT/report.json" && \
   grep -q '"rev_label": "custom_rev_1"' "$AMP_CUSTOM_OUT/report.json" && \
   ! grep -q '"fwd_label": "341F"' "$AMP_CUSTOM_OUT/report.json" && \
   ! grep -q '"rev_label": "785R/805R"' "$AMP_CUSTOM_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_LOW_SUPPORT_OUT="$TMP_AMPLICHECK_DIR/low-primer-support"
"$BIN" amplicheck "$FILES"/primers/small.fq --only primers \
  --fwd-primers CCTACGGGAGGCTGCAGAAGCAAGTGGCAC \
  --outdir "$AMP_LOW_SUPPORT_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck rejects primer calls without substantial read support"
if [[ $RET -eq 0 ]] && \
   grep -q '"detected": false' "$AMP_LOW_SUPPORT_OUT/report.json" && \
   grep -q '"support_count": 1' "$AMP_LOW_SUPPORT_OUT/report.json" && \
   grep -q '"consensus": "CCTAC' "$AMP_LOW_SUPPORT_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_MIN_REC_OUT="$TMP_AMPLICHECK_DIR/min-recommendation"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz \
  --outdir "$AMP_MIN_REC_OUT" --text > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck requires 5000 sampled reads for recommendations by default"
if [[ $RET -eq 0 ]] && \
   grep -q '"recommendation_min_reads": 5000' "$AMP_MIN_REC_OUT/report.json" && \
   grep -q '"recommendation_reads_sufficient": false' "$AMP_MIN_REC_OUT/report.json" && \
   grep -q '"recommendation": null' "$AMP_MIN_REC_OUT/report.json" && \
   grep -q 'Recommendation: not emitted; requires at least 5000 sampled reads' "$AMP_MIN_REC_OUT/report.txt"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --subsample 0 --outdir "$TMP_AMPLICHECK_DIR/bad" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck rejects invalid --subsample"
if [[ $RET -ne 0 ]] && grep -q -- '--subsample must satisfy' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz --threads banana \
  --outdir "$TMP_AMPLICHECK_DIR/bad-threads" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck rejects non-integer --threads"
if [[ $RET -ne 0 ]] && grep -q -- '--threads must be an integer' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

rm -rf "$TMP_AMPLICHECK_DIR"
