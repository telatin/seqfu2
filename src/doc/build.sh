#!/bin/sh

set -euxo pipefail

if [[ $OSTYPE == "darwin"* ]]; then
  export HOME="/Users/distiller"
fi

mkdir -p $PREFIX/bin

for PACKAGE in argparse;
do
nimble install -y --verbose $PACKAGE
done

nim c --threads:on -p:lib --opt:speed -o:$PREFIX/bin/porfast src/sfu.nim