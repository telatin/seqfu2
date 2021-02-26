#!/bin/bash
# RUN BENCHMARKS
# requires hyperfine
if [[ $# != 2 ]]
then
echo "USAGE: $0 R1.fastq.gz R2.fastq.gz"
exit 1
fi

R1="$1"
R2="$2"

#################
# PREPARE FILES #
#################
echo Decompress test files
zcat "$R1" > R1.fq
zcat "$R2" > R2.fq
seqfu interleave -1 R1.fq -2 R2.fq > interleaved.fq


hyperfine --warmup 1 --export-markdown interleave_benchmarks.md --export-csv interleave_benchmarks.csv "seqfu interleave -1 R1.fq -2 R2.fq" "taskset 1 ./bash_interleave.sh R1.fq R2.fq"

hyperfine --warmup 1 --export-markdown deinterleave_benchmarks.md --export-csv deinterleave_benchmarks.csv "seqfu deinterleave -o de interleaved.fq" "taskset 1 ./bash_deinterleave.sh interleaved.fq de_R1.fq de_R2.fq"


#for i in {1..3}
#do time sleep 0.1 > /dev/null
#done 2>&1 | paste - - - - | awk -v OFS='\t' '{print NR,$2,$4,$6}'

# TIME TEST WITH DEINTERLEAVE
(
echo "Testing SeqFu deinterleave:"
echo -e "TEST\tREAL\tUSER\tSYS"
for i in {1..11}
do time seqfu deinterleave -o deinterleaved interleaved.fq
done 2>&1 | paste - - - - | awk -v OFS='\t' '{print NR,$2,$4,$6}'
echo "Testing BASH deinterleave:"
echo -e "TEST\tREAL\tUSER\tSYS"
for i in {1..11}
do time paste - - - - - - - - < interleaved.fq | tee >(cut -f 1-4 | tr '\t' '\n' > deinterleaved.R1.fq) | cut -f 5-8 | tr '\t' '\n' > deinterleaved.R2.fq
done 2>&1 | paste - - - - | awk -v OFS='\t' '{print NR,$2,$4,$6}'
) > deinterleave.time.txt


############
# CLEAN UP #
############
rm -f R[12].fq interleaved.fq de_R[12].fq

