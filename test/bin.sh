#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Building fresh binary"
echo "============================="

VER=$(curl -s https://api.github.com/repos/telatin/seqfu2/releases/latest  | perl -nE '
my ($tag, $val) = split /:/, $_;
if ($tag=~/tag_name/) { 
  my @tag = split /"/, $val; 
  for my $i (@tag) { 
    $i =~s/[^0-9.]//g; 
    say $i if (length($i) > 2); 
  }
}')

 
if [[ $(uname) == "Darwin" ]]; then
  PLAT='Darwin';
else
  PLAT='Linux-x86_64'
fi

DEST="$SCRIPT_DIR/../releases/zips/";
mkdir -p $DEST

echo "Last version online: $VER"
echo "Local version: $LOCALVER"
nimble build
LOCAL_RELEASE=$(./bin/seqfu version)
zip -r $DEST/SeqFu-v${LOCAL_RELEASE}-${PLAT}.zip bin/*

echo "Last version online: $VER"
echo "Local version: $LOCAL_RELEASE"
echo "$DEST/SeqFu-v${LOCAL_RELEASE}-${PLAT}.zip"