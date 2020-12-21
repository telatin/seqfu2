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

nim c  --hints:off -w:on --opt:speed $RELEASE -p:$DIR/lib -o:$DIR/../bin/seqfu${PLATFORM} $DIR/sfu.nim  \
  || { echo "Compilation failed."; exit 1; }
nim c --hints:off  -w:on --opt:speed $RELEASE -p:$DIR/lib -o:$DIR/../bin/fu-cov${PLATFORM} src/fu_cov.nim \
  || { echo "fu-cov failed.";   exit 2; }

if [ -e "$DIR/../test/mini.sh" ]; then
  bash $DIR/../test/mini.sh
else
  echo "Minimal test suite not found at: $DIR/../test/mini.sh"
  exit 1;
fi

VERSION=$(grep return $DIR/seqfu_utils.nim | grep -o \\d\[^\"\]\\+ | head -n 1)
sed -i "s/version\s\+=\s\+\".\+\"/version = \"$VERSION\"/" $DIR/../seqfu.nimble

perl -e '
$VERSION=shift(@ARGV);
$BIN=shift(@ARGV);
$SPLASH=`$BIN --help 2>&1`;
$TEMPLATE=shift(@ARGV);

print STDERR "bin:$BIN;version:$VERSION\n";
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
for my $function ("head", "interleave", "deinterleave", "derep", "stats", "count") {
  print "\n### :closed_book: seqfu $function\n\n";
  print "```\n";
  print `$BIN $function --help`;
  print "```\n"
}

' "$VERSION" "$DIR/../bin/seqfu${PLATFORM}" "$DIR/README.raw" > $DIR/../README.md
