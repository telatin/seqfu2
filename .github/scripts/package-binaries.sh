#!/usr/bin/env bash
# Package bin/ into release assets for one platform:
#   dist/seqfu-<platform>                    the main binary alone (stable URL)
#   dist/seqfu-<version>-<platform>.tar.gz   every tool built by `make all`
set -euo pipefail

PLATFORM="${1:?usage: $0 <platform>}"
VERSION=$(grep version seqfu.nimble | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")
NAME="seqfu-${VERSION}-${PLATFORM}"

rm -rf dist
mkdir -p "dist/${NAME}/bin"
cp bin/* "dist/${NAME}/bin/"
cp LICENSE README.md "dist/${NAME}/"
chmod 755 "dist/${NAME}"/bin/*

"dist/${NAME}/bin/seqfu" --version
tar -C dist -czf "dist/${NAME}.tar.gz" "${NAME}"

cp "dist/${NAME}/bin/seqfu" "dist/seqfu-${PLATFORM}"
rm -rf "dist/${NAME}"
ls -l dist
