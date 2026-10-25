SubDrop for Windows
====================

The .exe must be built ON A WINDOWS PC (PyInstaller cannot cross-compile from macOS/Linux).

Steps:
  1. Install Python 3.10+ from https://www.python.org/downloads/
  2. Extract subdrop-src.tar.gz from the release dist folder
  3. Open PowerShell in that folder
  4. Run:  .\packaging\build-windows.ps1
  5. Ship dist\SubDrop.exe to users

First run on a new PC:
  - Windows may show SmartScreen — click "More info" → "Run anyway"
  - SubDrop uses Subliminal; the bundled exe includes Python dependencies but still needs internet for OpenSubtitles

Optional: install Subliminal globally instead of relying on the bundle:
  pip install subliminal

References: see README.md
