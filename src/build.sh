#!/bin/bash
set -exuo pipefail
OLDWD=$PWD

PLATFORM=""
if [[ $(uname) == 'Darwin' ]]; 
then
 PLATFORM="_mac"
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


nim --version >/dev/null 2>&1       || { echo "nim compiler not found."; exit 1; }
RELEASE=""
if [ "${NIM_RELEASE+x}" ]; then
 RELEASE=" -d:release ";
fi

nim c -w:on --opt:speed $RELEASE -p:$DIR/lib -o:$DIR/../bin/seqfu${PLATFORM} $DIR/sfu.nim || { echo "Compilation failed."; exit 1; }
nim c -w:on --opt:speed $RELEASE -p:$DIR/lib -o:$DIR/../bin/fu-cov${PLATFORM} src/fu_cov.nim || { echo "fu-cov failed.";   exit 2; }
bash $DIR/../test/mini.sh


VERSION=$(grep return $DIR/seqfu_utils.nim | grep -o \\d\[^\"\]\\+ | head -n 1)


perl -e '
   
  $VERSION=shift(@ARGV);
  $BIN=shift(@ARGV);
  $SPLASH=`$BIN --help 2>&1`;
  $TEMPLATE=shift(@ARGV);
  open(I, "<", $TEMPLATE);
  while (<I>) {
   while ( $_=~/\{\{ (\w+) \}\}/g ) {
      $repl=${$1};
      $match=$1;
      $_=~s/\{\{\s*$match\s*\}\}/$repl/g;
   }
   print;
  }
print "## Some functions\n";
for my $function ('head', 'interleave', 'deinterleave', 'derep', 'stats', 'count') {
  print "### seqfu $function\n\n```\n";
  print `$BIN $function --help`;
  print "````\n"
}

' "$VERSION" "$DIR/bin/seqfu_$(uname)" "$DIR/README.raw" > $DIR/../README.md


