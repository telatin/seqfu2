hyperfine "bin/seqfu trim -1 data/primers/16S_R1.fq.gz -2 data/primers/16S_R2.fq.gz -o 16S_seqfu \
  --cut-tail --cut-tail-window 4 --cut-tail-qual 20 \
  --qualified-qual 15 --unqualified-percent 40 -n 5 -l 15" \
"fastp -i data/primers/16S_R1.fq.gz -I data/primers/16S_R2.fq.gz \
  -o 16S_fastp_R1.fastq -O 16S_fastp_R2.fastq \
  --disable_adapter_trimming --disable_trim_poly_g \
  --cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 \
  --qualified_quality_phred 15 --unqualified_percent_limit 40 \
  --n_base_limit 5 --length_required 15 \
  -j 16S_fastp.json -h 16S_fastp.html"
