@echo off
rem Baut die Windows-Version nach export\CleanTheSkyscraper.exe (eine Datei, Spielstand liegt im Godot-Benutzerordner).
rem Voraussetzung einmalig: Godot-Editor oeffnen (start.bat --editor) - Editor - Exportvorlagen verwalten - Herunterladen und installieren.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" (
  echo Godot wurde nicht gefunden. Installieren mit: winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
if not exist "%APPDATA%\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe" (
  echo Die Godot-Exportvorlagen fehlen noch.
  echo Im Godot-Editor: Editor - Exportvorlagen verwalten - Herunterladen und installieren.
  pause
  exit /b 1
)
if not exist "%~dp0export" mkdir "%~dp0export"
"%GODOT%" --headless --path "%~dp0." --export-release "Windows Desktop" "%~dp0export\CleanTheSkyscraper.exe"
echo.
echo Fertig: export\CleanTheSkyscraper.exe
pause
