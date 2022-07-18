#!/bin/bash

export SEQFU_QUIET=1

SE=$("$BINDIR"/seqfu tabulate "$FILES"/comments.fastq | SEQFU_QUIET=1 "$BINDIR"/seqfu tabulate -d | "$BINDIR"/seqfu cnt | cut -f 2)
 
if [[ $SE == "5" ]]; then
    echo -e "$OK: FASTQ sequence tabulated / detabulated"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: FASTQ sequence tabulated / detabulated 5 expected, got $SE"
    ERRORS=$((ERRORS+1))
fi 

FA=$("$BINDIR"/seqfu tabulate "$FILES"/numbers.fa   | SEQFU_QUIET=1 "$BINDIR"/seqfu tabulate -d | "$BINDIR"/seqfu cnt | cut -f 2)
if [[ $FA == "1000" ]]; then
    echo -e "$OK: FASTA sequence tabulated / detabulated"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: FASTA sequence tabulated / detabulated 1000 expected, got $FA"
    ERRORS=$((ERRORS+1))
fi 

ILVCOUNT=$("$BINDIR"/seqfu tabulate "$FILES"/interleaved.fq.gz -i | wc -l | grep -o '[[:digit:]]\+')
if [[ $ILVCOUNT == "7" ]]; then
    echo -e "$OK: FQ interleaved sequence tabulated / detabulated"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: FQ interleaved sequence tabulated / detabulated 7 PAIRS (lines) expected, got $ILVCOUNT"
    ERRORS=$((ERRORS+1))
fi 
ILV=$("$BINDIR"/seqfu tabulate "$FILES"/interleaved.fq.gz -i | SEQFU_QUIET=1 "$BINDIR"/seqfu tabulate -d | "$BINDIR"/seqfu cnt | cut -f 2)
if [[ $ILV == "14" ]]; then
    echo -e "$OK: FQ interleaved sequence tabulated / detabulated"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: FQ interleaved sequence tabulated / detabulated 14 expected, got $ILV"
    ERRORS=$((ERRORS+1))
fi 