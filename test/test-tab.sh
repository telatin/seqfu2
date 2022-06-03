#!/bin/bash

export SEQFU_QUIET=1

SE=$("$BINDIR"/seqfu tabulate data/comments.fastq | awk  -v OFS='\t'  'gsub("E","e",$1);' | SEQFU_QUIET=1 "$BINDIR"/seqfu tabulate -d | "$BINDIR"/seqfu cnt | cut -f 2)
 
if [[ $SE == "5" ]]; then
    echo -e "$OK: sequence tabulated / detabulated"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: sequence tabulated / detabulated 5 expected, got $SE"
    FAIL=$((FAIL+1))
    ERRORS=$((ERRORS+1))
fi 