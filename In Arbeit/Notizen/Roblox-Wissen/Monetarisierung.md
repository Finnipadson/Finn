# Monetarisierung

Zurück: [[Roblox-Wissen]]

## Arten

- **Game Pass:** einmal kaufen, für immer (z. B. „2x Geschwindigkeit“, VIP). Prüfen mit `MarketplaceService:UserOwnsGamePassAsync` beim Beitreten + bei `PromptGamePassPurchaseFinished`.
- **Developer Product:** beliebig oft kaufbar (Eier-Pakete, Währung, Restock sofort). Abwicklung **nur** über `MarketplaceService.ProcessReceipt`.

## ProcessReceipt – Checkliste

- Genau **eine** Funktion `ProcessReceipt` im ganzen Spiel (auf dem Server).
- Prüfen: Spieler ist da, Produkt-ID bekannt.
- **Erst gutschreiben und speichern, dann** `Enum.ProductPurchaseDecision.PurchaseGranted` zurückgeben. Klappt etwas nicht (Spieler weg, Speichern fehlgeschlagen) → `NotProcessedYet`; Roblox versucht es später erneut.
- **Nicht doppelt gutschreiben:** `receiptInfo.PurchaseId` in den Spielerdaten merken und vorher prüfen.
- `PromptProductPurchaseFinished` heißt *nicht*, dass gekauft wurde – nie darauf Items vergeben.
- ProfileStore hat dafür eine fertige Hilfe (siehe [[Daten-Speichern]]).
- Im Creator Hub zeigt ein Banner, wenn ProcessReceipt fehlerhaft ist. Testkäufe im veröffentlichten Spiel kosten echte Robux → mit billigen Produkten testen (in Studio sind Käufe Testkäufe).

## Was sich in Top-Spielen bewährt (siehe [[Items-Loot]])

- Zwei Preise nebeneinander: Spielgeld (grün) und Robux (lila) – alles ist auch ohne Robux erreichbar, nur langsamer.
- Mengenstufen (1 / 3 / 10) mit durchgestrichenem Preis beim großen Paket, Geschenk-Button daneben.
- Game Pass für Komfort (Tempo x2, Auto-Sammeln), nicht für Spielsiege.
- Fair bleiben: Chancen offen anzeigen (wie die Ei-Shops), keine Tricks bei Preisen.
