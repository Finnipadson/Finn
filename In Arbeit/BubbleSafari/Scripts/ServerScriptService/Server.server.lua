-- Bubble Safari: Server (Script in ServerScriptService)
-- Der Server entscheidet alles: Training, Weite, Glueck, Tier, Geld. Client zeigt nur an.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
	X2Angebot = remote("X2Angebot"),
	X2Nehmen = remote("X2Nehmen"),
	X2Aktiv = remote("X2Aktiv"),
	Einstellung = remote("Einstellung"),
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
		Index = d.Index, Blasebalg = d.Blasebalg, IndexBelohnt = d.IndexBelohnt, Einstellungen = d.Einstellungen,
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
	p:SetAttribute("Tutorial", d.Tutorial)
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
	local bb = billboard(g.SchildAnker, "Anzeige", UDim2.fromOffset(380, 150))
	bb.MaxDistance = 320
	local z = zeile(bb, "Zahl", 0.48)
	local e = zeile(bb, "Einkommen", 0.42, Color3.fromRGB(120, 255, 120))
	local d = p and Spieldaten.holen(p)
	if p and d then
		z.Text = anzahl(d, true) .. " / " .. d.Plaetze
		e.Text = "$" .. D.format(einkommen[p] or 0) .. "/s"
	else
		z.Text, e.Text = "", ""
	end
	local ns = g:FindFirstChild("NamensSchild")
	if ns then
		local sg = ns:FindFirstChild("Text")
		if not sg then
			sg = Instance.new("SurfaceGui")
			sg.Name = "Text"
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 30
			sg.Parent = ns
			local t = zeile(sg, "Zeile", 1, Color3.fromRGB(255, 245, 220))
			t.Size = UDim2.fromScale(0.94, 0.9)
			t.Position = UDim2.fromScale(0.03, 0.05)
		end
		sg.Zeile.Text = if p then p.DisplayName .. "s Safari" else "Freies Grundstück"
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
	n.Text = art.name .. (if (tier.groesse or 1) > 1 then " · " .. D.Groessen[tier.groesse].name else "")
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

-- ===== Gehege bauen / ausbauen =====
local function gehegeMasse(g, plaetze)
	local cx = g.Boden.Position.X
	local z1 = g.Boden.Position.Z - 35
	return cx, z1, D.gehegeTiefe(plaetze)
end

local function zaunBauen(g, plaetze)
	local alt = g:FindFirstChild("Zaun")
	if alt then alt:Destroy() end
	local zaun = Instance.new("Folder")
	zaun.Name = "Zaun"
	local cx, z1, tiefe = gehegeMasse(g, plaetze)
	local x1, x2, z2, y = cx - 31, cx + 1, z1 + tiefe, 0.7
	local pfostenFarbe, latteFarbe = Color3.fromRGB(95, 60, 35), Color3.fromRGB(150, 98, 58)
	local function stueck(a, b, name)
		local d = b - a
		local n = math.max(1, math.floor(d.Magnitude / 5))
		for k = 0, n do
			local pf = teil(zaun, name, Vector3.new(1.2, 4.6, 1.2), CFrame.new(a + d * (k / n) + Vector3.new(0, 2.3, 0)), pfostenFarbe, Enum.Material.Wood)
			pf.CanCollide = true
		end
		local mitte = (a + b) / 2
		for _, h in { 1.6, 3.5 } do
			local l = teil(zaun, name, Vector3.new(0.6, 0.8, d.Magnitude), CFrame.lookAt(mitte + Vector3.new(0, h, 0), mitte + Vector3.new(0, h, 0) + d.Unit), latteFarbe, Enum.Material.Wood)
			l.CanCollide = true
		end
	end
	stueck(Vector3.new(x1, y, z1), Vector3.new(x2, y, z1), "Hinten")
	stueck(Vector3.new(x1, y, z2), Vector3.new(x2, y, z2), "Vorne")
	stueck(Vector3.new(x1, y, z1), Vector3.new(x1, y, z2), "Seite")
	stueck(Vector3.new(x2, y, z1), Vector3.new(x2, y, z1 + 8), "Seite")
	stueck(Vector3.new(x2, y, z1 + 16), Vector3.new(x2, y, z2), "Seite")
	zaun.Parent = g
end

local function ausbauAnzeige(g, plaetze)
	local s = g:FindFirstChild("AusbauSchild")
	if not s then return end
	local bb = billboard(s, "Anzeige", UDim2.fromOffset(260, 80), Vector3.new(0, 3.5, 0))
	local n = zeile(bb, "Name", 0.5)
	local pr = zeile(bb, "Preis", 0.5, Color3.fromRGB(255, 220, 80))
	local a = D.naechsterAusbau(plaetze)
	if a then
		n.Text = "Gehege " .. plaetze .. " > " .. a.plaetze .. " Plätze"
		pr.Text = "$" .. D.format(a.preis)
	else
		n.Text = "Gehege " .. plaetze .. " Plätze"
		pr.Text = "Voll ausgebaut"
	end
end

local function baueGehege(g, plaetze, animiert)
	local cx, z1, tiefe = gehegeMasse(g, plaetze)
	local cf, size = CFrame.new(cx - 15, 0.7, z1 + tiefe / 2), Vector3.new(32, 0.4, tiefe)
	local fl = g:FindFirstChild("GehegeFlaeche")
	if not fl then
		fl = teil(g, "GehegeFlaeche", size, cf, Color3.fromRGB(120, 205, 90))
		animiert = false
	end
	if animiert then
		local delta = size.Z - fl.Size.Z
		local info = TweenInfo.new(1.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(fl, info, { CFrame = cf, Size = size }):Play()
		local zaun = g:FindFirstChild("Zaun")
		if zaun then
			for _, t in zaun:GetChildren() do
				if t.Name == "Vorne" then TweenService:Create(t, info, { CFrame = t.CFrame + Vector3.new(0, 0, delta) }):Play() end
			end
		end
		task.delay(1.6, function() zaunBauen(g, plaetze) end)
	else
		fl.CFrame, fl.Size = cf, size
		zaunBauen(g, plaetze)
	end
	ausbauAnzeige(g, plaetze)
end

local function grundstueckLeeren(g)
	g:SetAttribute("Besitzer", 0)
	gehegeOrdner(g):ClearAllChildren()
	baueBlasebalg(g, 1)
	baueGehege(g, D.START_PLAETZE)
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
	if d.ErsterFang and d.Tutorial < 4 then d.Tutorial = 4 end
	baueBlasebalg(g, d.Blasebalg)
	baueGehege(g, d.Plaetze)
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

for standName, art in { VerkaufStand = "tiere", IndexStand = "index" } do
	local st = Map.Hub:FindFirstChild(standName)
	if st then
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = if art == "tiere" then "Tiere verkaufen" else "Index ansehen"
		pr.ObjectText = if art == "tiere" then "Verkaufen" else "Tier-Index"
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 14
		pr.RequiresLineOfSight = false
		pr.Parent = st.Theke
		pr.Triggered:Connect(function(p) R.LadenOeffnen:FireClient(p, art) end)
	end
end

do -- Bestenliste mit den hoechsten Einkommen auf diesem Server
	local bl = Map.Hub:FindFirstChild("Bestenliste")
	local tafel = bl and bl:FindFirstChild("Tafel")
	if tafel then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.Parent = tafel
		local liste = Instance.new("UIListLayout")
		liste.HorizontalAlignment = Enum.HorizontalAlignment.Center
		liste.Padding = UDim.new(0.02, 0)
		liste.Parent = sg
		zeile(sg, "Titel", 0.2, Color3.fromRGB(255, 215, 60)).Text = "TOP-SAFARIS"
		local reihen = {}
		for i = 1, 5 do
			local r = zeile(sg, "Platz" .. i, 0.14)
			r.Size = UDim2.fromScale(0.92, 0.14)
			r.TextXAlignment = Enum.TextXAlignment.Left
			reihen[i] = r
		end
		task.spawn(function()
			while true do
				local l = {}
				for p in plotVon do table.insert(l, p) end
				table.sort(l, function(a, b) return (einkommen[a] or 0) > (einkommen[b] or 0) end)
				for i = 1, 5 do
					local p = l[i]
					reihen[i].Text = if p then i .. ". " .. p.DisplayName .. "  $" .. D.format(einkommen[p] or 0) .. "/s" else ""
				end
				task.wait(5)
			end
		end)
	end
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
		if d.Tutorial == 3 then
			tutorialWeiter(p, d, 3, 4)
			meldung(p, "Super! Dein Tier verdient jetzt Geld für dich.", "gut")
		end
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
-- ===== Einfuehrung, Index, Einstellungen =====
local function tutorialWeiter(p, d, von, nach)
	if d.Tutorial >= von and d.Tutorial < nach then
		d.Tutorial = nach
		p:SetAttribute("Tutorial", d.Tutorial)
	end
end

local function indexPruefen(p, d, biomId, verzoegerung)
	if d.IndexBelohnt[biomId] then return end
	for _, t in D.TierListe do
		if t.biom == biomId and not d.Index[t.id] then return end
	end
	d.IndexBelohnt[biomId] = true
	local betrag = D.IndexBelohnung[biomId] or 0
	d.Geld += betrag
	local name = biomId
	for _, b in D.Biome do if b.id == biomId then name = b.name end end
	task.delay(verzoegerung or 0, function()
		if p.Parent then meldung(p, "Index " .. name .. " komplett! +$" .. D.format(betrag), "gut") end
	end)
end

R.Einstellung.OnServerEvent:Connect(function(p, schluessel, wert)
	local d = Spieldaten.holen(p)
	if not d or schluessel ~= "Schnell" or typeof(wert) ~= "boolean" then return end
	d.Einstellungen.Schnell = wert
	statusSenden(p)
end)

-- ===== Gehege vergroessern (Schild) =====
for i = 1, 8 do
	local g = plot(i)
	if not g then continue end
	local basis = g.Boden.Position
	local schild = teil(g, "AusbauSchild", Vector3.new(7, 3.2, 0.6), CFrame.new(basis.X - 15, 6.2, basis.Z + 37), Color3.fromRGB(160, 105, 62), Enum.Material.WoodPlanks)
	teil(g, "AusbauPfeil", Vector3.new(2.3, 2.3, 0.6), CFrame.new(basis.X - 11.3, 6.2, basis.Z + 37) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(160, 105, 62), Enum.Material.WoodPlanks)
	teil(g, "AusbauPfosten", Vector3.new(1, 5, 1), CFrame.new(basis.X - 15, 2.5, basis.Z + 37), Color3.fromRGB(95, 60, 35), Enum.Material.Wood)
	ausbauAnzeige(g, D.START_PLAETZE)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Gehege vergrößern"
	pr.ObjectText = "Gehege"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = schild
	pr.Triggered:Connect(function(p)
		if plotVon[p] ~= g then
			meldung(p, "Das ist nicht dein Grundstück.", "schlecht")
			return
		end
		local d = Spieldaten.holen(p)
		local a = D.naechsterAusbau(d.Plaetze)
		if not a then
			meldung(p, "Dein Gehege ist schon voll ausgebaut!", "info")
			return
		end
		if d.Geld < a.preis then
			meldung(p, "Nicht genug Geld! ($" .. D.format(a.preis) .. ")", "schlecht")
			return
		end
		d.Geld -= a.preis
		d.Plaetze = a.plaetze
		baueGehege(g, d.Plaetze, true)
		plotAnzeige(g, p)
		attributeSetzen(p)
		statusSenden(p)
		meldung(p, "Grundstück vergrößert! Platz für " .. d.Plaetze .. " Tiere", "gut")
	end)
end

-- ===== x2-Training =====
local x2Bis, x2Angebot, x2Naechstes = {}, {}, {}
R.X2Nehmen.OnServerEvent:Connect(function(p)
	if (x2Angebot[p] or 0) > os.clock() then
		x2Angebot[p] = 0
		x2Bis[p] = os.clock() + 10
		R.X2Aktiv:FireClient(p, 10)
	end
end)

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
			x2Naechstes[p] = nil
			continue
		end
		local jetzt = os.clock()
		if not x2Naechstes[p] then x2Naechstes[p] = jetzt + rng:NextNumber(12, 25) end
		if jetzt >= x2Naechstes[p] then
			x2Naechstes[p] = jetzt + rng:NextNumber(20, 40)
			x2Angebot[p] = jetzt + 6
			R.X2Angebot:FireClient(p)
		end
		trainAcc[p] = (trainAcc[p] or 0) + schritt
		if trainAcc[p] >= D.WDH_ZEIT then
			trainAcc[p] -= D.WDH_ZEIT
			local plus = D.Blasebaelge[d.Blasebalg].xp * (if (x2Bis[p] or 0) > os.clock() then 2 else 1)
			d.XP += plus
			R.TrainingTick:FireClient(p, plus)
			while d.XP >= D.xpBedarf(d.Stufe) do
				d.XP -= D.xpBedarf(d.Stufe)
				local vorher = D.pustkraft(d.Stufe)
				d.Stufe += 1
				R.StufeAuf:FireClient(p, d.Stufe, D.pustkraft(d.Stufe) - vorher)
			end
			if d.Stufe >= 3 then tutorialWeiter(p, d, 1, 2) end
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
	local gc = D.groessenChancen(glueck)
	local groesse = 1
	if d.NaechsteId > 1 then
		local r = rng:NextNumber()
		groesse = if r < gc[3] then 3 elseif r < gc[3] + gc[2] then 2 else 1
	end
	if RunService:IsStudio() then -- Test-Schalter, nur in Studio: Attribute TestArt / TestGroesse am Spieler
		local ta, tg = p:GetAttribute("TestArt"), p:GetAttribute("TestGroesse")
		if ta and D.Tiere[ta] then wahl = { id = ta, p = 0.001 } end
		if tg and D.Groessen[tg] then groesse = tg end
	end
	local tier = { id = d.NaechsteId, art = wahl.id, groesse = groesse, material = 1, gehege = false }
	d.NaechsteId += 1
	table.insert(d.Tiere, tier)
	local neu = not d.Index[wahl.id]
	d.Index[wahl.id] = true
	local dauer = D.flugDauer(w)
	naechstesPusten[p] = os.clock() + dauer + 4
	tutorialWeiter(p, d, 1, 3)
	attributeSetzen(p)
	indexPruefen(p, d, biom.id, dauer + 6)
	statusSenden(p)
	local art = D.Tiere[wahl.id]
	return {
		ok = true, weite = w, biom = biom.id, biomName = biom.name, glueck = glueck, art = wahl.id, name = art.name,
		selten = art.selten, chance = math.max(1, math.floor(1 / (wahl.p * gc[groesse]) + 0.5)), quali = qText, serie = serie[p],
		dauer = dauer, neu = neu, tierId = tier.id, drift = rng:NextNumber(-25, 25), einkommen = D.einkommen(tier),
		groesse = groesse, material = 1,
	}
end

print("Bubble Safari Server bereit")
