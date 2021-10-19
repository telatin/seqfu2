#!/bin/bash

set -euxo pipefail
export CHOOSENIM_CHOOSE_VERSION=1.2.10
# wget -qO - https://nim-lang.org/choosenim/init.sh | sh
curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
sh init.sh -y
rm init.sh

export PATH=/home/travis/.nimble/bin:"$HOME"/.nimble/bin:"$PATH"
nimble refresh
nimble build -y  --verbose
bash test/mini.sh
