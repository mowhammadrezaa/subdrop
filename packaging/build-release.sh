#!/usr/bin/env bash
# Build macOS DMG from this machine; stage Windows/Linux artifacts for distribution.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
mkdir -p "$DIST"

"$ROOT/packaging/build-macos-dmg.sh"

# Source bundle for Windows builders and Linux install
ARCHIVE="$DIST/subdrop-src.tar.gz"
tar -czf "$ARCHIVE" \
  --exclude dist \
  --exclude '.git' \
  -C "$ROOT" \
  README.md requirements.txt subdrop_gui.py subdrop_cli.py generate_languages.py \
  subdrop packaging install.sh fetch.sh

cp "$ROOT/packaging/install-linux.sh" "$DIST/install-linux.sh"
chmod +x "$DIST/install-linux.sh"

echo ""
echo "Release artifacts in $DIST:"
ls -la "$DIST"
