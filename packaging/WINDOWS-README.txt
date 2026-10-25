SubDrop for Windows
====================

The .exe must be built ON A WINDOWS PC (PyInstaller cannot cross-compile from macOS/Linux).

End users (recommended):
  1. Download SubDrop-Setup.exe from GitHub Releases
  2. Run the installer (no admin required)
  3. SubDrop appears in the Start menu; optionally check "Create a desktop icon"
  4. Uninstall later via Settings → Apps or Start menu → Uninstall SubDrop

Portable / developers:
  1. Install Python 3.10+ from https://www.python.org/downloads/
  2. Install Inno Setup 6 from https://jrsoftware.org/isinfo.php (for the installer)
  3. Extract subdrop-src.tar.gz or clone the repo
  4. Open PowerShell in the project root
  5. Run:  .\packaging\build-windows.ps1
  6. Ship dist\SubDrop-Setup.exe (installer) or dist\SubDrop.exe (portable)

First run on a new PC:
  - Windows may show SmartScreen — click "More info" → "Run anyway"
  - SubDrop uses Subliminal; the bundled exe includes Python dependencies but still needs internet for OpenSubtitles

Optional: install Subliminal globally instead of relying on the bundle:
  pip install subliminal

References: see README.md
