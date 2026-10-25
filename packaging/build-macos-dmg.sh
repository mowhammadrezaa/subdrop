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
if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  chmod +x "$ROOT/packaging/sign-macos-apps.sh"
  "$ROOT/packaging/sign-macos-apps.sh" "$STAGE/SubDrop.app"
elif command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$STAGE/SubDrop.app" 2>/dev/null || true
  xattr -cr "$STAGE/SubDrop.app" 2>/dev/null || true
fi
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/packaging/macos-read-first.html" "$STAGE/READ FIRST.html"
cp "$ROOT/packaging/MACOS-INSTALL.txt" "$STAGE/START HERE.txt"
cp "$ROOT/README.md" "$STAGE/README.txt"

hdiutil create \
  -volname "SubDrop" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" && -n "${APPLE_ID:-}" ]]; then
  chmod +x "$ROOT/packaging/notarize-macos.sh"
  "$ROOT/packaging/notarize-macos.sh" "$DMG"
fi

echo "Created: $DMG"
echo "Users: open the DMG, read READ FIRST.html, drag SubDrop.app to Applications."
