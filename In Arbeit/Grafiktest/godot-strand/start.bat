@echo off
rem Startet den Grafik-Test direkt (ohne Editor). Mit --editor stattdessen im Godot-Editor oeffnen.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if "%1"=="--editor" (
  start "" "%GODOT%" --path "%~dp0." --editor
) else (
  start "" "%GODOT%" --path "%~dp0."
)
