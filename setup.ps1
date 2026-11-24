$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$engineDir = Join-Path $root '_engine'
$exe = Join-Path $engineDir 'Godot_v4.7.2-stable_win64.exe'

if (Test-Path $exe) {
    Write-Host "Godot уже установлен: $exe"
    exit 0
}

$url = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip'
$zip = Join-Path $engineDir 'godot.zip'

New-Item -ItemType Directory -Force -Path $engineDir | Out-Null
Write-Host "Скачиваем Godot 4.7.2 (~86 МБ)..."
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Write-Host "Распаковываем..."
Expand-Archive -Path $zip -DestinationPath $engineDir -Force
Remove-Item $zip -Force

if (-not (Test-Path $exe)) {
    throw "Не удалось установить Godot: $exe не найден"
}
Write-Host "Готово: $exe"
