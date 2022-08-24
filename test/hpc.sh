#!/bin/bash
set -exuo pipefail
VERSION=$(grep version seqfu.nimble  | grep -oP \\d\+\.\\d\+\.\\d\+)
make
mkdir -p /nbi/software/testing/seqfu/${VERSION}/x86_64/bin/
mv -v bin/* /nbi/software/testing/seqfu/${VERSION}/x86_64/bin/
echo '#!/bin/bash'         > $BINSCRIPT
echo "VERSION=${VERSION}" >> $BINSCRIPT
echo 'export PATH="/nbi/software/testing/seqfu/${VERSION}/x86_64/bin/:$PATH"' >> $BINSCRIPT

