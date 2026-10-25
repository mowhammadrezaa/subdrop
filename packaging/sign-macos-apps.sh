#!/usr/bin/env bash
# Sign app bundles for notarization (--options runtime).
set -euo pipefail
IDENTITY="${APPLE_SIGNING_IDENTITY:?Set APPLE_SIGNING_IDENTITY}"

sign_app() {
  local app="$1"
  echo "Signing $app ..."
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$app"
  codesign --verify --deep --strict "$app"
}

for app in "$@"; do
  sign_app "$app"
done
