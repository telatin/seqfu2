#!/bin/bash

if [[ $# != 3 ]]
then
echo "USAGE: $0 interleaved.fastq deinterleaved.R1.fastq deinterleaved.R2.fastq"
exit 1
fi

paste - - - - - - - - < "$1" | tee >(cut -f 1-4 | tr '\t' '\n' > "$2") | cut -f 5-8 | tr '\t' '\n' > "$3"
