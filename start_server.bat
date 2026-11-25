@echo off
cd /d "%~dp0"
if not exist "_engine\Godot_v4.7.2-stable_win64_console.exe" (
  echo Движок не найден, скачиваем...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
  if errorlevel 1 exit /b 1
)
echo Выделенный сервер: порт 7777, Ctrl+C для выхода.
"_engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -- --host
