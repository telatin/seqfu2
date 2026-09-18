#!/bin/sh
set -eu

repo="${SEQFU_REPO:-telatin/seqfu2}"
version="${SEQFU_VERSION:-latest}"
install_dir="${SEQFU_INSTALL_DIR:-${HOME:-.}/.local/bin}"
binary_name="${SEQFU_BINARY_NAME:-seqfu}"
asset="${SEQFU_ASSET:-}"

usage() {
  cat <<'EOF'
Install the latest SeqFu binary from GitHub releases.

Usage:
  install-seqfu.sh [options]

Options:
  -d, --dir DIR        Installation directory [default: $HOME/.local/bin]
  -n, --name NAME      Installed binary name [default: seqfu]
  -v, --version TAG    Release tag or version, for example v1.29.0 or 1.29.0
  -a, --asset NAME     Release asset name to download
  -h, --help           Show this help

Environment:
  SEQFU_INSTALL_DIR, SEQFU_BINARY_NAME, SEQFU_VERSION, SEQFU_ASSET,
  SEQFU_REPO
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

say() {
  printf '%s\n' "$*" >&2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

fetch_stdout() {
  url=$1
  if have curl; then
    curl -fsSL "$url"
  elif have wget; then
    wget -qO- "$url"
  else
    die "curl or wget is required"
  fi
}

download_file() {
  url=$1
  out=$2
  if have curl; then
    curl -fL --retry 3 --connect-timeout 15 -o "$out" "$url"
  elif have wget; then
    wget -O "$out" "$url"
  else
    die "curl or wget is required"
  fi
}

lowercase() {
  printf '%s\n' "$1" | tr 'A-Z' 'a-z'
}

checksum_file() {
  algo=$1
  file=$2

  case "$algo" in
    sha256)
      if have sha256sum; then
        sha256sum "$file" | awk '{print $1}' | tr 'A-F' 'a-f'
      elif have shasum; then
        shasum -a 256 "$file" | awk '{print $1}' | tr 'A-F' 'a-f'
      elif have openssl; then
        openssl dgst -sha256 "$file" | awk '{print $NF}' | tr 'A-F' 'a-f'
      else
        die "no SHA-256 tool found; install sha256sum, shasum, or openssl"
      fi
      ;;
    *)
      die "unsupported checksum algorithm: $algo"
      ;;
  esac
}

detect_asset() {
  os=${SEQFU_OS:-$(uname -s)}
  arch=${SEQFU_ARCH:-$(uname -m)}

  case "$os" in
    Linux) os_part=linux ;;
    Darwin) os_part=macos ;;
    *) die "unsupported operating system: $os" ;;
  esac

  case "$arch" in
    x86_64|amd64) arch_part=x86_64 ;;
    aarch64)
      if [ "$os_part" = "macos" ]; then
        arch_part=arm64
      else
        arch_part=aarch64
      fi
      ;;
    arm64)
      if [ "$os_part" = "linux" ]; then
        arch_part=aarch64
      else
        arch_part=arm64
      fi
      ;;
    *) die "unsupported CPU architecture: $arch" ;;
  esac

  printf 'seqfu-%s-%s\n' "$os_part" "$arch_part"
}

release_json_for_tag() {
  tag=$1
  if [ "$tag" = "latest" ]; then
    fetch_stdout "https://api.github.com/repos/$repo/releases/latest"
  else
    fetch_stdout "https://api.github.com/repos/$repo/releases/tags/$tag"
  fi
}

extract_tag_name() {
  sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

extract_asset_digest() {
  wanted=$1
  awk -v wanted="$wanted" '
    /"name"[[:space:]]*:/ {
      name = $0
      sub(/^.*"name"[[:space:]]*:[[:space:]]*"/, "", name)
      sub(/".*$/, "", name)
    }
    name == wanted && /"digest"[[:space:]]*:/ {
      digest = $0
      sub(/^.*"digest"[[:space:]]*:[[:space:]]*"/, "", digest)
      sub(/".*$/, "", digest)
      print digest
      exit
    }
  '
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--dir)
      [ "$#" -gt 1 ] || die "$1 requires a directory"
      install_dir=$2
      shift 2
      ;;
    -n|--name)
      [ "$#" -gt 1 ] || die "$1 requires a binary name"
      binary_name=$2
      shift 2
      ;;
    -v|--version)
      [ "$#" -gt 1 ] || die "$1 requires a tag or version"
      version=$2
      shift 2
      ;;
    -a|--asset)
      [ "$#" -gt 1 ] || die "$1 requires an asset name"
      asset=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$version" in
  latest) requested_tag=latest ;;
  v*) requested_tag=$version ;;
  *) requested_tag="v$version" ;;
esac

[ -n "$asset" ] || asset=$(detect_asset)

say "Detecting SeqFu release..."
release_json=$(release_json_for_tag "$requested_tag") || die "could not read GitHub release metadata"
tag=$(printf '%s\n' "$release_json" | extract_tag_name)
[ -n "$tag" ] || die "could not determine release tag"

digest=$(printf '%s\n' "$release_json" | extract_asset_digest "$asset" || true)
base_url="https://github.com/$repo/releases/download/$tag"
bin_url="$base_url/$asset"

case "$digest" in
  sha256:*)
    expected_sha256=$(lowercase "${digest#sha256:}")
    ;;
  "")
    die "could not find GitHub SHA-256 digest for release asset: $asset"
    ;;
  *)
    die "unsupported GitHub digest for $asset: $digest"
    ;;
esac

tmp_parent=${TMPDIR:-/tmp}
tmp_dir=$(mktemp -d "$tmp_parent/seqfu-install.XXXXXX" 2>/dev/null || mktemp -d -t seqfu-install)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

tmp_bin="$tmp_dir/$asset"

say "Downloading $asset from $tag..."
download_file "$bin_url" "$tmp_bin" || die "download failed: $bin_url"

actual_sha256=$(checksum_file sha256 "$tmp_bin")
[ "$actual_sha256" = "$expected_sha256" ] || die "SHA-256 mismatch for $asset: expected $expected_sha256, got $actual_sha256"
say "Verified GitHub asset SHA-256: $actual_sha256"

mkdir -p "$install_dir" || die "could not create install directory: $install_dir"
chmod 755 "$tmp_bin"
dest="$install_dir/$binary_name"
mv "$tmp_bin" "$dest" || die "could not install to $dest"
chmod 755 "$dest"

say "Installed $dest"
if "$dest" --version >/dev/null 2>&1; then
  "$dest" --version
elif "$dest" version >/dev/null 2>&1; then
  "$dest" version
fi
