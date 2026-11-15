# Arbeitsnotizen für Claude – PCAufraeumer

Wird vor der Arbeit an diesem Projekt gelesen (Verweis in der Haupt-`CLAUDE.md`). Neue Projektdetails hier eintragen, nicht in der Haupt-`CLAUDE.md`.

- Windows-Desktop-App „PC Aufräumer & Systemübersicht“ (C# .NET 8 WPF, kein Spiel): Dateiscan (alte Videos, Duplikate, Temp/Cache, alte Downloads) mit Vorschau (LibVLC, WebView2) + Papierkorb-Löschen, Dashboard, Treiberprüfung (NVIDIA inoffizielle API, Windows Update), „Desktop aufräumen“ (Symbole per IFolderView2 gruppieren, lose Dateien in Ordner, Verlauf + Rückgängig
- Testmodus `PCA_DESKTOP_TEST`)
- Seite „Programme“ (wie Revo: Deinstallieren inkl
- Store-Apps/Launcher-Spiele, Restesuche Sicher/Moderat/Erweitert mit Schutzregeln, erzwungene Deinstallation, Installationsaufzeichnung, Autostart wie Task-Manager, Tab „Updates“ über winget
- Admin-Aktionen per `--admin-job` + UAC)
- Seite „Speicher“ (Treemap-Karte, nur lesend), Seite „Downloads“ (Dateien in Unterordner sortieren, Verlauf + Rückgängig
- Testmodus `PCA_DOWNLOADS_TEST`)
- Build/Start/Publish: `README.md` dort
- Tests: `dotnet test` (nur in `%USERPROFILE%\PCAufraeumer-Testordner`)
- Test-Datenordner per Env `PCA_DATADIR`
