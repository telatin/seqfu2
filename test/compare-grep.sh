#!/bin/bash

for FILE in data/numbers.fa data/filt.fa.gz;
do
  for PATTERN in 12$ filt.598..;
  do
    for SWITCH in "-w" "-f";
    do
      echo "=== $PATTERN $SWITCH"
      hyperfine "bin/seqfu grep $SWITCH -r $PATTERN $FILE" \
                "bin/seqfu grep2 $SWITCH -r $PATTERN $FILE"
    done
  done
done
