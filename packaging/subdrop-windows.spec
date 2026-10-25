# PyInstaller spec — build on Windows: pyinstaller packaging/subdrop-windows.spec
# -*- mode: python ; coding: utf-8 -*-

import sys
from pathlib import Path

ROOT = Path(SPECPATH).resolve().parent.parent

a = Analysis(
    [str(ROOT / "subdrop_gui.py")],
    pathex=[str(ROOT)],
    binaries=[],
    datas=[(str(ROOT / "languages.json"), ".")],
    hiddenimports=["babelfish", "subliminal", "guessit", "dogpile", "stevedore"],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="SubDrop",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ROOT / "AppIcon-1024.png") if (ROOT / "AppIcon-1024.png").exists() else None,
)
