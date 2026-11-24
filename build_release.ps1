$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$engine = Join-Path $root '_engine\Godot_v4.7.2-stable_win64_console.exe'
$outputDir = Join-Path $root 'build\windows'

if (-not (Test-Path $engine)) {
    Write-Host "Godot not found, running setup.ps1..."
    & (Join-Path $root 'setup.ps1')
}

Write-Host "Preparing export templates..."
& (Join-Path $root 'setup_export_templates.ps1')

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Write-Host "Exporting Windows build to $outputDir..."
& $engine --headless --path $root --export-release "Windows Desktop" (Join-Path $outputDir 'LesnayaZavarushka.exe')
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with code $LASTEXITCODE"
}

# Inno Setup is optional: if iscc is on PATH, build the installer as well.
$iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
if ($iscc) {
    Write-Host "Building installer with Inno Setup..."
    & $iscc (Join-Path $root 'installer.iss')
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup failed with code $LASTEXITCODE"
    }
} else {
    Write-Host "Inno Setup (iscc) not found — skipped installer. Install it to build setup.exe."
}

Write-Host "Release build ready: $outputDir"
