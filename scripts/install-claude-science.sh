#!/usr/bin/env bash
set -euo pipefail

# install-claude-science.sh — download Claude Science binary from the unblocked
# downloads.claude.ai CDN (bypasses the geo-blocked claude.ai install script),
# verify SHA256 against the manifest, and install to ~/.local/bin.
#
# Usage: bash install-claude-science.sh
# Override arch with: CS_ARCH=linux-x64 bash install-claude-science.sh

CDN="https://downloads.claude.ai/claude-science/latest"
CS_ARCH="${CS_ARCH:-linux-x64}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BIN="$INSTALL_DIR/claude-science"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Fetching manifest..."
curl -fsSL "$CDN/manifest.json" -o "$TMP/manifest.json"
VERSION="$(python3 -c "import json;print(json.load(open('$TMP/manifest.json'))['version'])")"
EXPECTED_SHA="$(python3 -c "import json;print(json.load(open('$TMP/manifest.json'))['sha256']['$CS_ARCH'])")"
echo "    version: $VERSION"
echo "    expected sha256: $EXPECTED_SHA"

mkdir -p "$INSTALL_DIR"
echo "==> Downloading $CS_ARCH binary (~150MB)..."
curl -fSL "$CDN/$CS_ARCH" -o "$BIN"
chmod +x "$BIN"

echo "==> Verifying SHA256..."
ACTUAL_SHA="$(sha256sum "$BIN" | awk '{print $1}')"
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "ERROR: checksum mismatch!"
  echo "  expected: $EXPECTED_SHA"
  echo "  actual:   $ACTUAL_SHA"
  rm -f "$BIN"
  exit 1
fi
echo "    checksum OK"

# Ensure ~/.local/bin is on PATH
grep -q '.local/bin' "$HOME/.profile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"

echo "==> Installed: $BIN"
echo "    $("$BIN" --version)"
echo
echo "Next: ensure ~/.local/bin is on PATH (source ~/.profile), then proceed to Step 2 of the skill."
