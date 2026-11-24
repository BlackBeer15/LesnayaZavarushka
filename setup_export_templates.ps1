$ErrorActionPreference = 'Stop'

# Шаблоны экспорта нужны только для сборки релиза; в репозиторий не кладутся.
$version = '4.7.2-stable'
$dest = Join-Path $env:APPDATA "Godot\export_templates\$version"
$marker = Join-Path $dest 'windows_release_x86_64.exe'

if (Test-Path $marker) {
    Write-Host "Export templates already installed: $dest"
    exit 0
}

$url = "https://github.com/godotengine/godot/releases/download/$version/Godot_v${version}_export_templates.tpz"
$archive = Join-Path $env:TEMP "godot_templates_${version}.zip"
$extract = Join-Path $env:TEMP "godot_templates_${version}"

Write-Host "Downloading Godot export templates (~1.3 GB)..."
Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
Write-Host "Extracting..."
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
Expand-Archive -Path $archive -DestinationPath $extract -Force
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path (Join-Path $extract 'templates\*') -Destination $dest -Recurse -Force
Remove-Item $archive -Force
Remove-Item $extract -Recurse -Force

if (-not (Test-Path $marker)) {
    throw "Export templates were not installed: $marker not found"
}
Write-Host "Export templates installed: $dest"
