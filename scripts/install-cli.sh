#!/usr/bin/env bash
# Installs the standalone litmus-cli binary onto the user's PATH.
#
# The MCP server already self-installs a private copy into
# ~/.cache/litmus-mcp-server/bin/ for its own litmus_sdk_* tools, but that copy
# is deliberately not on PATH. This script is for the other use: running
# litmus-cli directly in a shell, which is how the litmus-cli skill drives bulk
# and multi-edge work.
#
# Usage:
#   ./scripts/install-cli.sh [--check] [--version cli-vX.Y.Z] [--dir PATH]
#
#   --check    report the installed and latest versions, install nothing
#   --version  install a specific release tag (default: latest)
#   --dir      install directory (default: ~/.local/bin)
#
# Upstream also publishes a one-liner installer:
#   curl -fsSL https://raw.githubusercontent.com/litmusautomation/\
# litmus-sdk-releases/main/install.sh | sh
# This script does the same job without piping a remote script into a shell, and
# verifies the download against the release's SHA256SUMS either way.
#
# Note: once litmus-cli is installed, it can update itself with
# `litmus-cli update`, so this script is really only needed for the first
# install.

set -euo pipefail

REPO="litmusautomation/litmus-sdk-releases"
RELEASES_API="https://api.github.com/repos/$REPO/releases?per_page=30"
DOWNLOAD_BASE="https://github.com/$REPO/releases/download"

CHECK_ONLY=false
WANT_VERSION=""
INSTALL_DIR="${LITMUS_CLI_INSTALL_DIR:-$HOME/.local/bin}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=true; shift ;;
    --version) WANT_VERSION="${2:?--version needs a tag like cli-v0.9.2}"; shift 2 ;;
    --dir) INSTALL_DIR="${2:?--dir needs a path}"; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Required tool not found: $1" >&2; exit 1; }; }
need curl

# Resolve the asset name for this machine, matching the release naming scheme.
case "$(uname -s)" in
  Darwin) OS=darwin ;;
  Linux)  OS=linux ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=amd64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
SUFFIX=""
[[ "$OS" == "windows" ]] && SUFFIX=".exe"
ASSET="litmus-cli-${OS}-${ARCH}${SUFFIX}"
BINARY_NAME="litmus-cli${SUFFIX}"

installed_version() {
  if command -v litmus-cli >/dev/null 2>&1; then
    litmus-cli --version 2>/dev/null | head -1 | tr -d '\r'
  else
    echo "not installed"
  fi
}

latest_tag() {
  # Newest cli-v* tag by version sort. No jq dependency: the releases payload is
  # matched with grep so this works on a bare machine.
  curl -fsSL "$RELEASES_API" \
    | grep -o '"tag_name": *"cli-v[^"]*"' \
    | sed 's/.*"cli-v/cli-v/;s/"$//' \
    | sort -t. -k1,1V -k2,2n -k3,3n \
    | tail -1
}

echo "Installed: $(installed_version)"
if command -v litmus-cli >/dev/null 2>&1; then
  echo "Location:  $(command -v litmus-cli)"
fi

TAG="$WANT_VERSION"
if [[ -z "$TAG" ]]; then
  TAG="$(latest_tag || true)"
  if [[ -z "$TAG" ]]; then
    echo "Could not determine the latest release from GitHub." >&2
    echo "Check network access, or pass --version cli-vX.Y.Z explicitly." >&2
    exit 1
  fi
fi
echo "Latest:    $TAG"

if [[ "$CHECK_ONLY" == true ]]; then
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $ASSET from $TAG ..."
curl -fsSL -o "$TMP/$ASSET" "$DOWNLOAD_BASE/$TAG/$ASSET"
curl -fsSL -o "$TMP/SHA256SUMS" "$DOWNLOAD_BASE/$TAG/SHA256SUMS"

# Verify before installing. A corrupted or substituted binary here would run
# with the user's Edge credentials, so this check is not optional.
EXPECTED="$(awk -v a="$ASSET" '{ n=$NF; sub(/^\*/,"",n); if (n==a) print $1 }' "$TMP/SHA256SUMS" | head -1)"
if [[ -z "$EXPECTED" ]]; then
  echo "No SHA256SUMS entry for $ASSET in release $TAG. Refusing to install." >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$TMP/$ASSET" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')"
else
  echo "Neither sha256sum nor shasum found; cannot verify the download." >&2
  exit 1
fi

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "Checksum mismatch for $ASSET. Refusing to install." >&2
  echo "  expected $EXPECTED" >&2
  echo "  actual   $ACTUAL" >&2
  exit 1
fi
echo "Checksum verified."

mkdir -p "$INSTALL_DIR"
chmod +x "$TMP/$ASSET"
mv "$TMP/$ASSET" "$INSTALL_DIR/$BINARY_NAME"
echo "Installed $TAG to $INSTALL_DIR/$BINARY_NAME"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo
    echo "NOTE: $INSTALL_DIR is not on your PATH. Add it:"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    ;;
esac

echo
echo "Next: authenticate, then verify."
echo "  litmus-cli login        # browser sign-in, saves a profile"
echo "  litmus-cli le version   # confirm the device connection"
