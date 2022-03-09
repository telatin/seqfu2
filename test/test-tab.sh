#!/bin/bash
SE=$("$BINDIR"/seqfu tabulate data/comments.fastq | awk  -v OFS='\t'  'gsub("E","e",$1);' | "$BINDIR"/seqfu tabulate -d | "$BINDIR"/seqfu cnt | cut -f 2)
 
if [[ $SE = "5" ]]; then
    echo "OK: sequence tabulated / detabulated"
    PASS=$((PASS+1))
else
    echo "FAIL: sequence tabulated / detabulated 5 expected, got $SE"
    FAIL=$((FAIL+1))
    ERRORS=$((ERRORS+1))
fi 