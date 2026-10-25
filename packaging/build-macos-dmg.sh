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
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/README.md" "$STAGE/README.txt"

hdiutil create \
  -volname "SubDrop" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Created: $DMG"
echo "Users: open the DMG, drag SubDrop.app to Applications."
