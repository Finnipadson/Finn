@echo off
rem Highlight Cutter starten. Legt beim ersten Mal die Python-Umgebung (.venv) an.
setlocal
cd /d "%~dp0"
title Highlight Cutter

if exist ".venv\Scripts\python.exe" goto starten

echo Erster Start: richte die Python-Umgebung ein. Das dauert ein paar Minuten ...
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
  echo.
  echo Python wurde nicht gefunden. Bitte Python 3.12 oder neuer installieren:
  echo   winget install Python.Python.3.14
  echo und danach start.bat nochmal doppelklicken.
  pause
  exit /b 1
)
%PY% -m venv .venv
if errorlevel 1 goto fehler
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto fehler

:starten
where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo.
  echo Achtung: FFmpeg wurde nicht gefunden. Ohne FFmpeg geht nichts.
  echo Installieren mit:  winget install Gyan.FFmpeg   - danach dieses Fenster neu oeffnen.
  echo.
)
".venv\Scripts\python.exe" -m cutter server %*
if errorlevel 1 (
  echo.
  echo Der Server wurde mit einem Fehler beendet.
  pause
)
exit /b 0

:fehler
echo.
echo Einrichtung fehlgeschlagen. Ordner .venv loeschen und start.bat nochmal starten.
pause
exit /b 1
