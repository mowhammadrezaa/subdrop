# PyInstaller spec — build on Windows: pyinstaller packaging/subdrop-windows.spec
# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

from PyInstaller.utils.hooks import collect_all

# SPECPATH is the directory that contains this .spec file (packaging/).
ROOT = Path(SPECPATH).resolve().parent

dnd_datas, dnd_binaries, dnd_hidden = collect_all("windnd")

a = Analysis(
    [str(ROOT / "subdrop_gui.py")],
    pathex=[str(ROOT)],
    binaries=dnd_binaries,
    datas=[(str(ROOT / "languages.json"), ".")] + dnd_datas,
    hiddenimports=[
        "babelfish",
        "subliminal",
        "subliminal.cli.cli",
        "guessit",
        "dogpile",
        "stevedore",
        *dnd_hidden,
    ],
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
