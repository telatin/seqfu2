#!/bin/bash
set -euxo pipefail
gh() {
    # Check if `gh` command is available
    if ! command -v gh > /dev/null; then
        echo "The CLI utility 'gh' was not found"
        return 0
    else
        echo "OK: CLI utility 'gh' found"
	return 1
    fi
}

 
getversion() {
  new_tag="v$(grep version "$DIR"/../seqfu.nimble | cut -f 2 -d \")"
  # check if gh()
  if gh; then
    new_tag=$(gh release list -L 1 | grep -o "v\d\+\.\d\+\.\d\+")
  else
    echo "Could not get remote release""
  fi
}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BINDIR="$DIR"/../bin/
DESTDIR="$DIR"/../releases/zips/

programName="SeqFu"
os_tag="$(uname -s)-$(uname -m)"
new_tag="unknown"
getversion

mkdir -p "$DESTDIR"
ZIP="$DESTDIR"/${programName}-${new_tag}-${os_tag}.zip
zip -j "$ZIP" "$BINDIR"/*

gh release upload ${new_tag} "$ZIP"
