#!/bin/bash
set -euxo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ldd $SCRIPT_DIR/../bin/seqfu
echo $SHELL
whoami
file $SCRIPT_DIR/../bin/seqfu
ls /etc
apk
apt
yum
