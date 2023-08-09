FILE=$1
if [[ ! -e $FILE ]];then
  echo exiting..
  exit 1
fi

if [[ ! -d src/ ]]; then
  echo src should be where the script is invoked
  exit 1
fi
set -euxo pipefail
DIR=$(dirname $FILE)
cp -r /Users/telatina/.choosenim/toolchains/nim-1.6.6/lib $DIR/
cp -r /Users/telatina/.nimble/pkgs $DIR/
cp -r ./src $DIR/
sed "s'/Users/telatina/.choosenim/toolchains/nim-1.6.6/'./'g" $FILE | sed "s'/Users/telatina/git/seqfu2/'./'g" > $DIR/compile.sh
sed -i.bak 's|/Users/telatina/.nimble/pkgs/|./pkgs/|g' $DIR/*.c

