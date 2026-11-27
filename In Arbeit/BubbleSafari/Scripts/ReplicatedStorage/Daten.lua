-- Bubble Safari: zentrale Daten-Tabellen + Formeln (ModuleScript in ReplicatedStorage)
-- Werte = Startwerte aus bubblesafari-plan.md; Aenderungen dort nachtragen.
local D = {}

D.TAL_ENDE = 2400 -- Phase 1: Tal endet nach dem Sumpf
D.RUCKSACK = 10
D.START_PLAETZE = 6
D.WDH_ZEIT = 0.8 -- Sekunden pro Blasebalg-Tritt

D.Biome = {
	{ id = "Wiese", name = "Blumenwiese", von = 0, bis = 600, gVon = 1, gBis = 2, basis = 1 },
	{ id = "Pilzwald", name = "Pilzwald", von = 600, bis = 1400, gVon = 2, gBis = 4, basis = 6 },
	{ id = "Sumpf", name = "Sumpf", von = 1400, bis = 2400, gVon = 4, gBis = 7, basis = 40 },
}

D.Seltenheit = {
	Gewoehnlich = { name = "Gewöhnlich", mult = 1, rang = 1, farbe = Color3.fromRGB(255, 255, 255) },
	Ungewoehnlich = { name = "Ungewöhnlich", mult = 2, rang = 2, farbe = Color3.fromRGB(110, 230, 110) },
	Selten = { name = "Selten", mult = 5, rang = 3, farbe = Color3.fromRGB(90, 170, 255) },
	Episch = { name = "Episch", mult = 12, rang = 4, farbe = Color3.fromRGB(190, 110, 255) },
	Legendaer = { name = "Legendär", mult = 30, rang = 5, farbe = Color3.fromRGB(255, 200, 50) },
	Mythisch = { name = "Mythisch", mult = 100, rang = 6, farbe = Color3.fromRGB(255, 90, 170) },
}
D.Grundgewicht = { Gewoehnlich = 30, Ungewoehnlich = 25, Selten = 10, Episch = 4, Legendaer = 0.9, Mythisch = 0.1 }

-- Reihenfolge = Index-Reihenfolge
D.TierListe = {
	{ id = "Wiesenhase", name = "Wiesenhase", biom = "Wiese", selten = "Gewoehnlich" },
	{ id = "Bluetenlamm", name = "Blütenlamm", biom = "Wiese", selten = "Gewoehnlich" },
	{ id = "Blumenigel", name = "Blumenigel", biom = "Wiese", selten = "Ungewoehnlich" },
	{ id = "Pusteblumenfuchs", name = "Pusteblumen-Fuchs", biom = "Wiese", selten = "Selten" },
	{ id = "Bluetenhirsch", name = "Blütenhirsch", biom = "Wiese", selten = "Episch" },
	{ id = "Rosenpfau", name = "Rosenpfau", biom = "Wiese", selten = "Legendaer" },
	{ id = "Fruehlingseinhorn", name = "Frühlings-Einhorn", biom = "Wiese", selten = "Mythisch" },
	{ id = "Moosmaus", name = "Moosmaus", biom = "Pilzwald", selten = "Gewoehnlich" },
	{ id = "Fliegenpilzkroete", name = "Fliegenpilz-Kröte", biom = "Pilzwald", selten = "Gewoehnlich" },
	{ id = "Pilzhutwaschbaer", name = "Pilzhut-Waschbär", biom = "Pilzwald", selten = "Ungewoehnlich" },
	{ id = "Moosdachs", name = "Moos-Dachs", biom = "Pilzwald", selten = "Selten" },
	{ id = "Glimmereule", name = "Glimmer-Eule", biom = "Pilzwald", selten = "Episch" },
	{ id = "Pilzkoenigbaer", name = "Pilzkönig-Bär", biom = "Pilzwald", selten = "Legendaer" },
	{ id = "Wurzelgeistelch", name = "Wurzelgeist-Elch", biom = "Pilzwald", selten = "Mythisch" },
	{ id = "Seerosenfrosch", name = "Seerosen-Frosch", biom = "Sumpf", selten = "Gewoehnlich" },
	{ id = "Schilfente", name = "Schilf-Ente", biom = "Sumpf", selten = "Gewoehnlich" },
	{ id = "Moosschildkroete", name = "Moos-Schildkröte", biom = "Sumpf", selten = "Ungewoehnlich" },
	{ id = "Nebelotter", name = "Nebelotter", biom = "Sumpf", selten = "Selten" },
	{ id = "Seerosenkrokodil", name = "Seerosen-Krokodil", biom = "Sumpf", selten = "Episch" },
	{ id = "Irrlichtreiher", name = "Irrlicht-Reiher", biom = "Sumpf", selten = "Legendaer" },
	{ id = "Nebelschlange", name = "Nebelschlange", biom = "Sumpf", selten = "Mythisch" },
}
D.Tiere = {}
for _, t in D.TierListe do D.Tiere[t.id] = t end

D.Seifen = {
	{ name = "Kernseife", preis = 0, weite = 1.0, glueck = 0, farbe = Color3.fromRGB(235, 245, 255) },
	{ name = "Honigseife", preis = 500, weite = 1.3, glueck = 0, farbe = Color3.fromRGB(255, 200, 70) },
	{ name = "Minzseife", preis = 15000, weite = 1.7, glueck = 0.10, farbe = Color3.fromRGB(110, 240, 190) },
}

D.Blasebaelge = {
	{ name = "Holz-Blasebalg", preis = 0, xp = 2, farbe = Color3.fromRGB(160, 110, 60), material = Enum.Material.WoodPlanks },
	{ name = "Kupfer-Blasebalg", preis = 2500, xp = 8, farbe = Color3.fromRGB(200, 120, 70), material = Enum.Material.Metal },
	{ name = "Lila-Samt-Blasebalg", preis = 60000, xp = 20, farbe = Color3.fromRGB(150, 80, 210), material = Enum.Material.Fabric },
}

D.Groessen = { { name = "", skala = 1, mult = 1 }, { name = "GROSS", skala = 1.6, mult = 4 }, { name = "RIESIG", skala = 2.6, mult = 9 } }

-- Groesse ist ein eigener Zufallswurf; Glueck erhoeht ihn leicht (max. 25 % / 5 %)
function D.groessenChancen(glueck)
	local f = math.sqrt(math.max(glueck, 1))
	local riesig = math.min(0.015 * f, 0.05)
	local gross = math.min(0.085 * f, 0.25)
	return { 1 - gross - riesig, gross, riesig }
end

-- Gehege-Ausbau: Stufe i -> Plaetze + Preis
D.Ausbau = {
	{ plaetze = 8, preis = 1000 },
	{ plaetze = 10, preis = 25000 },
	{ plaetze = 12, preis = 500000 },
	{ plaetze = 14, preis = 10e6 },
	{ plaetze = 16, preis = 200e6 },
	{ plaetze = 18, preis = 4e9 },
	{ plaetze = 20, preis = 80e9 },
}
function D.naechsterAusbau(plaetze)
	for _, a in D.Ausbau do
		if a.plaetze > plaetze then return a end
	end
end
-- Gehege-Tiefe (Studs) je nach Platzanzahl
function D.gehegeTiefe(plaetze)
	return 30 + (plaetze - 6) * 2.6
end

-- Belohnung fuer ein volles Biom im Index
D.IndexBelohnung = { Wiese = 2500, Pilzwald = 25000, Sumpf = 250000 }
D.Materialien = { { name = "", mult = 1 }, { name = "GOLD", mult = 4 }, { name = "DIAMANT", mult = 15 }, { name = "REGENBOGEN", mult = 50 } }

function D.pustkraft(stufe)
	local s = stufe - 1
	return 10 + 2 * s + 0.05 * s * s
end

function D.xpBedarf(stufe)
	return stufe * stufe + 5 * stufe
end

-- Zeiger 0..1 (unten..oben) -> Faktor, Text
function D.qualitaet(z)
	if z >= 0.84 and z <= 0.96 then return 1.15, "PERFEKT!" end
	if z >= 0.45 then return 1.0, "GUT" end
	return 0.7, "SCHWACH"
end

function D.weite(stufe, seife, faktor)
	return D.pustkraft(stufe) * 10 * D.Seifen[seife].weite * faktor
end

function D.biomBei(w)
	w = math.clamp(w, 0, D.TAL_ENDE - 1)
	for _, b in D.Biome do
		if w < b.bis then
			local a = (w - b.von) / (b.bis - b.von)
			return b, b.gVon + (b.gBis - b.gVon) * a
		end
	end
	local b = D.Biome[#D.Biome]
	return b, b.gBis
end

-- Chancen aller Arten eines Bioms bei gegebenem Glueck: { {id, p}, ... }
function D.chancen(biomId, glueck)
	local liste, summe = {}, 0
	for _, t in D.TierListe do
		if t.biom == biomId then
			local g = D.Grundgewicht[t.selten]
			if t.selten == "Ungewoehnlich" then
				g *= math.sqrt(glueck)
			elseif t.selten ~= "Gewoehnlich" then
				g *= glueck
			end
			table.insert(liste, { id = t.id, g = g })
			summe += g
		end
	end
	for _, e in liste do e.p = e.g / summe end
	return liste
end

function D.flugDauer(w)
	return 3 + 7 * math.sqrt(math.clamp(w, 0, 10400) / 10400)
end

function D.einkommen(tier)
	local art = D.Tiere[tier.art]
	if not art then return 0 end
	local biom = 1
	for _, b in D.Biome do if b.id == art.biom then biom = b.basis end end
	return biom * D.Seltenheit[art.selten].mult * D.Groessen[tier.groesse or 1].mult * D.Materialien[tier.material or 1].mult
end

function D.verkaufspreis(tier)
	return math.floor(D.einkommen(tier) * 30)
end

local KUERZEL = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }
function D.format(n)
	n = math.floor(n + 0.5)
	if n < 1000 then return tostring(n) end
	local i = 1
	while n >= 1000 and i < #KUERZEL do n /= 1000; i += 1 end
	local s = if n < 10 then string.format("%.2f", n) elseif n < 100 then string.format("%.1f", n) else string.format("%d", math.floor(n))
	if s:find("%.") then
		s = (s:gsub("0+$", ""))
		s = (s:gsub("%.$", ""))
	end
	return (s:gsub("%.", ",")) .. KUERZEL[i]
end

return D
