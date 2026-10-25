# Build SubDrop.exe on Windows (PowerShell).
# Prerequisites: Python 3.10+, pip install -r requirements.txt pyinstaller
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller pillow
python generate_languages.py languages.json

pyinstaller --noconfirm --clean packaging/subdrop-windows.spec
if ($LASTEXITCODE -ne 0) {
  throw "PyInstaller failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path "$Root\dist\SubDrop.exe")) {
  throw "dist\SubDrop.exe was not created"
}

$iconPng = Join-Path $Root "AppIcon-1024.png"
$iconIco = Join-Path $Root "dist\SubDrop.ico"
if (Test-Path $iconPng) {
  python -c @"
from pathlib import Path
from PIL import Image
src = Path(r'$iconPng')
dst = Path(r'$iconIco')
img = Image.open(src).convert('RGBA')
sizes = [(256, 256), (64, 64), (48, 48), (32, 32), (16, 16)]
img.save(dst, format='ICO', sizes=sizes)
print('Wrote', dst)
"@
}

$installerScript = Join-Path $Root "packaging\build-windows-installer.ps1"
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
  $iscc = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
}
if ((Test-Path $iscc) -and (Test-Path $iconIco)) {
  & $installerScript
} elseif ($env:GITHUB_ACTIONS -eq "true") {
  throw "Inno Setup or SubDrop.ico missing; install Inno Setup on the runner (choco install innosetup)"
} else {
  Write-Warning "Skip installer: install Inno Setup 6 to build dist\SubDrop-Setup.exe"
}

Write-Host ""
Write-Host "Built: $Root\dist\SubDrop.exe"
if (Test-Path "$Root\dist\SubDrop-Setup.exe") {
  Write-Host "Built: $Root\dist\SubDrop-Setup.exe (recommended for end users)"
}
Write-Host "Users need internet for OpenSubtitles; first run may be slow."
