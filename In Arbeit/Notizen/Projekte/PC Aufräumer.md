---
typ: app
status: in Arbeit
technik: C# .NET 8 WPF
---

Windows-App „PC Aufräumer & Systemübersicht“: Dateiscan mit Vorschau + Papierkorb-Löschen, Dashboard, Treiberprüfung, Desktop aufräumen, Programme (Deinstallieren, Restesuche, Autostart, winget-Updates), Speicher-Karte (Treemap), Downloads sortieren.

- Build/Start/Publish: [[PCAufraeumer/README|README]]
- Plan Speicher/Updates/Downloads: [[Plan-Speicher-Updates-Downloads]]
- Tests: `dotnet test` (nur in `%USERPROFILE%\PCAufraeumer-Testordner`)
- Testmodi: `PCA_DESKTOP_TEST`, `PCA_DOWNLOADS_TEST`, Datenordner per `PCA_DATADIR`

## Offene Punkte

-

## Notizen

- WPF-Fallen siehe [[Gelernte Fehler]]
