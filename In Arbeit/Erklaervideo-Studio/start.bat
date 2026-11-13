@echo off
rem Startet das Erklaervideo-Studio: Server + Oberflaeche, dann eigenes App-Fenster (Edge im App-Modus).
cd /d "%~dp0"

if not exist node_modules (
  echo Installiere Pakete beim ersten Start ...
  call npm install --no-fund --no-audit
  if errorlevel 1 (
    echo Installation fehlgeschlagen.
    pause
    exit /b 1
  )
)

rem Laeuft das Studio schon? Dann nur ein weiteres App-Fenster oeffnen.
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing http://localhost:5173 -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto fenster

rem Server + Oberflaeche in eigenem, minimiertem Fenster starten
start "Erklaervideo-Studio (Server)" /min cmd /c "npm run dev"

rem Warten, bis die Oberflaeche erreichbar ist (max. ca. 30 s)
set /a tries=0
:wait
set /a tries+=1
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing http://localhost:5173 -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
  if %tries% geq 30 (
    echo Die Oberflaeche startet nicht. Details im Fenster "Erklaervideo-Studio (Server)".
    pause
    exit /b 1
  )
  timeout /t 1 /nobreak >nul
  goto wait
)

:fenster
set EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe
if not exist "%EDGE%" set EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe
if exist "%EDGE%" (
  start "" "%EDGE%" --app=http://localhost:5173 --window-size=1440,920
) else (
  start "" http://localhost:5173
)
