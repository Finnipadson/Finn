Fallen, die schon mal Zeit gekostet haben. Kurzfassung, die ausführliche Version liegt in Claudes Memory-Ordner.

## Browser-Spiele (HTML/CSS/JS)

- Element mit `hidden` wird trotzdem angezeigt, wenn CSS `display: flex` setzt → immer `[hidden] { display: none !important; }`.
- `display: grid` mit fester Höhe → immer auch `grid-template-rows` setzen.
- SVG-Overlay mit `preserveAspectRatio="none"` braucht einen Container mit **fester Höhe**.
- Testen über lokalen http-Server, nicht `file://`.
- Screens mit Einblend-Animation erst nach ~1 s screenshotten.

## Browser-Erweiterungen

- Firefox: `browser_specific_settings.gecko.id` und `data_collection_permissions` sind Pflicht.
- Zustands-Klassen wie `.ad-showing` nur zum Erkennen nutzen, nie Elemente damit entfernen.

## Windows / PowerShell

- Komplexe Befehle als `.ps1`-Datei ausführen statt inline.
- PowerShell 5.1 zerstört Umlaute in UTF-8-Dateien ohne BOM → Code nie mit `Get-Content`/`Set-Content` bearbeiten; `.ps1` nur ASCII.
- `[IO.File]` ignoriert `cd` → absolute Pfade.

## WPF / C# ([[PC Aufräumer]])

- `ImplicitUsings` enthält kein `System.IO`.
- DataGrid mit Checkbox-Spalten → `IsReadOnly="True"`; im TabItem `EnableColumnVirtualization="False"`.
- Shell-COM-Objekte nur auf ihrem STA-Thread nutzen.

## Python / KI

- Library-Signaturen vor Benutzung prüfen (z. B. sounddevice-WASAPI-Loopback → `pyaudiowpatch`).
- `enable_model_cpu_offload()` + IP-Adapter → Device-Mismatch; stattdessen `pipe.to("cuda")`.
- pip-cuDNN nicht neben dem torch-cuDNN installieren.

## Remotion

- Jedes Video in einem eigenen `src/<Name>/`-Ordner.
