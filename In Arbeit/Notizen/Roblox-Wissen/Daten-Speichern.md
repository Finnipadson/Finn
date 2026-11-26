# Daten-Speichern

Zurück: [[Roblox-Wissen]]

Spielerdaten verlieren oder Items verdoppeln ist der schlimmste Fehler in Roblox-Spielen. Deshalb nicht selbst „schnell“ bauen.

## Empfehlung

- **ProfileStore** (Community-Modul von MadStudio, Nachfolger von ProfileService) nutzen. Es bringt Session-Lock, Auto-Speichern und Hilfen für Robux-Käufe schon mit. Aktuelle Version und API vor dem Einbau auf der ProfileStore-Seite prüfen.
- Wenn selbst gebaut, dann nach der offiziellen Anleitung „Implement player data and purchasing systems“ im Creator Hub.

## Regeln (gelten auch mit Modul)

- **UpdateAsync statt SetAsync** – liest den aktuellen Stand und schreibt nur, wenn es passt; verhindert, dass ein Server alte Daten über neue schreibt.
- **Session-Lock:** Daten eines Spielers dürfen nur auf *einem* Server gleichzeitig geladen sein. Sonst: Server wechseln → alter Server speichert alte Daten → Verlust oder doppelte Items.
- **Auto-Speichern** regelmäßig (Beispiel in der offiziellen Doku: alle 180 s), dazu beim Verlassen (`PlayerRemoving`) und beim Herunterfahren (`game:BindToClose`).
- **Fehlschläge einplanen:** Anfragen in `pcall`, mit Wiederholung. Wenn Laden fehlschlägt: Spieler *nicht* mit leeren Daten spielen lassen (sonst wird leer gespeichert) – lieber Hinweis + erneut versuchen oder kicken.
- **Eine Tabelle pro Spieler** mit Versionsnummer, Standardwerte beim ersten Laden ergänzen (neue Felder in Updates):

```lua
local STANDARD = { Version = 1, Geld = 0, Level = 1, XP = 0, Inventar = {}, Index = {}, LetzterLogin = 0, LoginTag = 0 }

local function ergaenzen(daten)
	for k, v in STANDARD do
		if daten[k] == nil then
			daten[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
	return daten
end
```

- **In Studio testen:** „Studio Access to API Services“ in den Spieleinstellungen an, sonst geht DataStore im Playtest nicht.
