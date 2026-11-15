@echo off
rem Startet Clean the Skyscraper. Mit --editor stattdessen im Godot-Editor oeffnen.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot wurde nicht gefunden. Installieren mit: winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
if "%1"=="--editor" (
  start "" "%GODOT%" --path "%~dp0." --editor
) else (
  start "" "%GODOT%" --path "%~dp0."
)
