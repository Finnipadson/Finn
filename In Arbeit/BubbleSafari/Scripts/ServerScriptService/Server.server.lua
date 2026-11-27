-- Bubble Safari: Server (Script in ServerScriptService)
-- Der Server entscheidet alles: Training, Weite, Glueck, Tier, Geld. Client zeigt nur an.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local D = require(RS:WaitForChild("Daten"))
local TM = require(RS:WaitForChild("TierModelle"))
local Spieldaten = require(script.Parent:WaitForChild("Spieldaten"))

local rng = Random.new()
local Map = workspace:WaitForChild("Map")
local Grund = Map:WaitForChild("Grundstuecke")

-- ===== Remotes =====
local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = RS
local function remote(name, klasse)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(klasse or "RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end
local R = {
	Pusten = remote("Pusten", "RemoteFunction"),
	TierAktion = remote("TierAktion"),
	BesteAufstellen = remote("BesteAufstellen"),
	SeifeKaufen = remote("SeifeKaufen"),
	SeifeAusruesten = remote("SeifeAusruesten"),
	TrainingStop = remote("TrainingStop"),
	Status = remote("Status"),
	Meldung = remote("Meldung"),
	LadenOeffnen = remote("LadenOeffnen"),
	TrainingTick = remote("TrainingTick", "UnreliableRemoteEvent"),
	StufeAuf = remote("StufeAuf"),
}

local function meldung(p, text, art)
	R.Meldung:FireClient(p, text, art or "info")
end

-- ===== Hilfen =====
local plotVon = {} -- [player] = Model Grundstueck
local einkommen = {} -- [player] = $/s
local gestoppt = {} -- [player] = true nach HALT, bis Kreis verlassen
local trainAcc = {}
local naechstesPusten = {}
local serie = {}

local function plot(nr) return Grund:FindFirstChild("Grundstueck" .. nr) end

local function anzahl(d, imGehege)
	local n = 0
	for _, t in d.Tiere do
		if (t.gehege == true) == imGehege then n += 1 end
	end
	return n
end

local function findeTier(d, id)
	for i, t in d.Tiere do
		if t.id == id then return t, i end
	end
end

local function statusSenden(p)
	local d = Spieldaten.holen(p)
	if not d then return end
	R.Status:FireClient(p, {
		Tiere = d.Tiere, Seife = d.Seife, SeifenBesitz = d.SeifenBesitz, Plaetze = d.Plaetze,
		Index = d.Index, Blasebalg = d.Blasebalg,
	})
end

local function attributeSetzen(p)
	local d = Spieldaten.holen(p)
	if not d then return end
	p:SetAttribute("Geld", d.Geld)
	p:SetAttribute("Einkommen", einkommen[p] or 0)
	p:SetAttribute("Stufe", d.Stufe)
	p:SetAttribute("XP", d.XP)
	p:SetAttribute("XPBedarf", D.xpBedarf(d.Stufe))
	p:SetAttribute("Pustkraft", D.pustkraft(d.Stufe))
	p:SetAttribute("Blasebalg", d.Blasebalg)
	p:SetAttribute("Seife", d.Seife)
end

-- ===== Grundstueck: Anzeigen =====
local function billboard(anker, name, groesse, offset)
	local bb = anker:FindFirstChild(name)
	if bb then return bb end
	bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = groesse
	bb.StudsOffset = offset or Vector3.zero
	bb.MaxDistance = 260
	bb.LightInfluence = 0
	bb.Parent = anker
	local liste = Instance.new("UIListLayout")
	liste.HorizontalAlignment = Enum.HorizontalAlignment.Center
	liste.Parent = bb
	return bb
end
local function zeile(bb, name, hoehe, farbe)
	local t = bb:FindFirstChild(name)
	if t then return t end
	t = Instance.new("TextLabel")
	t.Name = name
	t.Size = UDim2.new(1, 0, hoehe, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = farbe or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(40, 40, 60)
	st.Parent = t
	t.Parent = bb
	return t
end

local function plotAnzeige(g, p)
	local bb = billboard(g.SchildAnker, "Anzeige", UDim2.fromOffset(320, 90))
	local n = zeile(bb, "Name", 0.55)
	local e = zeile(bb, "Einkommen", 0.45, Color3.fromRGB(120, 255, 120))
	if p then
		n.Text = p.DisplayName .. "s Safari"
		e.Text = "$" .. D.format(einkommen[p] or 0) .. "/s"
	else
		n.Text = "Freies Grundstück"
		e.Text = ""
	end
end

local function aufwertenAnzeige(g, stufe)
	local s = g.AufwertenSchild
	local bb = billboard(s, "Anzeige", UDim2.fromOffset(240, 80), Vector3.new(0, 3.5, 0))
	local n = zeile(bb, "Name", 0.5)
	local pr = zeile(bb, "Preis", 0.5, Color3.fromRGB(255, 220, 80))
	local naechste = D.Blasebaelge[stufe + 1]
	if naechste then
		n.Text = naechste.name
		pr.Text = "$" .. D.format(naechste.preis) .. " · +" .. naechste.xp .. " XP"
	else
		n.Text = D.Blasebaelge[stufe].name
		pr.Text = "Höchste Stufe"
	end
end

-- ===== Blasebalg bauen =====
local function teil(m, name, size, cf, farbe, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = farbe
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local function baueBlasebalg(g, stufe)
	local alt = g:FindFirstChild("Blasebalg")
	if alt then alt:Destroy() end
	local b = D.Blasebaelge[stufe]
	local m = Instance.new("Model")
	m.Name = "Blasebalg"
	m:SetAttribute("Stufe", stufe)
	local c = g.BlasebalgAnker.CFrame * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, math.rad(180), 0)
	local dunkel = b.farbe:Lerp(Color3.new(0, 0, 0), 0.35)
	teil(m, "Unterbrett", Vector3.new(7, 0.6, 5), c * CFrame.new(0, 0.3, 0), b.farbe, b.material)
	teil(m, "Balg", Vector3.new(6.4, 1.6, 4.4), c * CFrame.new(0, 1.4, 0), Color3.fromRGB(240, 235, 225), Enum.Material.Fabric)
	for i = -1, 1 do
		teil(m, "Falte", Vector3.new(6.6, 0.25, 4.6), c * CFrame.new(0, 1.4 + i * 0.5, 0), dunkel)
	end
	local deckel = teil(m, "Deckel", Vector3.new(7, 0.6, 5), c * CFrame.new(0, 2.5, 0), b.farbe, b.material)
	teil(m, "Griff", Vector3.new(1.2, 0.8, 1.2), c * CFrame.new(0, 3.2, 1.6), dunkel, b.material)
	teil(m, "Duese", Vector3.new(1.2, 1.2, 3), c * CFrame.new(0, 1.4, -3.6), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	m.PrimaryPart = deckel
	m.Parent = g
	aufwertenAnzeige(g, stufe)
end

-- ===== Gehege-Tiere =====
local function gehegeOrdner(g)
	local f = g:FindFirstChild("GehegeTiere")
	if not f then
		f = Instance.new("Folder")
		f.Name = "GehegeTiere"
		f.Parent = g
	end
	return f
end

local function tierAufstellen(g, tier)
	local f = gehegeOrdner(g)
	if f:FindFirstChild(tostring(tier.id)) then return end
	local m = TM.bauen(tier.art, tier.groesse, tier.material)
	if not m then return end
	m.Name = tostring(tier.id)
	local flaeche = g.GehegeFlaeche
	local s = flaeche.Size
	local x = rng:NextNumber(-s.X / 2 + 4, s.X / 2 - 4)
	local z = rng:NextNumber(-s.Z / 2 + 4, s.Z / 2 - 4)
	local oben = flaeche.CFrame * CFrame.new(x, s.Y / 2, z)
	m:PivotTo(CFrame.new(oben.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m:SetAttribute("TierId", tier.id)
	m:SetAttribute("Einkommen", D.einkommen(tier))
	local art = D.Tiere[tier.art]
	local bb = Instance.new("BillboardGui")
	bb.Name = "Schild"
	bb.Size = UDim2.fromOffset(160, 44)
	bb.StudsOffset = Vector3.new(0, TM.hoehe(m) + 1.5, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = m.PrimaryPart
	local l = Instance.new("UIListLayout")
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = bb
	local n = zeile(bb, "Name", 0.55, D.Seltenheit[art.selten].farbe)
	n.Text = art.name
	local e = zeile(bb, "Ek", 0.45, Color3.fromRGB(120, 255, 120))
	e.Text = "$" .. D.format(D.einkommen(tier)) .. "/s"
	m.Parent = f
end

local function tierEntfernen(g, id)
	local m = gehegeOrdner(g):FindFirstChild(tostring(id))
	if m then m:Destroy() end
end

local function einkommenNeu(p)
	local d = Spieldaten.holen(p)
	if not d then return end
	local e = 0
	for _, t in d.Tiere do
		if t.gehege then e += D.einkommen(t) end
	end
	einkommen[p] = e
	p:SetAttribute("Einkommen", e)
	local g = plotVon[p]
	if g then plotAnzeige(g, p) end
end

-- ===== Beitreten / Verlassen =====
local function freiesGrundstueck()
	for i = 1, 8 do
		local g = plot(i)
		if g and g:GetAttribute("Besitzer") == 0 then return g end
	end
end

local function grundstueckLeeren(g)
	g:SetAttribute("Besitzer", 0)
	gehegeOrdner(g):ClearAllChildren()
	baueBlasebalg(g, 1)
	plotAnzeige(g, nil)
end

local function spielerKommt(p)
	local d, fehler = Spieldaten.laden(p)
	if not d then
		if p.Parent then p:Kick("Deine Daten konnten nicht geladen werden. Bitte versuche es gleich noch einmal.") end
		return
	end
	if not p.Parent then return end
	local g = freiesGrundstueck()
	if not g then
		meldung(p, "Alle Grundstücke sind belegt.", "schlecht")
		return
	end
	g:SetAttribute("Besitzer", p.UserId)
	plotVon[p] = g
	p:SetAttribute("Grundstueck", g:GetAttribute("Nummer"))
	baueBlasebalg(g, d.Blasebalg)
	for _, t in d.Tiere do
		if t.gehege then tierAufstellen(g, t) end
	end
	einkommenNeu(p)
	attributeSetzen(p)
	statusSenden(p)
	if not Spieldaten.istSpeicherbar(p) then
		meldung(p, "Speichern ist gerade nicht möglich – dein Fortschritt wird nicht gesichert.", "schlecht")
	end
end

Players.PlayerAdded:Connect(spielerKommt)
for _, p in Players:GetPlayers() do task.spawn(spielerKommt, p) end

Players.PlayerRemoving:Connect(function(p)
	local g = plotVon[p]
	Spieldaten.entfernen(p)
	if g then grundstueckLeeren(g) end
	plotVon[p], einkommen[p], gestoppt[p], trainAcc[p], naechstesPusten[p], serie[p] = nil, nil, nil, nil, nil, nil
end)

for i = 1, 8 do
	local g = plot(i)
	if g then grundstueckLeeren(g) end
end

-- ===== Blasebalg aufwerten (Schild) =====
for i = 1, 8 do
	local g = plot(i)
	if not g then continue end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Aufwerten"
	pr.ObjectText = "Blasebalg"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = g.AufwertenSchild
	pr.Triggered:Connect(function(p)
		if plotVon[p] ~= g then
			meldung(p, "Das ist nicht dein Grundstück.", "schlecht")
			return
		end
		local d = Spieldaten.holen(p)
		local naechste = D.Blasebaelge[d.Blasebalg + 1]
		if not naechste then
			meldung(p, "Dein Blasebalg hat schon die höchste Stufe!", "info")
			return
		end
		if d.Geld < naechste.preis then
			meldung(p, "Nicht genug Geld! (" .. D.format(naechste.preis) .. " $)", "schlecht")
			return
		end
		d.Geld -= naechste.preis
		d.Blasebalg += 1
		baueBlasebalg(g, d.Blasebalg)
		attributeSetzen(p)
		statusSenden(p)
		meldung(p, "Auf " .. naechste.name .. " verbessert!", "gut")
	end)
end

-- ===== Seifenladen =====
do
	local laden = Map.Hub.Seifenladen
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Seifen ansehen"
	pr.ObjectText = "Seifenladen"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.Parent = laden.Theke
	pr.Triggered:Connect(function(p) R.LadenOeffnen:FireClient(p) end)
end

R.SeifeKaufen.OnServerEvent:Connect(function(p, i)
	local d = Spieldaten.holen(p)
	if not d or typeof(i) ~= "number" then return end
	local s = D.Seifen[i]
	if not s or d.SeifenBesitz[tostring(i)] then return end
	if d.Geld < s.preis then
		meldung(p, "Nicht genug Geld!", "schlecht")
		return
	end
	d.Geld -= s.preis
	d.SeifenBesitz[tostring(i)] = true
	d.Seife = i
	attributeSetzen(p)
	statusSenden(p)
	meldung(p, s.name .. " gekauft und ausgerüstet!", "gut")
end)

R.SeifeAusruesten.OnServerEvent:Connect(function(p, i)
	local d = Spieldaten.holen(p)
	if not d or typeof(i) ~= "number" or not d.SeifenBesitz[tostring(i)] then return end
	d.Seife = i
	attributeSetzen(p)
	statusSenden(p)
end)

-- ===== Tiere: Gehege / Rucksack / Verkaufen =====
R.TierAktion.OnServerEvent:Connect(function(p, id, aktion)
	local d = Spieldaten.holen(p)
	local g = plotVon[p]
	if not d or not g or typeof(id) ~= "number" or typeof(aktion) ~= "string" then return end
	local t, idx = findeTier(d, id)
	if not t then return end
	if aktion == "gehege" and not t.gehege then
		if anzahl(d, true) >= d.Plaetze then
			meldung(p, "Gehege voll! (" .. d.Plaetze .. "/" .. d.Plaetze .. ")", "schlecht")
			return
		end
		t.gehege = true
		tierAufstellen(g, t)
	elseif aktion == "raus" and t.gehege then
		if anzahl(d, false) >= D.RUCKSACK then
			meldung(p, "Rucksack voll!", "schlecht")
			return
		end
		t.gehege = false
		tierEntfernen(g, id)
	elseif aktion == "verkaufen" then
		local preis = D.verkaufspreis(t)
		d.Geld += preis
		if t.gehege then tierEntfernen(g, id) end
		table.remove(d.Tiere, idx)
		meldung(p, D.Tiere[t.art].name .. " verkauft: +$" .. D.format(preis), "gut")
	else
		return
	end
	einkommenNeu(p)
	attributeSetzen(p)
	statusSenden(p)
end)

R.BesteAufstellen.OnServerEvent:Connect(function(p)
	local d = Spieldaten.holen(p)
	local g = plotVon[p]
	if not d or not g then return end
	local sortiert = table.clone(d.Tiere)
	table.sort(sortiert, function(a, b) return D.einkommen(a) > D.einkommen(b) end)
	for i, t in sortiert do
		local soll = i <= d.Plaetze
		if soll and not t.gehege then
			t.gehege = true
			tierAufstellen(g, t)
		elseif not soll and t.gehege then
			t.gehege = false
			tierEntfernen(g, t.id)
		end
	end
	einkommenNeu(p)
	attributeSetzen(p)
	statusSenden(p)
	meldung(p, "Die besten Tiere stehen jetzt im Gehege!", "gut")
end)

-- ===== Training =====
R.TrainingStop.OnServerEvent:Connect(function(p)
	gestoppt[p] = true
	p:SetAttribute("Trainiert", false)
end)

local function imKreis(p, g)
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local k = g.TrainKreis.Position
	local d = hrp.Position - k
	return Vector2.new(d.X, d.Z).Magnitude < 7.5 and d.Y > -2 and d.Y < 9
end

local trainZeit = 0
RunService.Heartbeat:Connect(function(dt)
	trainZeit += dt
	if trainZeit < 0.1 then return end
	local schritt = trainZeit
	trainZeit = 0
	for p, g in plotVon do
		local d = Spieldaten.holen(p)
		if not d then continue end
		local drin = imKreis(p, g)
		if not drin then gestoppt[p] = nil end
		local aktiv = drin and not gestoppt[p]
		if p:GetAttribute("Trainiert") ~= aktiv then p:SetAttribute("Trainiert", aktiv) end
		if not aktiv then
			trainAcc[p] = 0
			continue
		end
		trainAcc[p] = (trainAcc[p] or 0) + schritt
		if trainAcc[p] >= D.WDH_ZEIT then
			trainAcc[p] -= D.WDH_ZEIT
			local plus = D.Blasebaelge[d.Blasebalg].xp
			d.XP += plus
			R.TrainingTick:FireClient(p, plus)
			while d.XP >= D.xpBedarf(d.Stufe) do
				d.XP -= D.xpBedarf(d.Stufe)
				local vorher = D.pustkraft(d.Stufe)
				d.Stufe += 1
				R.StufeAuf:FireClient(p, d.Stufe, D.pustkraft(d.Stufe) - vorher)
			end
			attributeSetzen(p)
		end
	end
end)

-- ===== Einkommen =====
task.spawn(function()
	while true do
		task.wait(1)
		for p in plotVon do
			local d = Spieldaten.holen(p)
			if d and (einkommen[p] or 0) > 0 then
				d.Geld += einkommen[p]
				p:SetAttribute("Geld", d.Geld)
			end
		end
	end
end)

-- ===== Pusten =====
local function ziehen(liste)
	local r = rng:NextNumber()
	for _, e in liste do
		r -= e.p
		if r <= 0 then return e end
	end
	return liste[#liste]
end

R.Pusten.OnServerInvoke = function(p, zeiger)
	local d = Spieldaten.holen(p)
	local g = plotVon[p]
	if not d or not g then return { fehler = "Noch nicht bereit." } end
	if typeof(zeiger) ~= "number" or zeiger ~= zeiger then return { fehler = "Ungültig." } end
	if os.clock() < (naechstesPusten[p] or 0) then return { fehler = "Warte, bis deine Blase zurück ist." } end
	local platte = Map:FindFirstChild("Wurfplatz") and Map.Wurfplatz:FindFirstChild("Platte")
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not platte or not hrp then return { fehler = "Stell dich auf den Wurfplatz." } end
	local abstand = platte.CFrame:PointToObjectSpace(hrp.Position)
	if math.abs(abstand.X) > platte.Size.X / 2 + 2 or math.abs(abstand.Z) > platte.Size.Z / 2 + 2 then
		return { fehler = "Stell dich auf den Wurfplatz." }
	end
	if anzahl(d, false) >= D.RUCKSACK then
		return { fehler = "Rucksack voll! Stelle Tiere ins Gehege oder verkaufe sie." }
	end

	-- TODO Phase 5: Zeiger-Zeitpunkt serverseitig pruefen (jetzt max. x1,15 Vorteil)
	local faktor, qText = D.qualitaet(math.clamp(zeiger, 0, 1))
	serie[p] = if qText == "PERFEKT!" then math.min((serie[p] or 0) + 1, 5) else 0
	local w = math.clamp(D.weite(d.Stufe, d.Seife, faktor), 40, D.TAL_ENDE - 30)
	local biom, g0 = D.biomBei(w)
	local glueck = g0 * (1 + D.Seifen[d.Seife].glueck + serie[p] * 0.1)
	local liste = D.chancen(biom.id, glueck)
	local wahl
	if not d.ErsterFang then
		d.ErsterFang = true
		wahl = { id = "Wiesenhase", p = 1 }
		for _, e in liste do if e.id == "Wiesenhase" then wahl = e end end
	else
		wahl = ziehen(liste)
	end
	local tier = { id = d.NaechsteId, art = wahl.id, groesse = 1, material = 1, gehege = false }
	d.NaechsteId += 1
	table.insert(d.Tiere, tier)
	local neu = not d.Index[wahl.id]
	d.Index[wahl.id] = true
	local dauer = D.flugDauer(w)
	naechstesPusten[p] = os.clock() + dauer + 4
	statusSenden(p)
	local art = D.Tiere[wahl.id]
	return {
		ok = true, weite = w, biom = biom.id, biomName = biom.name, glueck = glueck, art = wahl.id, name = art.name,
		selten = art.selten, chance = math.max(1, math.floor(1 / wahl.p + 0.5)), quali = qText, serie = serie[p],
		dauer = dauer, neu = neu, tierId = tier.id, drift = rng:NextNumber(-25, 25), einkommen = D.einkommen(tier),
		groesse = 1, material = 1,
	}
end

print("Bubble Safari Server bereit")
