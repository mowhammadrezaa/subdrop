#!/usr/bin/env bash
# Notarize dist/SubDrop-mac.dmg when Apple credentials are set (GitHub Actions secrets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:-$ROOT/dist/SubDrop-mac.dmg}"

: "${APPLE_SIGNING_IDENTITY:?Set APPLE_SIGNING_IDENTITY (Developer ID Application: …)}"
: "${APPLE_ID:?Set APPLE_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"

if [[ ! -f "$DMG" ]]; then
  echo "Missing DMG: $DMG" >&2
  exit 1
fi

echo "Notarizing $DMG ..."
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

xcrun stapler staple "$DMG"
echo "Notarization complete: $DMG"
