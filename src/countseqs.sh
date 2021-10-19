#!/bin/bash

CAT="cat"
# Check if the first parameter was passed
if [ -z "$1" ]; then
    echo "Usage: countseqs.sh <fasta file>"
    exit 1
fi

# Check if the file exists
if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

# Check if the filename ends with .gz
if [[ "$1" == *.gz ]]; then
    #GZIPPED=1
    GUNZIP_PIPE="gzip -d "
else
    #GZIPPED=0
    GUNZIP_PIPE="$CAT"
fi

# Get the first character of the file
FIRST_CHAR=$($CAT "$1" | $GUNZIP_PIPE | head -c 1)

if [[ "$FIRST_CHAR" == ">" ]]; then
  COUNT=$($CAT "$1" | $GUNZIP_PIPE | grep -c "^>")
elif [[ "$FIRST_CHAR" == "@" ]]; then
  COUNT=$($CAT "$1" | $GUNZIP_PIPE | wc -l)
  COUNT=$((COUNT / 4))
fi

echo $COUNT
