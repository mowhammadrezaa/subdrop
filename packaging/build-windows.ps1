# Build SubDrop.exe on Windows (PowerShell).
# Prerequisites: Python 3.10+, pip install -r requirements.txt pyinstaller
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller
python generate_languages.py languages.json

pyinstaller --noconfirm --clean packaging/subdrop-windows.spec

Write-Host ""
Write-Host "Built: $Root\dist\SubDrop.exe"
Write-Host "Distribute dist\SubDrop.exe (users still need network; first run may be slow)."
