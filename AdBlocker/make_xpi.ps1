$dir = "C:\Users\finns\OneDrive\Desktop\Claude\Games\AdBlocker"
$xpi = "$dir\yt-adblocker.xpi"
$zip = "$dir\yt-adblocker.zip"

if (Test-Path $xpi) { Remove-Item $xpi }
if (Test-Path $zip) { Remove-Item $zip }

Add-Type -Assembly "System.IO.Compression.FileSystem"
$archive = [System.IO.Compression.ZipFile]::Open($zip, "Create")

@("manifest.json","background.js","content.js","popup.html","popup.js","popup.css","icon48.png","icon96.png") | ForEach-Object {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, "$dir\$_", $_) | Out-Null
}

$archive.Dispose()
Rename-Item $zip "yt-adblocker.xpi"
Write-Host "Done: $xpi"
