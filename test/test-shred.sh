#!/bin/bash
# Tests for "seqfu shred". Sourced by test/mini.sh, but can also run directly.
TESTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR=${BINDIR:-"$TESTDIR/../bin/"}
FILES=${FILES:-"$TESTDIR/../data/"}
OK=${OK:-'\033[0;32mOK\033[0m'}
FAIL=${FAIL:-'\033[0;31mFAIL\033[0m'}
PASS=${PASS:-0}
ERRORS=${ERRORS:-0}

export SEQFU_QUIET=1
INPUT="$FILES"/16S_coli.fa
TEMPORARY_DIR=$(mktemp -d)
TEMPFILENAME="$TEMPORARY_DIR"/se.fq

shred_check() {
    # shred_check MESSAGE EXPECTED GOT
    if [[ "$3" == "$2" ]]; then
        echo -e "$OK: $1"
        PASS=$((PASS+1))
    else
        echo -e "$FAIL: $1 (expected $2, got $3)"
        ERRORS=$((ERRORS+1))
    fi
}
shred_rc() {
    echo "$1" | rev | tr ACGTacgt TGCAtgca
}
# Reference sequence as a single line
REF=$(grep -v '>' "$INPUT" | tr -d '\n\r')
REFLEN=${#REF}

### SINGLE END (legacy)
"$BINDIR"/seqfu shred "$INPUT" -l 100 -s 150 > "$TEMPFILENAME"
shred_check "SE: 10 sequences" 10 "$("$BINDIR"/seqfu count "$TEMPFILENAME" | cut -f 2)"
shred_check "SE: Total length 1000bp" 1000 "$("$BINDIR"/seqfu stats "$TEMPFILENAME" | cut -f 3 | tail -n 1)"
shred_check "SE: second read payload" "${REF:150:100}" "$(sed -n 6p "$TEMPFILENAME")"

"$BINDIR"/seqfu shred "$INPUT" -l 100 -s 150 -r > "$TEMPFILENAME"
shred_check "SE --add-rc: first read reverse complemented" "$(shred_rc "${REF:0:100}")" "$(sed -n 2p "$TEMPFILENAME")"
shred_check "SE --add-rc: second read forward" "${REF:150:100}" "$(sed -n 6p "$TEMPFILENAME")"

"$BINDIR"/seqfu shred "$INPUT" -l 600 -s 500 > "$TEMPFILENAME"
shred_check "SE: read length above default fragment length" 2 "$("$BINDIR"/seqfu count "$TEMPFILENAME" | cut -f 2)"

### PAIRED END (legacy --out-prefix)
FWD="$TEMPORARY_DIR"/illuminate_R1.fq
REV="$TEMPORARY_DIR"/illuminate_R2.fq
"$BINDIR"/seqfu shred "$INPUT" -f 100 -l 50 -s 150 -o "$TEMPORARY_DIR"/illuminate
if [[ -e "$FWD" ]] && [[ -e "$REV" ]]; then
    shred_check "PE: output found $FWD,$REV" 1 1
else
    shred_check "PE: output found $FWD,$REV" 1 0
fi
shred_check "PE: 10 sequences" 10 "$("$BINDIR"/seqfu count "$FWD" | cut -f 2)"
shred_check "PE: Total length 500bp" 500 "$("$BINDIR"/seqfu stats "$FWD" | cut -f 3 | tail -n 1)"
shred_check "PE: R1 payload" "${REF:150:50}" "$(sed -n 6p "$FWD")"
shred_check "PE: R2 payload" "$(shred_rc "${REF:200:50}")" "$(sed -n 6p "$REV")"

### PAIRED END: explicit files, gzip, FASTA
"$BINDIR"/seqfu shred "$INPUT" -f 300 -l 100 -s 200 --fasta --pair-suffix \
    -1 "$TEMPORARY_DIR"/p_1.fa.gz -2 "$TEMPORARY_DIR"/p_2.fa.gz
shred_check "PE -1/-2: R1 gzipped" 0 "$(gzip -t "$TEMPORARY_DIR"/p_1.fa.gz; echo $?)"
shred_check "PE -1/-2: 7 pairs" 7 "$(gzip -dc "$TEMPORARY_DIR"/p_2.fa.gz | "$BINDIR"/seqfu count | cut -f 2)"
shred_check "PE FASTA: R1 trimmed to read length" "${REF:200:100}" "$(gzip -dc "$TEMPORARY_DIR"/p_1.fa.gz | sed -n 4p)"
shred_check "PE FASTA: R2 is revcomp of fragment end" "$(shred_rc "${REF:400:100}")" "$(gzip -dc "$TEMPORARY_DIR"/p_2.fa.gz | sed -n 4p)"
shred_check "PE --pair-suffix: R2 name" ">16S_2/2" "$(gzip -dc "$TEMPORARY_DIR"/p_2.fa.gz | sed -n 3p)"

"$BINDIR"/seqfu shred "$INPUT" -f 300 -l 100 -o "$TEMPORARY_DIR"/gz -z --for-tag _1 --rev-tag _2
shred_check "PE --out-prefix -z: gzipped names" 2 "$(ls "$TEMPORARY_DIR"/gz_1.fq.gz "$TEMPORARY_DIR"/gz_2.fq.gz 2>/dev/null | wc -l | tr -d ' ')"

### Single output file and interleaved
"$BINDIR"/seqfu shred "$INPUT" -l 100 -s 150 -1 "$TEMPORARY_DIR"/single.fq.gz
shred_check "SE -1: same records as STDOUT" "$("$BINDIR"/seqfu shred "$INPUT" -l 100 -s 150 | md5sum)" "$(gzip -dc "$TEMPORARY_DIR"/single.fq.gz | md5sum)"

"$BINDIR"/seqfu shred "$INPUT" -f 100 -l 50 -s 150 -i > "$TEMPFILENAME"
shred_check "Interleaved: 20 records" 20 "$("$BINDIR"/seqfu count "$TEMPFILENAME" | cut -f 2)"
shred_check "Interleaved: R2 follows R1" "$(sed -n 6p "$REV")" "$(sed -n 14p "$TEMPFILENAME")"

### Tiling options
"$BINDIR"/seqfu shred "$INPUT" -l 100 -s 150 --tail --coords > "$TEMPFILENAME"
shred_check "--tail: extra read" 11 "$("$BINDIR"/seqfu count "$TEMPFILENAME" | cut -f 2)"
shred_check "--tail: last read ends at sequence end" "${REF:$((REFLEN-100)):100}" "$(tail -n 3 "$TEMPFILENAME" | head -n 1)"
shred_check "--coords: comment" "@16S_11 16S:$((REFLEN-99))-$REFLEN:+" "$(tail -n 4 "$TEMPFILENAME" | head -n 1)"

"$BINDIR"/seqfu shred "$INPUT" -l 100 -s 100 --circular > "$TEMPFILENAME"
shred_check "--circular: one read per step" $(( (REFLEN + 99) / 100 )) "$("$BINDIR"/seqfu count "$TEMPFILENAME" | cut -f 2)"
LASTSTART=$(( (REFLEN - 1) / 100 * 100 ))
shred_check "--circular: last read wraps" "${REF:$LASTSTART}${REF:0:$((100 - REFLEN + LASTSTART))}" "$(tail -n 3 "$TEMPFILENAME" | head -n 1)"

"$BINDIR"/seqfu shred "$INPUT" -l 150 --amplicon -i --fasta > "$TEMPFILENAME"
shred_check "--amplicon: R1 is sequence start" "${REF:0:150}" "$(sed -n 2p "$TEMPFILENAME")"
shred_check "--amplicon: R2 is revcomp of sequence end" "$(shred_rc "${REF:$((REFLEN-150)):150}")" "$(sed -n 4p "$TEMPFILENAME")"

"$BINDIR"/seqfu shred "$INPUT" -l 100 -s 50 --strand both > "$TEMPFILENAME"
shred_check "--strand both: forward read" "${REF:0:100}" "$(sed -n 2p "$TEMPFILENAME")"
shred_check "--strand both: reverse read" "$(shred_rc "${REF:0:100}")" "$(sed -n 6p "$TEMPFILENAME")"
shred_check "--strand both: twice the reads" \
    $(( 2 * $("$BINDIR"/seqfu shred "$INPUT" -l 100 -s 50 | "$BINDIR"/seqfu count | cut -f 2) )) \
    "$("$BINDIR"/seqfu count "$TEMPFILENAME" | cut -f 2)"

shred_check "--coverage: 10X paired end" "$("$BINDIR"/seqfu shred "$INPUT" -f 300 -s 20 -i | md5sum)" "$("$BINDIR"/seqfu shred "$INPUT" -f 300 -x 10 -i | md5sum)"

printf ">x\n%s%s%s\n" "$(printf 'A%.0s' {1..100})" "$(printf 'N%.0s' {1..100})" "$(printf 'C%.0s' {1..100})" > "$TEMPORARY_DIR"/n.fa
shred_check "--max-n: skip N-rich segments" 4 "$("$BINDIR"/seqfu shred "$TEMPORARY_DIR"/n.fa -l 50 -s 50 --max-n 0.2 | "$BINDIR"/seqfu count | cut -f 2)"

### Variable fragment size
SD1=$("$BINDIR"/seqfu shred "$INPUT" -f 400 --frag-sd 50 -i | md5sum)
shred_check "--frag-sd: reproducible with default seed" "$SD1" "$("$BINDIR"/seqfu shred "$INPUT" -f 400 --frag-sd 50 -i | md5sum)"
SD2=$("$BINDIR"/seqfu shred "$INPUT" -f 400 --frag-sd 50 -i --seed 7 | md5sum)
shred_check "--frag-sd: seed changes output" 1 "$([[ "$SD1" != "$SD2" ]] && echo 1 || echo 0)"
shred_check "--frag-sd 0: systematic" "$("$BINDIR"/seqfu shred "$INPUT" -f 400 -i | md5sum)" "$("$BINDIR"/seqfu shred "$INPUT" -f 400 --frag-sd 0 --seed 7 -i | md5sum)"

### Invalid combinations
for BADARGS in "-2 x.fq" "-o p -1 x.fq" "-i -o p" "-f 50 -l 100 -i" "--strand up" "-r --strand rev"; do
    # shellcheck disable=SC2086
    "$BINDIR"/seqfu shred "$INPUT" $BADARGS > /dev/null 2>&1
    shred_check "Rejects: $BADARGS" 1 "$?"
done

rm -rf "$TEMPORARY_DIR"
