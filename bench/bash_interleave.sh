#!/bin/bash
if [[ $# != 2 ]]
then
echo "USAGE: $0 R1.fastq R2.fastq"
exit 1
fi

paste "$1" "$2" | paste - - - - | awk -v OFS='\n' -v FS='\t' '{print($1,$3,$5,$7,$2,$4,$6,$8)}'
