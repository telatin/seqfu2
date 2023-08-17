#!/usr/bin/env bash
# Automate screeshots with termshot

# Check if termshot is available
if ! command -v termshot &> /dev/null
then
    echo "termshot could not be found"
    echo "Install it with:"
    echo "brew install homeport/tap/termshot"
    exit
fi
echo "termshot found, continuing..."
make
echo "Setting up test environment..."
export PATH=$PWD/bin:$PATH


for PROG in cat count deinterleave derep grep head interleave lanes metadata rc rotate stats tab tail;
do
    
    termshot --show-cmd --filename docs/img/screenshot-${PROG}.png -- seqfu $PROG --help

done
termshot --show-cmd --filename docs/img/screenshot-seqfu.png -- seqfu

