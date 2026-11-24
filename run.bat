@echo off
cd /d "%~dp0"
if not exist "_engine\Godot_v4.7.2-stable_win64.exe" (
  echo Движок не найден, скачиваем...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
  if errorlevel 1 exit /b 1
)
start "" "_engine\Godot_v4.7.2-stable_win64.exe" --path . %*
