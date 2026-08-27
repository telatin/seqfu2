NIMCACHE="${NIMCACHE:-${TMPDIR:-/tmp}/seqfu_test_speed_nimcache}"
mkdir -p "$NIMCACHE"

nim c --nimcache:"$NIMCACHE/imported" speed/imported.nim
nim c --nimcache:"$NIMCACHE/native" -p:../src/lib speed/native.nim
