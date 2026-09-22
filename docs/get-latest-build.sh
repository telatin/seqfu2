#!/usr/bin/env bash
# get-latest-build.sh — download artifacts from the latest "Build binaries (manual)" run
set -euo pipefail

WORKFLOW="build-binaries.yml"
REPO="${GH_REPO:-telatin/seqfu2}"
OUTDIR="./action-binaries"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Download all artifacts from the latest run of the on-demand build workflow.

Options:
  -o, --outdir DIR   Output directory (default: ./action-binaries)
  -r, --repo REPO    GitHub repository (default: $REPO)
  -h, --help         Show this help

Requirements: gh CLI authenticated (gh auth login)
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--outdir) OUTDIR="$2"; shift 2 ;;
    -r|--repo)   REPO="$2";   shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

command -v gh &>/dev/null || die "gh CLI not found. Install from https://cli.github.com/"
gh auth status &>/dev/null || die "Not authenticated. Run: gh auth login"

echo "Fetching latest run of workflow '$WORKFLOW' in $REPO..."

RUN_ID=$(gh run list \
  --repo "$REPO" \
  --workflow "$WORKFLOW" \
  --limit 1 \
  --json databaseId,status,conclusion,createdAt \
  --jq '.[0] | "\(.databaseId) \(.status) \(.conclusion) \(.createdAt)"')

[[ -n "$RUN_ID" ]] || die "No runs found for workflow '$WORKFLOW'"

read -r ID STATUS CONCLUSION CREATED_AT <<< "$RUN_ID"

echo "  Run ID    : $ID"
echo "  Created   : $CREATED_AT"
echo "  Status    : $STATUS"
echo "  Conclusion: $CONCLUSION"

if [[ "$STATUS" != "completed" ]]; then
  die "Run $ID is not completed yet (status: $STATUS). Try again later."
fi

if [[ "$CONCLUSION" != "success" ]]; then
  echo "WARNING: run $ID finished with conclusion '$CONCLUSION'. Proceeding anyway." >&2
fi

mkdir -p "$OUTDIR"

echo "Downloading artifacts into '$OUTDIR'..."
gh run download "$ID" \
  --repo "$REPO" \
  --dir "$OUTDIR"

echo ""
echo "Done. Files in '$OUTDIR':"
find "$OUTDIR" -type f | sort | sed "s|^$OUTDIR/||"
