# System-Rezepte

Zurück: [[Roblox-Wissen]] · Aussehen: [[Design-Bibliothek]]

Bewährte Aufbauten für Systeme aus Top-Roblox-Spielen. Kein fertiger Code – das Muster plus die entscheidenden Zeilen.

## Zufall mit Gewichtung (Ei öffnen, Kiste, Drop)

Chancen in der Daten-Tabelle, die auch der Shop anzeigt (Prozente offen zeigen, siehe Ei-Shop in [[Items-Loot]]). Gezogen wird **nur auf dem Server**.

```lua
local rng = Random.new()

local function ziehen(liste) -- { {id = "Hund", gewicht = 39}, {id = "Loewe", gewicht = 0.5}, ... }
	local summe = 0
	for _, e in liste do summe += e.gewicht end
	local r = rng:NextNumber() * summe
	for _, e in liste do
		r -= e.gewicht
		if r <= 0 then return e.id end
	end
	return liste[#liste].id
end
```

Ablauf Ei: Server zieht → speichert → setzt Attribut am Ei `Bereit = true` → Client spielt Schlüpf-Effekt ([[Game-Feel]]) → Haustier erscheint.

## Shop mit Restock-Timer (für alle Server gleich)

Statt eines Timers pro Server: Die „Runde“ aus der Uhrzeit berechnen. Dann haben alle Server dasselbe Angebot und denselben Countdown, ohne DataStore.

```lua
local INTERVALL = 300 -- 5 Minuten

local function runde() return os.time() // INTERVALL end
local function restSekunden() return INTERVALL - os.time() % INTERVALL end

local function angebot(r) -- gleiche Runde = gleiches Angebot
	local zufall = Random.new(r)
	-- z. B. pro Saat: Vorrat = zufall:NextInteger(0, 10); seltene oft 0
end
```

Vorrat pro Spieler zählen (in den Spielerdaten mit Rundennummer), damit jeder Spieler eigenen Vorrat hat. Client zeigt `restSekunden()` als Countdown; bei Rundenwechsel Meldung „Shop wieder aufgefüllt!“.

## Laufband mit Multiplikator (Keyboard Escape)

- Jedes Laufband ist ein Modell mit Attribut `Multi` (1, 3, 10 …) und Preis-Schild.
- Server prüft alle ~0,2 s, wer auf welchem Band steht (`workspace:GetPartBoundsInBox` über der Lauffläche oder Touched/TouchEnded mit Zähler), und gibt `Basiswert * Multi * Boosts` gut.
- Client: Textur der Lauffläche bewegt sich (`Texture.OffsetStudsV` ändern), fliegende Zahlen „+3.75T“ (siehe unten), Lauf-Animation.
- Große Zahlen kurz formatieren (K, M, B, T, Qa …).

## Haustier folgt dem Spieler

- Haustier-Modelle werden **auf jedem Client lokal** bewegt (spart Server und Netz): Server legt nur fest, welche Haustiere ein Spieler ausgerüstet hat (Attribut/Ordner am Player).
- Client: pro Haustier jeden Frame (`RunService.RenderStepped`) die Ziel-Position hinter dem Spieler berechnen (versetzt im Halbkreis), weich hinziehen (`CFrame:Lerp`), leicht hüpfen (`math.sin(zeit)`).
- Modelle verankert (`Anchored`), `CanCollide = false`.

## Sammelbuch / Index (Steal An Egg)

- Daten: `Index = { Hund = true, ... }` in den Spielerdaten, eingetragen beim ersten Erhalt.
- Pro Gebiet eine Liste in der Daten-Tabelle; UI zeigt fehlende als Silhouette (`ImageColor3` schwarz) mit „???“, Hintergrund in Seltenheitsfarbe.
- Belohnung pro Gebiet bei voll (Merker `IndexBelohnt.Wald = true`, damit nicht doppelt).

## Tägliche Login-Belohnung (Rivals)

```lua
local tag = os.time() // 86400 -- UTC-Tag
if daten.LetzterLogin < tag then
	daten.LoginTag = if daten.LetzterLogin == tag - 1 then daten.LoginTag % 7 + 1 else 1
	daten.LetzterLogin = tag
	-- Belohnung für daten.LoginTag geben, Tag 7 = großer Preis
end
```

(Ob eine verpasste Tag-Serie wieder bei 1 anfängt, ist eine Design-Entscheidung.)

## Grundstücke zuweisen (Gehege, Basis)

- Feste Grundstücke im Workspace (`Map/Grundstuecke/1..8`), Attribut `Besitzer` (UserId oder 0).
- Beim Beitreten freies Grundstück vergeben, Namensschild setzen, gespeicherte Sachen des Spielers darauf aufbauen. Beim Verlassen leeren und freigeben.
- Server-Max-Spieler = Anzahl Grundstücke.

## Fliegende Zahlen

- Client erzeugt ein `BillboardGui` mit `TextLabel` an der Position, tweent nach oben + `TextTransparency` auf 1, löscht nach ~0,8 s.
- Viele gleichzeitig: Objekte wiederverwenden (Pool), Anzahl deckeln (z. B. max. 15).
- Server schickt nur den Wert per `UnreliableRemoteEvent` oder der Client berechnet ihn aus der Änderung des Geld-Attributs.

## Portal / Tor mit Anforderung

- Tor-Modell mit Attributen `BenoetigtLevel` oder `Preis` und `Ziel` (Name des Spawn-Punkts).
- Server prüft beim Berühren (mit Abklingzeit pro Spieler) und teleportiert per `PivotTo`; sonst Meldung „Benötigt Level 15“. Schild zeigt die Anforderung schon vorher (siehe [[Welt-Map]]).
- Für Himmelsinseln: `Weg/BossTor` hat schon `BenoetigtLevel = 15`.
