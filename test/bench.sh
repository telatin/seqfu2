#!/bin/bash
# RUN BENCHMARKS
# requires hyperfine

R1="$1"
R2="$2"

#################
# PREPARE FILES #
#################
zcat "$R1" > R1.fq
zcat "$R2" > R2.fq
seqfu interleave -1 R1.fq -2 R2.fq > interleaved.fq

ls -lh $R1 $R2
wc -l R1.fq R2.fq

HF="hyperfine --warmup 1 --shell bash --export-markdown"
DST=test/bench
mkdir -p $DST

####################
# INTERLEAVE TESTS #
####################
$HF $DST/interleave.md "./bin/seqfu interleave -1 R1.fq -2 R2.fq" "seqfu interleave -1 R1.fq -2 R2.fq" "paste R1.fq R2.fq | paste - - - - | awk -v OFS='\\n' -v FS='\\t' '{print("'$1,$3,$5,$7,$2,$4,$6,$8'")}'"

(time ./bin/seqfu interleave -1 R1.fq -2 R2.fq > /dev/null) 2> $DST/interleave.time.txt
(time paste R1.fq R2.fq | paste - - - - | awk -v OFS='\n' -v FS='\t' '{print($1,$3,$5,$7,$2,$4,$6,$8)}' > /dev/null) 2>> $DST/interleave.time.txt

#######################
# DE-INTERLEAVE TESTS #
#######################

$HF $DST/deinterleave.md "seqfu deinterleave -o deinterleaved interleaved.fq" "paste - - - - - - - - < interleaved.fq | tee >(cut -f 1-4 | tr '\\t' '\\n' > deinterleaved.R1.fq) | cut -f 5-8 | tr '\\t' '\\n' > deinterleaved.R2.fq"

(time seqfu deinterleave -o deinterleaved interleaved.fq > /dev/null) 2> $DST/deinterleave.time.txt
(time paste - - - - - - - - < interleaved.fq | tee >(cut -f 1-4 | tr '\t' '\n' > deinterleaved.R1.fq) | cut -f 5-8 | tr '\t' '\n' > deinterleaved.R2,fq) 2>> $DST/deinterleave.time.txt

############
# CLEAN UP #
############
rm -f R[12].fq interleaved.fq deinterleaved[_.]R[12].fq
