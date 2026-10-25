#!/usr/bin/env bash
# Build SubDrop.app and SubDrop-mac.dmg (run on macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-stage"
DMG="$DIST/SubDrop-mac.dmg"
BACKGROUND="$ROOT/packaging/dmg-background.png"

ensure_create_dmg() {
  if command -v create-dmg >/dev/null 2>&1; then
    CREATE_DMG="$(command -v create-dmg)"
    return
  fi
  if command -v brew >/dev/null 2>&1; then
    brew install create-dmg
    CREATE_DMG="$(command -v create-dmg)"
    return
  fi
  echo "Install create-dmg (brew install create-dmg) to build the DMG." >&2
  exit 1
}

"$ROOT/install.sh"
ensure_create_dmg
python3 "$ROOT/generate_languages.py" "$ROOT/languages.json"

if [[ ! -f "$BACKGROUND" ]]; then
  echo "Missing $BACKGROUND — run: python3 packaging/generate-dmg-background.py" >&2
  exit 1
fi
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$HOME/Applications/SubDrop.app" "$STAGE/"
cp "$ROOT/packaging/MACOS-INSTALL.txt" "$STAGE/SubDrop.app/Contents/Resources/INSTALL.txt"

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  chmod +x "$ROOT/packaging/sign-macos-apps.sh"
  "$ROOT/packaging/sign-macos-apps.sh" "$STAGE/SubDrop.app"
elif command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$STAGE/SubDrop.app" 2>/dev/null || true
  xattr -cr "$STAGE/SubDrop.app" 2>/dev/null || true
fi

VOLICON=()
if [[ -f "$ROOT/AppIcon.icns" ]]; then
  VOLICON=(--volicon "$ROOT/AppIcon.icns")
fi

"$CREATE_DMG" \
  --volname "SubDrop" \
  "${VOLICON[@]}" \
  --background "$BACKGROUND" \
  --window-pos 120 100 \
  --window-size 660 400 \
  --icon-size 128 \
  --text-size 12 \
  --icon "SubDrop.app" 168 178 \
  --hide-extension "SubDrop.app" \
  --app-drop-link 492 178 \
  "$DMG" \
  "$STAGE"

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" && -n "${APPLE_ID:-}" ]]; then
  chmod +x "$ROOT/packaging/notarize-macos.sh"
  "$ROOT/packaging/notarize-macos.sh" "$DMG"
fi

echo "Created: $DMG"
echo "Users: drag SubDrop to Applications (arrow on background)."
