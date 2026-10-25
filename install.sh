#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/SubDrop.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

swiftc -O -parse-as-library "$ROOT/SubDropApp.swift" \
  -o "$MACOS/SubDrop" \
  -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers

cp "$ROOT/fetch.sh" "$RES/fetch.sh"
chmod +x "$RES/fetch.sh"
python3 "$ROOT/generate_languages.py" "$RES/languages.json" \
  || cp "$ROOT/languages.json" "$RES/languages.json"

if [[ -f "$ROOT/AppIcon.icns" ]]; then
  cp "$ROOT/AppIcon.icns" "$RES/AppIcon.icns"
elif [[ -f "$ROOT/AppIcon-1024.png" ]]; then
  "$ROOT/build_icon.sh" "$ROOT/AppIcon-1024.png" "$RES/AppIcon.icns"
else
  echo "Warning: no AppIcon.icns — run build_icon.sh after adding AppIcon-1024.png" >&2
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>SubDrop</string>
	<key>CFBundleIdentifier</key>
	<string>local.subdrop.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>SubDrop</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.2</string>
	<key>CFBundleVersion</key>
	<string>1.2</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Video</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.movie</string>
				<string>public.video</string>
				<string>public.mpeg-4</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

# Ad-hoc sign so the binary is a valid macOS app bundle (not a Developer ID release).
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
fi

echo "Installed: $APP"
echo "Open it from Applications — the window stays open for drag-and-drop."
