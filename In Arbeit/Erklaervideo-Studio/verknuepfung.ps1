# Legt eine Desktop-Verknuepfung "Erklaervideo-Studio" mit eigenem Icon an.
# Aufruf: Rechtsklick -> "Mit PowerShell ausfuehren"  (oder: powershell -ExecutionPolicy Bypass -File verknuepfung.ps1)
$ordner = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktop = [Environment]::GetFolderPath('Desktop')
$ziel = Join-Path $desktop 'Erklaervideo-Studio.lnk'
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($ziel)
$lnk.TargetPath = Join-Path $ordner 'start.bat'
$lnk.WorkingDirectory = $ordner
$lnk.IconLocation = (Join-Path $ordner 'assets\icon.ico') + ',0'
$lnk.Description = 'Erklaervideo-Studio: Thema eingeben, animiertes Erklaervideo erhalten'
$lnk.WindowStyle = 7   # Startfenster minimiert
$lnk.Save()
Write-Host "Verknuepfung erstellt: $ziel"
