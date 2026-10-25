# Build SubDrop-Setup.exe with Inno Setup (requires dist\SubDrop.exe and dist\SubDrop.ico).
param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$Packaging = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Packaging

if (-not (Test-Path "$Root\dist\SubDrop.exe")) {
    throw "Run packaging\build-windows.ps1 first (missing dist\SubDrop.exe)"
}

if ($Version -eq "") {
    if ($env:GITHUB_REF -match 'refs/tags/v(.+)$') {
        $Version = $Matches[1]
    } elseif ($env:GITHUB_REF_NAME -match '^v(.+)$') {
        $Version = $Matches[1]
    } else {
        $tag = git -C $Root describe --tags --abbrev=0 2>$null
        if ($tag -match '^v(.+)$') {
            $Version = $Matches[1]
        } else {
            $Version = "0.0.0"
        }
    }
}

$isccCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw @"
Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php
  or on CI: choco install innosetup -y
"@
}

$iss = Join-Path $Packaging "subdrop-windows.iss"
Write-Host "Building installer version $Version ..."
& $iscc "/DMyAppVersion=$Version" $iss
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path "$Root\dist\SubDrop-Setup.exe")) {
    throw "dist\SubDrop-Setup.exe was not created"
}
Write-Host "Built: $Root\dist\SubDrop-Setup.exe"
