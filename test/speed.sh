#!/bin/bash

for FILE in /local/qi/import/AN/EG/Lcr/reads/7794_51_R1.fastq /local/qi/data/SC/CEL/reads/F09.fastq.gz;
do
  seqfu count "$FILE"
  BASE=$(basename "$FILE" | cut -f1 -d.)
  hyperfine "./speed/native $FILE" "./speed/imported $FILE" --export-markdown speed/"$BASE".md
done
