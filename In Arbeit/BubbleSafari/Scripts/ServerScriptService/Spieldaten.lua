-- Bubble Safari: Spielerdaten laden/speichern (ModuleScript in ServerScriptService)
-- UpdateAsync + einfacher Session-Lock. Spaeter evtl. ProfileStore (siehe Roblox-Wissen/Daten-Speichern).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local M = {}
local STORE_NAME = "BubbleSafari_v1"
local LOCK_ZEIT = 1800 -- s: aelterer Lock gilt als verwaist

local STANDARD = {
	Version = 1,
	Geld = 0,
	XP = 0,
	Stufe = 1,
	Blasebalg = 1,
	Seife = 1,
	SeifenBesitz = { ["1"] = true }, -- String-Schluessel: DataStore mag keine Luecken in Arrays
	Plaetze = 6,
	Tiere = {}, -- { id, art, groesse, material, gehege }
	Index = {},
	NaechsteId = 1,
	ErsterFang = false,
	Tutorial = 1, -- 1 Blasebalg, 2 Pusten, 3 Gehege, 4 fertig
	Einstellungen = { Schnell = false },
	IndexBelohnt = {},
}

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = s end
end

local cache = {} -- [player] = daten
local speicherbar = {} -- [player] = bool

local function tiefKopie(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in v do t[k] = tiefKopie(x) end
	return t
end

local function ergaenzen(d)
	for k, v in STANDARD do
		if d[k] == nil then d[k] = tiefKopie(v) end
	end
	return d
end

local function schluessel(player) return "Spieler_" .. player.UserId end

function M.laden(player)
	if not store then
		speicherbar[player] = false
		cache[player] = ergaenzen({})
		return cache[player], "kein DataStore"
	end
	for versuch = 1, 8 do
		local gesperrt = false
		local ok, ergebnis = pcall(function()
			return store:UpdateAsync(schluessel(player), function(alt)
				alt = alt or {}
				local lock = alt.Lock
				if lock and lock.job ~= game.JobId and os.time() - (lock.zeit or 0) < LOCK_ZEIT then
					gesperrt = true
					return nil -- abbrechen, nichts schreiben
				end
				alt.Lock = { job = game.JobId, zeit = os.time() }
				return alt
			end)
		end)
		if not player.Parent then return nil, "weg" end
		if ok and ergebnis and not gesperrt then
			local d = ergaenzen(ergebnis)
			d.Lock = nil
			cache[player] = d
			speicherbar[player] = true
			return d
		end
		task.wait(if gesperrt then 5 else 2)
	end
	return nil, "Laden fehlgeschlagen"
end

function M.holen(player)
	return cache[player]
end

function M.speichern(player, freigeben)
	local d = cache[player]
	if not d or not speicherbar[player] or not store then return false end
	local kopie = tiefKopie(d)
	local ok, err = pcall(function()
		store:UpdateAsync(schluessel(player), function(alt)
			if alt and alt.Lock and alt.Lock.job ~= game.JobId then
				return nil -- anderer Server hat uebernommen
			end
			kopie.Lock = if freigeben then nil else { job = game.JobId, zeit = os.time() }
			return kopie
		end)
	end)
	if not ok then warn("Speichern fehlgeschlagen", player.Name, err) end
	return ok
end

function M.entfernen(player)
	M.speichern(player, true)
	cache[player] = nil
	speicherbar[player] = nil
end

function M.istSpeicherbar(player)
	return speicherbar[player] == true
end

-- Auto-Speichern
task.spawn(function()
	while true do
		task.wait(120)
		for _, p in Players:GetPlayers() do
			if cache[p] then task.spawn(M.speichern, p, false) end
		end
	end
end)

game:BindToClose(function()
	local offen = 0
	for _, p in Players:GetPlayers() do
		if cache[p] then
			offen += 1
			task.spawn(function()
				M.speichern(p, true)
				offen -= 1
			end)
		end
	end
	local start = os.clock()
	while offen > 0 and os.clock() - start < 25 do task.wait(0.2) end
end)

return M
