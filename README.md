# SubDrop

**SubDrop** downloads subtitle files for your videos with drag-and-drop. It saves a UTF-8 `.srt` next to each video, using the same base name as the file (for example `Movie.mkv` → `Movie.srt`).

| Platform | Experience |
|----------|------------|
| **macOS** | Native SwiftUI app (`SubDrop.app`) |
| **Windows** | `SubDrop-Setup.exe` installer (Start menu + optional desktop shortcut) or portable `SubDrop.exe` |
| **Linux** | `install-linux.sh` → `subdrop` GUI + `subdrop-cli` |

Inspired by “drop zone” utilities: open the app, drop one or many videos (or a folder), pick a language, and subtitles are fetched automatically.

---

## Features

- **Drag and drop** — multiple video files or folders (scans up to 3 levels deep).
- **Language picker** — searchable list of OpenSubtitles-supported languages (67 entries in `languages.json`).
- **Morphing banner** — compact bar when choosing a language; full-height banner when the list is closed.
- **Fixed drop zone** — the bottom drop area stays the same size; the language list uses space above it.
- **UTF-8** — subtitles are normalized to UTF-8 (BOM removed when present).
- **Hash-based matching** — downloads are matched to your exact file release when possible (via [Subliminal](https://github.com/Diaoul/subliminal) + OpenSubtitles providers).
- **Persistence** — last chosen language is stored in UserDefaults and `~/.config/subdrop/config`.

---

## Ready-to-install releases

Pre-built artifacts are published on **[GitHub Releases](https://github.com/mowhammadrezaa/subdrop/releases)** when you push a tag like `v1.0.0` (see `.github/workflows/release.yml`). Locally, run `packaging/build-release.sh` on a Mac to build `dist/` yourself.

| File | Platform | Install |
|------|----------|---------|
| **`SubDrop-mac.dmg`** | macOS | Open DMG → drag **SubDrop.app** to **Applications** → open (right-click → Open first time if blocked). |
| **`SubDrop-Setup.exe`** | Windows | **Recommended.** Run the installer → **SubDrop** in the Start menu; optional desktop shortcut on the last step. |
| **`SubDrop.exe`** | Windows | Portable build (no installer). Build on Windows with `packaging\build-windows.ps1` (see **`WINDOWS-README.txt`**). |
| **`install-linux.sh`** | Linux | `chmod +x install-linux.sh && ./install-linux.sh` — installs to `~/.local/share/subdrop`, commands `subdrop` and `subdrop-cli`. |
| **`subdrop-src.tar.gz`** | All | Full source for developers and for building the Windows `.exe`. |

### macOS DMG (end users)

```bash
open dist/SubDrop-mac.dmg
```

Drag **SubDrop.app** to **Applications**.

If macOS says the app is **“damaged”** (common for unsigned downloads), remove the quarantine flag — the app is not corrupted:

```bash
xattr -cr ~/Applications/SubDrop.app
# or: xattr -cr /Applications/SubDrop.app
```

Then open SubDrop again (or right-click → **Open** the first time). The DMG includes **If macOS says damaged, read this.txt** with the same steps.

Requires **Subliminal** installed (`pip3 install subliminal`).

### Windows installer (end users)

1. Download **`SubDrop-Setup.exe`** from [Releases](https://github.com/mowhammadrezaa/subdrop/releases).
2. Run the wizard (installs under `%LocalAppData%\Programs\SubDrop` by default).
3. Open **SubDrop** from the Start menu. On the final screen you can enable **Create a desktop icon** and launch the app.

### Windows build (developers)

On **Windows 10/11** with Python 3.10+ and [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```powershell
tar -xf subdrop-src.tar.gz   # or clone/copy source
cd subdrop   # project root
.\packaging\build-windows.ps1
```

Output: **`dist\SubDrop-Setup.exe`** (installer) and **`dist\SubDrop.exe`** (portable). Users need internet for OpenSubtitles.

### Linux (install script)

```bash
chmod +x install-linux.sh
./install-linux.sh
# ensure ~/.local/bin is on PATH
subdrop
```

Or from source tree: `./packaging/install-linux.sh`

---

## Requirements

| Requirement | Notes |
|-------------|--------|
| **macOS 13+** | Ventura or later for the Swift app (`LSMinimumSystemVersion`). |
| **Windows 10+** | For `SubDrop.exe` (Python embedded via PyInstaller). |
| **Linux** | Python 3.10+, tkinter (usually included with Python). |
| **Xcode Command Line Tools** | For `swiftc` when running `install.sh`. |
| **Python 3** | Used by `fetch.sh`, `generate_languages.py`, and Subliminal. |
| **Subliminal** | Subtitle download engine. Install once (see below). |
| **Network** | Access to OpenSubtitles APIs via Subliminal providers. |

### Install Subliminal (one-time)

```bash
pip3 install subliminal --break-system-packages
```

On Apple Silicon, the binary is usually at `/opt/homebrew/bin/subliminal`. SubDrop’s `fetch.sh` prepends Homebrew to `PATH` so Finder-launched apps can find it (GUI apps do not inherit your shell `PATH`).

---

## Installation

Source and scripts live in:

```text
~/.local/share/subdrop/
```

Build and install the app to:

```text
~/Applications/SubDrop.app
```

Run:

```bash
~/.local/share/subdrop/install.sh
```

This will:

1. Compile `SubDropApp.swift` with `swiftc`.
2. Copy `fetch.sh` into the app bundle `Contents/Resources/`.
3. Generate `languages.json` via `generate_languages.py`.
4. Bundle `AppIcon.icns` (or build it from `AppIcon-1024.png` using `build_icon.sh`).

### First launch (unsigned app)

macOS may block the app because it is not signed:

- **Right-click** `SubDrop.app` → **Open**, or  
- Allow it under **System Settings → Privacy & Security**.

If the Dock icon looks stale after an update, remove the app from the Dock and open it again from Applications.

---

## Usage

1. Open **SubDrop** from `~/Applications/SubDrop.app`.
2. Optionally tap **Change language**, search by name or code (e.g. `Persian`, `fa`), and select a language.
3. Drag **one or more** video files onto the drop zone (or onto the Dock icon while the app is running).
4. SubDrop writes `VideoName.srt` beside each video.

Supported extensions (in `fetch.sh`): `mkv`, `mp4`, `m4v`, `mov`, `avi`, `webm`, `ts`, `m2ts`.

### Configuration

Default language file:

```text
~/.config/subdrop/config
```

Example:

```bash
# SubDrop default subtitle language (subliminal / OpenSubtitles code)
SUBDROP_LANG=fa
```

The app updates this file when you change language in the UI. You can override per run in the shell:

```bash
SUBDROP_LANG=en ~/.local/share/subdrop/fetch.sh "/path/to/video.mkv"
```

### Command-line only (no GUI)

```bash
SUBDROP_LANG=fa /path/to/SubDrop.app/Contents/Resources/fetch.sh "/path/to/video.mkv"
```

---

## How it works

### Pipeline

```text
Video file(s)
    → Subliminal (hash + metadata)
    → OpenSubtitles providers (opensubtitlescom, opensubtitles)
    → Download best-matching subtitle
    → Save as <basename>.srt (-s / single name, UTF-8)
    → Python normalization (utf-8-sig → utf-8)
```

### Release matching (sync)

OpenSubtitles and Subliminal use a **video hash** (not just the filename): typically MD5 over the **first and last 64 KiB** of the file combined with size. When someone has uploaded subs for the same rip as yours, timing usually aligns well.

If no hash match exists, Subliminal may fall back to title/season/episode metadata — sync can be worse.

**Dubbed videos:** subtitles follow **picture** timing. They may feel early or late compared to a **dubbed** audio track.

### GUI vs Terminal environment

Apps started from Finder get a minimal `PATH`. `fetch.sh` explicitly sets:

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:..."
```

The Swift app also passes `PATH` and `SUBDROP_LANG` when spawning `fetch.sh`.

### Logs

Last Subliminal run (stderr/stdout):

```text
/tmp/subdrop-last.log
```

---

## Project layout

| Path | Purpose |
|------|---------|
| `SubDropApp.swift` | SwiftUI macOS app (drop UI, language picker, runs `fetch.sh`). |
| `fetch.sh` | Subtitle download script (Subliminal wrapper). |
| `install.sh` | Build app bundle and install to `~/Applications`. |
| `generate_languages.py` | Builds `languages.json` from Babelfish OpenSubtitles language table. |
| `build_icon.sh` | Creates `AppIcon.icns` from a 1024×1024 PNG via `sips` + `iconutil`. |
| `AppIcon-1024.png` / `AppIcon.icns` | Application icon assets. |
| `SubDrop.applescript` | **Legacy** droplet prototype (superseded by the Swift app). |
| `subdrop_gui.py` | Tkinter GUI for Windows/Linux. |
| `subdrop_cli.py` | CLI for all platforms. |
| `subdrop/core.py` | Shared download logic (Subliminal). |
| `packaging/build-macos-dmg.sh` | Builds `dist/SubDrop-mac.dmg`. |
| `packaging/build-windows.ps1` | Builds `dist/SubDrop.exe` on Windows. |
| `packaging/install-linux.sh` | Linux installer script (also copied to `dist/`). |
| `packaging/build-release.sh` | DMG + `subdrop-src.tar.gz` + `install-linux.sh`. |

Installed bundle:

```text
SubDrop.app/
  Contents/
    MacOS/SubDrop          # compiled binary
    Resources/
      fetch.sh
      languages.json
      AppIcon.icns
    Info.plist
```

---

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| **Failed** in the app | Read `/tmp/subdrop-last.log`. |
| `subliminal not found` | `pip3 install subliminal --break-system-packages`; confirm `/opt/homebrew/bin/subliminal` exists. |
| OpenSubtitles errors / rate limits | Wait and retry; providers may skip `opensubtitlescom` and use `opensubtitles`. |
| No subtitle found | Try another language; your release may not be on OpenSubtitles. |
| App won’t open | Right-click → Open (unsigned app). |
| Wrong sync | Subs may be for a different release; try another upload or adjust timing in a subtitle editor. |

---

## References

### Subtitle download

- **Subliminal** — Python subtitle downloader CLI and library.  
  https://github.com/Diaoul/subliminal  
  Documentation: https://subliminal.readthedocs.io/

- **Babelfish** — Language/country objects used by Subliminal; language list source for `generate_languages.py`.  
  https://github.com/Diaoul/babelfish  

- **OpenSubtitles.com** — Primary subtitle database (API used by Subliminal providers).  
  https://www.opensubtitles.com/  

- **OpenSubtitles.org** — Legacy provider name in Subliminal (`opensubtitles`).  
  https://www.opensubtitles.org/  

### Hash matching

- OpenSubtitles **movie hash** (file size + first/last 64 KB) — described in Subliminal/Babelfish refiners and OpenSubtitles API docs.  
  Subliminal hash refiner: https://github.com/Diaoul/subliminal/blob/master/subliminal/refiners/hash.py  

### Apple / macOS

- **SwiftUI** — User interface.  
  https://developer.apple.com/documentation/swiftui  

- **AppKit** — `NSApplicationDelegate`, file open, window behavior.  
  https://developer.apple.com/documentation/appkit  

- **Uniform Type Identifiers** — Drag-and-drop file URLs.  
  https://developer.apple.com/documentation/uniformtypeidentifiers  

- **`swiftc`** — Command-line Swift compiler (Xcode CLT).  
  https://developer.apple.com/documentation/xcode  

- **`iconutil` / `sips`** — macOS icon and image tools (`build_icon.sh`).  
  https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html  

### Python

- **PEP 668** — Externally managed Python environments (`--break-system-packages` on Homebrew Python).  
  https://peps.python.org/pep-0668/

- **PyInstaller** — Bundles `SubDrop.exe` on Windows.  
  https://pyinstaller.org/

- **tkinterdnd2** — Optional drag-and-drop on Windows for the Python GUI.  
  https://pypi.org/project/tkinterdnd2/  

### Optional tools (not bundled)

- **FFmpeg / ffprobe** — Useful for manual duration/sync checks; not required by SubDrop.  
  https://ffmpeg.org/  

---

## Contact

Report bugs or feedback: **[m.hosseini.eng@outlook.com](mailto:m.hosseini.eng@outlook.com)**

---

## License

SubDrop is personal/local tooling. Third-party services (OpenSubtitles) and software (Subliminal) have their own terms of use — comply with their rules when downloading subtitles.

---

## Version

App bundle version in `install.sh`: **1.2** (`CFBundleShortVersionString` / `CFBundleVersion`).

Rebuild after any source change:

```bash
~/.local/share/subdrop/install.sh
```
