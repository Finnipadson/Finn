# Legt eine Verknuepfung "Highlight Cutter" an (Standard: auf dem Desktop).
# Aufruf:  powershell -ExecutionPolicy Bypass -File verknuepfung.ps1 [-Ziel <Ordner>]
# Hinweis: Datei nur ASCII, Windows PowerShell 5.1 liest sie sonst falsch.
param(
    [string]$Ziel = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Stop'
$projekt = Split-Path -Parent $MyInvocation.MyCommand.Path
$start = Join-Path $projekt 'start.bat'
$icon = Join-Path $projekt 'web\icon.ico'

if (-not (Test-Path $start)) { throw "start.bat nicht gefunden: $start" }
if (-not (Test-Path $Ziel)) { New-Item -ItemType Directory -Force -Path $Ziel | Out-Null }
$Ziel = (Resolve-Path $Ziel).Path

$lnk = Join-Path $Ziel 'Highlight Cutter.lnk'
$shell = New-Object -ComObject WScript.Shell
$v = $shell.CreateShortcut($lnk)
$v.TargetPath = $start
$v.WorkingDirectory = $projekt
$v.WindowStyle = 7   # minimiert: das Konsolenfenster stoert nicht, die App oeffnet sich in Edge
$v.Description = 'Highlight Cutter - Kills aus NVIDIA-Aufnahmen schneiden'
if (Test-Path $icon) { $v.IconLocation = "$icon,0" }
$v.Save()

Write-Host "Verknuepfung angelegt: $lnk"
