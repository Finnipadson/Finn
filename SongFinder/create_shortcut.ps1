$ws = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcut = $ws.CreateShortcut($desktop + '\SongFinder.lnk')
$shortcut.TargetPath = 'C:\Users\finns\AppData\Local\Programs\Python\Python314\pythonw.exe'
$shortcut.Arguments = 'C:\Users\finns\OneDrive\Desktop\Claude\Games\SongFinder\app.py'
$shortcut.WorkingDirectory = 'C:\Users\finns\OneDrive\Desktop\Claude\Games\SongFinder'
$shortcut.IconLocation = 'C:\Users\finns\OneDrive\Desktop\Claude\Games\SongFinder\icon.ico'
$shortcut.Description = 'SongFinder'
$shortcut.Save()
Write-Host "Verknuepfung aktualisiert."
