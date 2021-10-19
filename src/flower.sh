#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
for FILE in "$SCRIPT_DIR"/bin/*;
do
  if [[ -e "$FILE" ]]; then
    mv "$FILE" "${FILE/fu/flower}"
  fi
done
