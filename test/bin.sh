#!/bin/bash
VER=$(curl -s https://api.github.com/repos/telatin/seqfu2/releases/latest  | perl -nE 'my ($tag, $val) = split /:/, $_; if ($tag=~/tag_name/) { my @tag = split /"/, $val; for my $i (@tag) { $i =~s/[^0-9.]//g; say $i if (length($i) > 2); } }')

if [[ $(uname) == "Darwin" ]]; then
  PLAT='macos-intel';
else
  PLAT='linux64'
fi

if [[ -d "$HOME/Downloads" ]];
then
  DEST="$HOME/Downloads";
else
  DEST="./release"
fi

mkdir -p $DEST
nimble build && zip -r $DEST/seqfu-${VER}-${PLAT}.zip bin/*

