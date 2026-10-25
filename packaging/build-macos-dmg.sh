#!/usr/bin/env bash
# Build SubDrop.app and SubDrop-mac.dmg (run on macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-stage"
DMG="$DIST/SubDrop-mac.dmg"

"$ROOT/install.sh"
python3 "$ROOT/generate_languages.py" "$ROOT/languages.json"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$HOME/Applications/SubDrop.app" "$STAGE/"
osacompile -o "$STAGE/Install SubDrop.app" "$ROOT/packaging/macos-install.applescript"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$STAGE/SubDrop.app" 2>/dev/null || true
  codesign --force --deep --sign - "$STAGE/Install SubDrop.app" 2>/dev/null || true
  xattr -cr "$STAGE/SubDrop.app" 2>/dev/null || true
  xattr -cr "$STAGE/Install SubDrop.app" 2>/dev/null || true
fi
cp "$ROOT/packaging/MACOS-INSTALL.txt" "$STAGE/START HERE.txt"
cp "$ROOT/README.md" "$STAGE/README.txt"

hdiutil create \
  -volname "SubDrop" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Created: $DMG"
echo "Users: open the DMG, double-click Install SubDrop.app"
