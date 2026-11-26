# Architektur

Zurück: [[Roblox-Wissen]]

## Grundregel: Der Server entscheidet

- **Server** (Script in `ServerScriptService`): Geld, Inventar, Schaden, Käufe, Speichern, Gegner-KI. Alles, was zählt.
- **Client** (LocalScript in `StarterPlayerScripts` / `StarterGui`): Anzeige, Eingabe, Kamera, Effekte, Animationen von Deko.
- **Dem Client nie glauben:** Er darf nur *Wünsche* schicken („ich möchte X kaufen“), der Server prüft alles selbst (Geld, Abstand, Abklingzeit, ob das Item existiert).

## Ordner

| Ort | Inhalt |
|---|---|
| `ServerScriptService` | Server-Skripte + Server-Module (Daten, Shop, Kampf) |
| `ServerStorage` | Vorlagen, die nur der Server klont (Gegner, Haustiere, Items) |
| `ReplicatedStorage` | Geteilte Module (Item-Tabellen, Konstanten), `Remotes`-Ordner, Modelle, die Clients brauchen |
| `StarterPlayerScripts` | Client-Logik (Eingabe, Effekte) |
| `StarterGui` | UI (ScreenGuis) + deren LocalScripts |
| `Workspace` | Die Welt. Feste Teile `Anchored`, Ordner pro Gebiet (`Map/Hub`, `Map/Lava` …) |

**Daten-Tabellen einmal zentral** als ModuleScript in `ReplicatedStorage` (z. B. `Items`, `Haustiere`, `Welten`): Server nutzt sie zum Prüfen, Client zum Anzeigen. Preise/Werte nie doppelt pflegen.

## Kommunikation

- **RemoteEvent** Client → Server (Wunsch) und Server → Client (Meldung, Effekt).
- **RemoteFunction** nur Client → Server, wenn der Client eine Antwort braucht (nie Server → Client: hängt, wenn der Client nicht antwortet).
- **UnreliableRemoteEvent** für häufige, unwichtige Dinge (Effekte, Positionen) – darf verloren gehen.
- **Attribute** (`SetAttribute`) für Zustand an Objekten: werden automatisch zu den Clients repliziert, Client hört mit `GetAttributeChangedSignal`. Gut für Boss-Zustand, HP, „Ei bereit“. (So läuft der Lavadrache-Bosskampf.)
- **Spielerwerte für die Anzeige:** Server setzt Attribute am Player (`Geld`, `Level`) → UI hört darauf. Kein eigenes Remote nötig.

Beispiel – Kauf-Wunsch prüfen:

```lua
Remotes.Kaufen.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" then return end
	local item = Items[itemId]
	if not item then return end
	local daten = Spielerdaten.holen(player)
	if not daten or daten.Geld < item.Preis then return end
	daten.Geld -= item.Preis
	table.insert(daten.Inventar, itemId)
	player:SetAttribute("Geld", daten.Geld)
end)
```

## Arbeitsweise mit Claude (MCP)

- Skripte liegen als Dateien im Projektordner (z. B. `Himmelsinseln/Scripts/*.server.lua`) = **Quelle der Wahrheit**. Eingespielt per `execute_luau`; Änderungen in Studio immer zurück in die Dateien.
- Studio-ID ändert sich bei jedem Neustart → zuerst `list_roblox_studios`.
- Große Bauten per Skript in Schleifen mit `task.wait()`, sonst Timeout.
- Kontrolle per `screen_capture` mit gesetzter Kamera.
