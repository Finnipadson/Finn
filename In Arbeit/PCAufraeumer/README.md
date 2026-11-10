# PC Aufräumer & Systemübersicht

Windows-11-App (C# / .NET 8 / WPF), komplett auf Deutsch. Sie findet unnötige Dateien, zeigt sie dir **vor** dem Löschen in einer Vorschau und schiebt nur das in den Papierkorb, was du selbst freigibst. Dazu kommt eine Systemübersicht mit Live-Werten und Treiberprüfung.

---

## Schnellstart (ohne Programmierkenntnisse)

1. Öffne den Ordner `publish\PCAufraeumer\`.
2. Doppelklick auf **`PCAufraeumer.exe`**. Eine Installation ist nicht nötig, .NET ist schon mitgeliefert.
3. Optional: Rechtsklick auf die .exe → *Weitere Optionen* → *Senden an* → *Desktop (Verknüpfung erstellen)*.

> Der ganze Ordner gehört zusammen (die VLC-Dateien für den Videoplayer liegen im Unterordner `libvlc`). Wenn du die App verschieben willst, verschiebe immer den **ganzen Ordner**.

Die App startet **ohne Adminrechte**. Nur zwei Dinge fragen gezielt per UAC nach Adminrechten (in der App mit 🛡 *Admin* markiert):
- Leeren von `C:\Windows\Temp` und den Windows-Update-Resten
- optional „Mit Adminrechten neu starten“ für die CPU-Temperatur

## So benutzt du die App

| Seite | Was passiert dort |
|---|---|
| **Übersicht** | CPU, Grafikkarte, RAM, Laufwerke (SSD/HDD/NVMe + Gesundheit), Mainboard, BIOS, Windows, Betriebszeit. Live-Werte alle 3 s. |
| **Treiber** | Wichtige Treiber mit Version und Datum. NVIDIA wird mit der neuesten Version verglichen. Mit „Über Windows Update prüfen“ siehst du angebotene Treiber-Updates. Die App **installiert nichts**. |
| **Scan** | Ordner auswählen, Ausschlüsse festlegen, Kategorien an- oder abschalten, „Scan starten“. Der Scan löscht nichts. |
| **Ergebnisse** | Liste nach Kategorie gruppiert, Vorschau rechts (Video, Bild, Text, PDF). Häkchen setzen → „In den Papierkorb“. |
| **Desktop aufräumen** | Ordnet App-Symbole nach Kategorien in Gruppen an und packt lose Dateien in passende Ordner. Mit Vorher/Nachher-Vorschau, Verlauf und „Rückgängig machen“. |
| **Protokoll** | Jede Löschung und jede Desktop-Aufräumaktion mit Datum, Pfad und Größe, als CSV exportierbar. Darunter steht das Fehlerprotokoll. |
| **Einstellungen** | Zeiträume, Kategorien, Mindestgröße, Ausschluss- und Ausnahmeliste, Dark/Light Mode. |

### Typischer Ablauf
1. **Scan** → Ordner prüfen → *Scan starten* (Abbrechen ist jederzeit möglich).
2. **Ergebnisse** → Datei anklicken → rechts ansehen/abspielen.
3. Häkchen bei allem setzen, was weg darf. **Standardmäßig ist nichts ausgewählt.**
4. Unten steht, wie viel du freigibst („Du gibst 23,4 GB frei“).
5. *In den Papierkorb* → Bestätigungsdialog mit Liste → bestätigen.
6. Etwas versehentlich gelöscht? Im **Papierkorb** wiederherstellen (*Protokoll → Papierkorb öffnen*).

### Die Kategorien
- **Alte Videos/Clips**: Videodateien, die seit dem eingestellten Zeitraum nicht geöffnet wurden (Standard: 1 Jahr).
- **Doppelte Dateien**: Die App filtert zuerst nach Größe, prüft dann Anfang und Ende der Datei und bestätigt am Ende per Inhalts-Hash (xxHash128). Pro Gruppe schlägt sie eine Kopie zum **Behalten** vor (grünes „BLEIBT“). Sie bevorzugt dabei Kopien, die nicht in Downloads/Temp liegen und kein „Kopie“ oder „(1)“ im Namen haben, sonst die älteste. Mit „Diese Kopie behalten“ änderst du den Vorschlag. Mindestens eine Kopie bleibt **immer** erhalten.
- **Temp-/Cache-Dateien**: `%TEMP%`, `C:\Windows\Temp`, Chrome-, Edge- und Firefox-Cache, Miniaturansichten, Windows-Update-Reste. Sie werden als eigener Bereich angezeigt, unabhängig von der Ordnerauswahl. Diese Dateien werden **direkt** gelöscht (kein Papierkorb), aber erst nach einer eigenen Bestätigung mit Pflicht-Häkchen. Browser-Caches lassen sich nur bei geschlossenem Browser leeren.
- **Alte Downloads/Installer**: `.exe`, `.msi`, `.zip`, `.rar`, `.7z`, `.iso` usw. im Downloads-Ordner, die älter sind als der eingestellte Zeitraum (Standard: 6 Monate).

### Desktop aufräumen
1. Seite **Desktop aufräumen** öffnen. Die App liest deinen Desktop (auch einen per OneDrive umgeleiteten) und den öffentlichen Desktop. Dabei wird **nichts verändert**.
2. Einen **Anordnungs-Vorschlag** anklicken. Jede Karte zeigt eine Mini-Vorschau:
   - **Spalten**: jede Kategorie in eigenen Spalten, mit Abstand dazwischen (Standard)
   - **Kompakt**: alles dicht am linken Rand, maximal viel freie Fläche
   - **Zeilen**: jede Kategorie als waagerechte Reihe oben, eine unter der anderen
   - **Blöcke**: jede Kategorie als kleiner, fast quadratischer Block
   - **Ränder**: Apps links, Ordner ganz rechts, die Mitte bleibt frei fürs Hintergrundbild

   Passt ein Vorschlag nicht ganz auf den Bildschirm, steht das auf der Karte. Die App merkt sich deine Wahl.
3. **Vorher | Nachher** vergleichen. Mit dem Pfeil-Knopf oben rechts siehst du die Vorschau groß.
4. In der Liste **„Geplante Änderungen“** kannst du:
   - einzelne Änderungen abwählen,
   - für ein Symbol eine andere Gruppe wählen (oder es im Nachher-Bild per **Drag & Drop** bzw. Rechtsklick in eine andere Gruppe ziehen; die App merkt sich das),
   - für eine Datei einen anderen Zielordner wählen oder einen neuen Namen eintippen.
5. **Übernehmen …** → Bestätigung → fertig.
6. **Verlauf** rechts: Jede Aktion lässt sich mit **Rückgängig** einzeln wiederherstellen. Dateien kommen zurück, Symbole an ihre alten Plätze, und neu angelegte Ordner werden nur entfernt, wenn sie leer sind. Die App behält die letzten 20 Aktionen.

Was passiert genau:
- **App-Symbole** (Verknüpfungen, Steam-/Epic-Links …) bleiben als Symbole auf dem Desktop. Sie werden nur **neu angeordnet**: jede Kategorie in eigenen Spalten, von links nach rechts in der Reihenfolge aus den Einstellungen.
- **Lose Dateien** kommen in Ordner auf dem Desktop: Bilder, Screenshots, Dokumente, Videos, Musik, Archive, Installer, Sonstiges. Ein vorhandener passender Ordner (z. B. „Fotos“ für Bilder) wird genutzt. Gleichnamige Dateien werden zu „Name (2)“, **nichts wird überschrieben**. Geöffnete Dateien werden übersprungen.
- **Ordner** werden nicht verändert, nur rechts mit einsortiert.
- **Papierkorb, Dieser PC** und alles auf deiner „Nie anfassen“-Liste bleiben, wo sie sind.
- **Öffentlicher Desktop** (`C:\Users\Public\Desktop`): Diese Symbole werden nur neu angeordnet, nie verschoben.
- **Monitore:** Symbole auf anderen Monitoren bleiben dort. Mit dem Häkchen oben holst du sie auf den Hauptmonitor.
- **Es wird nie etwas gelöscht.**

Gut zu wissen:
- Ist **„Symbole automatisch anordnen“** eingeschaltet (Rechtsklick auf den Desktop → Ansicht), sortiert Windows selbst um und eigene Positionen halten nicht. Die App zeigt das an und kann es ausschalten.
- Windows speichert die Positionen selbst. Ändert sich die Bildschirmauflösung, kann Windows Symbole verschieben. Dafür gibt es den Verlauf mit „Rückgängig“.
- In den **Einstellungen → Desktop aufräumen** verwaltest du Kategorien (hinzufügen, umbenennen, löschen, Reihenfolge), die Regeln „Programm → Kategorie“ und „Dateityp → Ordner“ sowie die „Nie anfassen“-Liste.

### „Zuletzt geöffnet“: wie zuverlässig ist das?
Windows aktualisiert das Datum „Letzter Zugriff“ nicht immer. Die App liest die Einstellung `NtfsDisableLastAccessUpdate` aus der Registry und zeigt sie auf der Scan-Seite an. Die Ausgabe von `fsutil behavior query disablelastaccess` steht dort ebenfalls, falls Windows sie ohne Adminrechte liefert. Ist die Aktualisierung aus, nutzt die App das **Änderungsdatum**. In der Spalte **Grundlage** steht bei jeder Datei, welches Datum verwendet wurde.

Gut zu wissen:
- Die App setzt das Zugriffsdatum nach Hash-Berechnung, Vorschaubild und Vorschau wieder zurück, damit sie die Einstufung nicht selbst verfälscht.
- Virenscanner wie Windows Defender und die Windows-Suche lesen neue oder geänderte Dateien selbst. Dabei setzen sie „Letzter Zugriff“ auf *jetzt*. Bei alten, unberührten Dateien passiert das nicht.

## Sicherheit

**Fest geschützt und nie vorgeschlagen:**
- `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData`, `AppData`
- Systemdateien und versteckte Systemdateien
- geöffnete oder gesperrte Dateien
- OneDrive-Dateien „Nur online verfügbar“: Diese werden beim Scan **nicht heruntergeladen**, es werden nur ihre Attribute gelesen.
- Programm-, Spiele- und Entwicklerordner (`steamapps`, `Epic Games`, `WindowsApps`, `.git`, `node_modules` …)

**Weitere Regeln:**
- **Papierkorb only**: Funde aus dem Dateiscan landen ausschließlich im Windows-Papierkorb. Auf Laufwerken ohne Papierkorb (USB-Sticks, Netzlaufwerke) verweigert die App das Löschen. Passt eine Datei nicht in den Papierkorb, warnt Windows, statt sie still endgültig zu löschen.
- **Direkt vor dem Löschen** prüft die App jede Datei noch einmal: Liegt sie an einem geschützten Ort? Ist sie geöffnet? Hat sich die Größe seit dem Scan geändert?
- **Internet**: Die App verbindet sich nur bei der Treiberprüfung mit dem Internet. Für NVIDIA geht dabei nur das Grafikkartenmodell an nvidia.com (abschaltbar), die Windows-Update-Suche startet nur auf Knopfdruck.
- **Fehler** (fehlende Rechte, gesperrte Dateien …) werden angezeigt und protokolliert. Die App stürzt deswegen nicht ab.

### NVIDIA-Treiberprüfung: wie funktioniert das?
NVIDIA bietet **keine offizielle Schnittstelle** für die neueste Treiberversion. Die App nutzt dieselben (inoffiziellen) Abfragen wie die Treibersuche auf nvidia.com:
1. die Produktliste unter `nvidia.com/Download/API/lookupValueSearch.aspx`
2. die Treibersuche unter `gfwsl.geforce.com/.../AjaxDriverService.php`

Sie vergleicht die Game-Ready-Version (WHQL, DCH) mit der installierten Version, die aus der Windows-Treiberversion umgerechnet wird, z. B. `32.0.16.2114` → `621.14`. Wenn etwas fehlschlägt, bleibt die Ampel **grau** und der Knopf zur NVIDIA-Seite ist da. Die App zeigt **nie** „aktuell“ an, ohne wirklich geprüft zu haben.

## Wo speichert die App ihre Daten?
`%APPDATA%\PCAufraeumer\`
- `einstellungen.json`: alle Einstellungen
- `loeschprotokoll.jsonl`: Löschprotokoll (CSV-Export in der App)
- `fehler.log`: Fehlerprotokoll
- `letztes-ergebnis.json`: letzte Ergebnisliste (wird beim Start automatisch geladen)
- `Ergebnisse\`: deine mit „Speichern unter …“ gesicherten Ergebnislisten
- `Desktop-Verlauf\`: gespeicherte Zustände vor jeder Desktop-Aufräumaktion (Grundlage für „Rückgängig“)

---

## Für Entwickler

### Voraussetzungen
- Windows 10/11 x64
- .NET 8 SDK: `winget install Microsoft.DotNet.SDK.8`

### Bauen, testen, starten
```bash
cd "Games/In Arbeit/PCAufraeumer"
dotnet build
dotnet test                       # 48 Tests – arbeiten nur in %USERPROFILE%\PCAufraeumer-Testordner
dotnet run --project src/PCAufraeumer
```

### Startbare .exe erzeugen
```bash
dotnet publish src/PCAufraeumer -c Release -r win-x64 --self-contained true -o publish/PCAufraeumer
```
Ergebnis: `publish/PCAufraeumer/PCAufraeumer.exe` (ca. 260 MB inkl. .NET und VLC, läuft ohne Installation).

### Technik & Begründung
**WPF statt WinUI 3**: Der Videoplayer LibVLCSharp (spielt auch .mkv & Co.) läuft unter WPF stabil. Die .exe startet ohne MSIX-Paket und Zertifikat. Virtualisierte Listen sind in WPF bewährt.

| Bibliothek | Zweck |
|---|---|
| CommunityToolkit.Mvvm | MVVM (ObservableProperty, RelayCommand) |
| LibVLCSharp.WPF + VideoLAN.LibVLC.Windows | eingebauter Videoplayer |
| Microsoft.Web.WebView2 | PDF-Vorschau (blockiert jedes Nachladen aus dem Internet) |
| System.IO.Hashing | xxHash128 für Duplikate |
| System.Management | WMI: Hardware, Treiber, Laufwerksgesundheit (`MSFT_PhysicalDisk`) |

**Bewusst nicht verwendet:** LibreHardwareMonitorLib. Sie braucht für die CPU-Temperatur den Kernel-Treiber WinRing0, den Windows Defender seit 2025 als verwundbaren Treiber meldet. Stattdessen liest die App die CPU-Temperatur über die ACPI-Thermalzone (nur mit Adminrechten, nicht auf jedem Board). Die GPU-Temperatur kommt zuverlässig aus `nvidia-smi`.

### Projektstruktur
```
PCAufraeumer/
├─ PCAufraeumer.sln
├─ src/PCAufraeumer/
│  ├─ Models/        FileCandidate, TempTarget, AppSettings, Log/Result-Modelle
│  ├─ Services/      ScanService (Scan + Duplikate), ProtectionService (Schutzregeln),
│  │                 CleanupService (Papierkorb + Admin-Helfer), TempService, LastAccessService,
│  │                 SystemInfoService, DriverService (WMI/WU/NVIDIA), ThumbnailService, Storage …
│  ├─ ViewModels/    eine pro Seite + MainViewModel (Navigation)
│  ├─ Views/         XAML-Seiten, PreviewPanel (Video/Bild/Text/PDF), ConfirmDialog, Vollbild
│  ├─ Themes/        Colors.Dark/Light.xaml, Styles.xaml
│  └─ Interop/       Windows-API (SHFileOperation, Shell-Thumbnails, Known Folders)
└─ tests/PCAufraeumer.Tests/   xUnit-Tests (Scan-Regeln, Schutz, Duplikate, Papierkorb, Temp, CSV, Treiber)
```

### Admin-Helfer
Für Admin-Bereiche startet die App sich selbst mit `--admin-clean <job> <ergebnis>` per UAC. Der Helfer bekommt **nur IDs** aus der fest eingebauten Temp-Liste (keine beliebigen Pfade) und schreibt das Protokoll zurück.

### Test-Datenordner
Mit der Umgebungsvariable `PCA_DATADIR` nutzt die App einen anderen Datenordner, damit deine echten Einstellungen beim Testen unberührt bleiben.

### Desktop aufräumen: Technik
- **Symbolpositionen:** `IShellWindows.FindWindowSW(SWC_DESKTOP)` → `IShellBrowser` → `IFolderView2` (`GetItemPosition`, `SelectAndPositionItems`, `GetCurrentFolderFlags`/`SetCurrentFolderFlags` für „Automatisch anordnen“). Es werden keine Dateien verschoben, um Symbole anzuordnen. Koordinaten sind physische Pixel der Desktop-Ansicht; Monitore kommen über `EnumDisplayMonitors` + `ScreenToClient` (DPI-bewusst, mehrere Monitore).
- **Verknüpfungen:** `.lnk` über `IShellLinkW` (Ziel, Argumente, Hersteller/Produkt aus der Versionsinfo), `.url` als Textdatei (`steam://`, `com.epicgames.launcher://` …).
- **Testmodus:** `PCA_DESKTOP_TEST=<Ordner>` nutzt statt des Desktops ein offenes Explorer-Fenster dieses Ordners. Windows-11-Ordnerfenster ordnen immer automatisch an. Dort lässt sich also das Verschieben von Dateien und das Rückgängigmachen testen, nicht aber freie Positionen. Den echten Desktop prüft der Test `Real_desktop_single_icon_position_and_restore` (nur mit `PCA_REAL_DESKTOP_TEST=1`): Er bewegt ein einziges Symbol und stellt danach alle Positionen wieder her.
