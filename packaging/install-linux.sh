#!/usr/bin/env bash
# SubDrop installer for Linux — GUI + CLI wrapper.
# Usage: curl -fsSL .../install-linux.sh | bash
#    or: ./packaging/install-linux.sh
set -euo pipefail

INSTALL_DIR="${SUBDROP_INSTALL_DIR:-$HOME/.local/share/subdrop}"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> SubDrop Linux installer"
echo "    Install dir: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

if [[ -f "$SCRIPT_DIR/subdrop_gui.py" ]]; then
  mkdir -p "$INSTALL_DIR/subdrop"
  cp -R "$SCRIPT_DIR/subdrop/." "$INSTALL_DIR/subdrop/"
  cp "$SCRIPT_DIR/subdrop_gui.py" "$SCRIPT_DIR/subdrop_cli.py" \
    "$SCRIPT_DIR/requirements.txt" "$SCRIPT_DIR/generate_languages.py" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true
else
  echo "Run this script from the SubDrop source tree." >&2
  exit 1
fi

PYTHON="${SUBDROP_PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "python3 not found. Install Python 3.10+." >&2
  exit 1
fi

"$PYTHON" -m pip install --user --upgrade pip
"$PYTHON" -m pip install --user -r "$INSTALL_DIR/requirements.txt"

"$PYTHON" "$INSTALL_DIR/generate_languages.py" "$INSTALL_DIR/languages.json"

cat > "$BIN_DIR/subdrop" <<EOF
#!/usr/bin/env bash
export SUBDROP_LANG="\${SUBDROP_LANG:-}"
exec "$PYTHON" "$INSTALL_DIR/subdrop_gui.py" "\$@"
EOF
chmod +x "$BIN_DIR/subdrop"

cat > "$BIN_DIR/subdrop-cli" <<EOF
#!/usr/bin/env bash
exec "$PYTHON" "$INSTALL_DIR/subdrop_cli.py" "\$@"
EOF
chmod +x "$BIN_DIR/subdrop-cli"

cat > "$DESKTOP_DIR/subdrop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=SubDrop
Comment=Download subtitles for video files
Exec=$BIN_DIR/subdrop
Icon=video-subtitles
Terminal=false
Categories=AudioVideo;Video;
EOF

echo ""
echo "Installed."
echo "  GUI:  subdrop   (ensure $BIN_DIR is on your PATH)"
echo "  CLI:  subdrop-cli /path/to/video.mkv"
echo "  Config: ~/.config/subdrop/config"
echo ""
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Add to your shell profile:  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
