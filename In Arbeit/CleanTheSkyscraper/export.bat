@echo off
rem Baut die Windows-Version nach export\CleanTheSkyscraper.exe (Spielstand liegt im Godot-Benutzerordner).
rem Mit Internet-Mehrspieler (EOS, Phase 7g) liegen 3 DLLs neben der .exe - zum Weitergeben export\CleanTheSkyscraper-Spiel.zip nehmen.
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
if not exist "%~dp0addons\epic-online-services-godot\eosg.gdextension" (
  echo Hinweis: Das EOS-Paket fehlt in addons\ - die .exe hat dann kein Internet-Spiel, nur Heimnetz.
)
if not exist "%~dp0eos_zugang.cfg" (
  echo Hinweis: eos_zugang.cfg fehlt - die .exe hat dann kein Internet-Spiel, nur Heimnetz.
)
del /q "%~dp0export\*.dll" 2>nul
"%GODOT%" --headless --path "%~dp0." --export-release "Windows Desktop" "%~dp0export\CleanTheSkyscraper.exe"
if not exist "%~dp0export\CleanTheSkyscraper.exe" (
  echo Export fehlgeschlagen.
  pause
  exit /b 1
)
del /q "%~dp0export\CleanTheSkyscraper-Spiel.zip" 2>nul
rem Packen mit bis zu 15 Versuchen: direkt nach dem Bauen ist die .exe manchmal noch gesperrt (z. B. OneDrive synchronisiert sie)
powershell -NoProfile -Command "$d='%~dp0export'; $zip=$d+'\CleanTheSkyscraper-Spiel.zip'; $f=@($d+'\CleanTheSkyscraper.exe') + @(Get-ChildItem -Path ($d+'\*.dll') | ForEach-Object { $_.FullName }); for ($i=0; $i -lt 15; $i++) { try { Compress-Archive -Path $f -DestinationPath $zip -Force -ErrorAction Stop; break } catch { Start-Sleep -Seconds 2 } }; Add-Type -AssemblyName System.IO.Compression.FileSystem; $z=[IO.Compression.ZipFile]::OpenRead($zip); $ok=@($z.Entries | Where-Object { $_.Name -eq 'CleanTheSkyscraper.exe' }).Count; $z.Dispose(); if ($ok -eq 0) { Write-Host 'FEHLER: Die Zip enthaelt die .exe nicht - bitte export.bat nochmal starten.'; exit 1 } else { Write-Host 'Zip geprueft: .exe und DLLs sind drin.' }"
echo.
echo Fertig: export\CleanTheSkyscraper.exe
echo Zum Weitergeben an Freunde: export\CleanTheSkyscraper-Spiel.zip (alles drin, nur entpacken und starten)
if not "%1"=="leise" pause
