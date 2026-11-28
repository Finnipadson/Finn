-- Bubble Safari: Client (LocalScript in StarterPlayerScripts)
-- Anzeige, Eingabe, Kamera, Effekte. Entscheidungen trifft der Server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local D = require(RS:WaitForChild("Daten"))
local TM = require(RS:WaitForChild("TierModelle"))
local Remotes = RS:WaitForChild("Remotes")
local R = {}
for _, n in { "Pusten", "TierAktion", "BesteAufstellen", "SeifeKaufen", "SeifeAusruesten", "TrainingStop", "Status", "Meldung", "LadenOeffnen", "TrainingTick", "StufeAuf", "X2Angebot", "X2Nehmen", "X2Aktiv", "Einstellung" } do
	R[n] = Remotes:WaitForChild(n)
end

local spieler = Players.LocalPlayer
local cam = workspace.CurrentCamera
local Map = workspace:WaitForChild("Map")
local Grund = Map:WaitForChild("Grundstuecke")
local rng = Random.new()

local status = { Tiere = {}, Seife = 1, SeifenBesitz = { ["1"] = true }, Plaetze = 6, Index = {}, Blasebalg = 1, IndexBelohnt = {}, Einstellungen = { Schnell = false } }
local pustetGerade = false
local versteckAb = math.huge -- Tier-IDs >= diesem Wert noch nicht zeigen (Enthuellung laeuft)
local SB = 50 -- halbe Schluchtbreite (wie Map.lua)
local seqOrdner = Instance.new("Folder")
seqOrdner.Name = "LokaleSequenz"
seqOrdner.Parent = workspace

-- ===== UI-Hilfen =====
local FONT = Enum.Font.FredokaOne
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function neu(klasse, props, kinder)
	local o = Instance.new(klasse)
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	for _, k in kinder or {} do k.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function ecke(r) return neu("UICorner", { CornerRadius = UDim.new(0, r or 12) }) end
local function rand(dicke, farbe) return neu("UIStroke", { Thickness = dicke or 3, Color = farbe or rgb(40, 40, 70), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function textRand(dicke) return neu("UIStroke", { Thickness = dicke or 2.5, Color = rgb(40, 40, 70) }) end
local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.TextColor3 = props.TextColor3 or rgb(255, 255, 255)
	local rd = props.RandDicke
	props.RandDicke = nil
	local t = neu("TextLabel", props)
	if rd ~= 0 then textRand(rd).Parent = t end
	return t
end
local function knopf(props, farbe)
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or rgb(255, 255, 255)
	props.BackgroundColor3 = farbe or rgb(80, 170, 255)
	props.AutoButtonColor = true
	local b = neu("TextButton", props, { ecke(12), rand(3) })
	textRand(2).Parent = b
	return b
end

local gui = neu("ScreenGui", { Name = "BubbleUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = spieler:WaitForChild("PlayerGui") })

-- ===== HUD oben links =====
local geldBox = neu("Frame", { Size = UDim2.fromOffset(260, 74), Position = UDim2.fromOffset(16, 60), BackgroundColor3 = rgb(30, 40, 70), BackgroundTransparency = 0.25, Parent = gui }, { ecke(14), rand(3, rgb(255, 255, 255)) })
local geldText = text({ Size = UDim2.new(1, -20, 0.6, 0), Position = UDim2.fromOffset(10, 4), Text = "$0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(140, 255, 140), Parent = geldBox })
local ekText = text({ Size = UDim2.new(1, -20, 0.35, 0), Position = UDim2.new(0, 10, 0.6, 0), Text = "+$0/s", TextXAlignment = Enum.TextXAlignment.Left, Parent = geldBox })
local stufeText = text({ Size = UDim2.fromOffset(260, 26), Position = UDim2.fromOffset(16, 138), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = gui })

local function hudAktualisieren()
	geldText.Text = "$" .. D.format(spieler:GetAttribute("Geld") or 0)
	ekText.Text = "+$" .. D.format(spieler:GetAttribute("Einkommen") or 0) .. "/s"
	stufeText.Text = "Stufe " .. (spieler:GetAttribute("Stufe") or 1) .. " · Pustkraft " .. math.floor(spieler:GetAttribute("Pustkraft") or 10)
end
for _, a in { "Geld", "Einkommen", "Stufe", "Pustkraft" } do
	spieler:GetAttributeChangedSignal(a):Connect(hudAktualisieren)
end
hudAktualisieren()

-- ===== Meldungen =====
local meldungsFrame = neu("Frame", { Size = UDim2.fromOffset(600, 200), Position = UDim2.new(0.5, -300, 0, 70), BackgroundTransparency = 1, Parent = gui }, {
	neu("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
})
local function meldung(t, art)
	local farbe = if art == "gut" then rgb(120, 255, 140) elseif art == "schlecht" then rgb(255, 110, 110) else rgb(255, 255, 255)
	local l = text({ Size = UDim2.fromOffset(600, 34), Text = t, TextColor3 = farbe, Parent = meldungsFrame })
	task.delay(2.6, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play() end
		task.wait(0.4)
		l:Destroy()
	end)
end
R.Meldung.OnClientEvent:Connect(meldung)

-- ===== Fenster-Grundgeruest =====
local function fenster(titel, breite, hoehe)
	local f = neu("Frame", { Size = UDim2.fromOffset(breite, hoehe), Position = UDim2.new(0.5, -breite / 2, 0.5, -hoehe / 2), BackgroundColor3 = rgb(235, 245, 255), Visible = false, ZIndex = 20, Parent = gui }, { ecke(18), rand(4) })
	text({ Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(16, 8), Text = titel, TextColor3 = rgb(70, 140, 230), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = f })
	local zu = knopf({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -54, 0, 8), Text = "X", ZIndex = 21, Parent = f }, rgb(240, 80, 80))
	zu.Activated:Connect(function() f.Visible = false end)
	local inhalt = neu("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -110), Position = UDim2.fromOffset(12, 60), BackgroundTransparency = 1, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 21, Parent = f }, {
		neu("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return f, inhalt
end

-- ===== Rucksack-Leiste =====
local leiste = neu("Frame", { Size = UDim2.fromOffset(10 * 74 + 8, 82), Position = UDim2.new(0.5, -(10 * 74 + 8) / 2, 1, -96), BackgroundColor3 = rgb(30, 40, 70), BackgroundTransparency = 0.35, Parent = gui }, {
	ecke(14), neu("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),
})
local rucksackTitel = text({ Size = UDim2.fromOffset(300, 24), Position = UDim2.new(0.5, -150, 1, -122), Text = "Rucksack 0/10", Parent = gui })
local menue -- kleines Aktions-Menue
local function menueZu()
	if menue then menue:Destroy(); menue = nil end
end

local function tierAktionMenue(tier, ueber)
	menueZu()
	local art = D.Tiere[tier.art]
	menue = neu("Frame", { Size = UDim2.fromOffset(220, 150), Position = UDim2.new(0, ueber.AbsolutePosition.X - 70, 0, ueber.AbsolutePosition.Y - 120), BackgroundColor3 = rgb(235, 245, 255), ZIndex = 30, Parent = gui }, { ecke(12), rand(3) })
	text({ Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 4), Text = art.name, TextColor3 = D.Seltenheit[art.selten].farbe, ZIndex = 31, Parent = menue })
	local a = knopf({ Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 40), Text = if tier.gehege then "Raus aus dem Gehege" else "Ins Gehege", ZIndex = 31, Parent = menue }, rgb(90, 200, 110))
	local v = knopf({ Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 94), Text = "Verkaufen $" .. D.format(D.verkaufspreis(tier)), ZIndex = 31, Parent = menue }, rgb(240, 150, 60))
	a.Activated:Connect(function() R.TierAktion:FireServer(tier.id, if tier.gehege then "raus" else "gehege"); menueZu() end)
	v.Activated:Connect(function() R.TierAktion:FireServer(tier.id, "verkaufen"); menueZu() end)
end

local function tierKachel(tier, parent, groesse)
	local art = D.Tiere[tier.art]
	local farbe = D.Seltenheit[art.selten].farbe
	local k = neu("TextButton", { Size = groesse, BackgroundColor3 = rgb(250, 250, 255), Text = "", AutoButtonColor = true, Parent = parent }, { ecke(10), rand(3, farbe) })
	-- 3D-Vorschau
	local vp = neu("ViewportFrame", { Size = UDim2.new(1, 0, 0.72, 0), BackgroundTransparency = 1, Parent = k })
	local m = TM.bauen(tier.art, tier.groesse, tier.material)
	if m then
		m:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
		m.Parent = vp
		local h = TM.hoehe(m)
		local vc = Instance.new("Camera")
		vc.FieldOfView = 40
		local dist = math.max(h, m:GetExtentsSize().Z, m:GetExtentsSize().X) * 1.35
		vc.CFrame = CFrame.lookAt(Vector3.new(dist * 0.35, h * 0.75, -dist), Vector3.new(0, h * 0.45, 0))
		vc.Parent = vp
		vp.CurrentCamera = vc
	end
	text({ Size = UDim2.new(1, -4, 0.28, 0), Position = UDim2.new(0, 2, 0.72, 0), Text = "$" .. D.format(D.einkommen(tier)) .. "/s", TextColor3 = rgb(60, 170, 70), Parent = k })
	if (tier.groesse or 1) > 1 then
		text({ Size = UDim2.new(0.9, 0, 0.24, 0), Position = UDim2.new(0.05, 0, 0, 2), Text = D.Groessen[tier.groesse].name, TextColor3 = rgb(255, 190, 40), ZIndex = k.ZIndex + 2, Parent = k })
	end
	return k
end

local function rucksackZeichnen()
	for _, c in leiste:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local n = 0
	for _, t in status.Tiere do
		if not t.gehege and t.id < versteckAb then
			n += 1
			local k = tierKachel(t, leiste, UDim2.fromOffset(70, 70))
			k.LayoutOrder = n
			k.Activated:Connect(function() tierAktionMenue(t, k) end)
		end
	end
	for i = n + 1, D.RUCKSACK do
		neu("Frame", { Size = UDim2.fromOffset(70, 70), BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 0.8, LayoutOrder = i, Parent = leiste }, { ecke(10) })
	end
	rucksackTitel.Text = "Rucksack " .. n .. "/" .. D.RUCKSACK
end

-- ===== Fenster: Meine Tiere =====
local tierFenster, tierInhalt = fenster("Meine Tiere", 560, 460)
local besteKnopf = knopf({ Size = UDim2.fromOffset(230, 40), Position = UDim2.new(0, 16, 1, -48), Text = "Beste aufstellen", ZIndex = 21, Parent = tierFenster }, rgb(90, 200, 110))
local gehegeZaehler = text({ Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -216, 1, -46), Text = "Gehege 0/6", TextColor3 = rgb(70, 140, 230), ZIndex = 21, Parent = tierFenster })
besteKnopf.Activated:Connect(function() R.BesteAufstellen:FireServer() end)

local function tierFensterZeichnen()
	for _, c in tierInhalt:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local imGehege = 0
	local liste = {}
	for _, t in status.Tiere do
		if t.id < versteckAb then table.insert(liste, t) end
		if t.gehege then imGehege += 1 end
	end
	table.sort(liste, function(a, b)
		if a.gehege ~= b.gehege then return a.gehege end
		return D.einkommen(a) > D.einkommen(b)
	end)
	for i, t in liste do
		local art = D.Tiere[t.art]
		local z = neu("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = if t.gehege then rgb(215, 245, 215) else rgb(255, 255, 255), LayoutOrder = i, ZIndex = 21, Parent = tierInhalt }, { ecke(10) })
		local k = tierKachel(t, z, UDim2.fromOffset(62, 62))
		k.Position = UDim2.fromOffset(4, 4)
		k.ZIndex = 22
		text({ Size = UDim2.new(0.38, 0, 0, 30), Position = UDim2.fromOffset(74, 6), Text = art.name, TextColor3 = D.Seltenheit[art.selten].farbe, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = z })
		text({ Size = UDim2.new(0.45, 0, 0, 24), Position = UDim2.fromOffset(74, 38), Text = (if t.gehege then "Im Gehege · " else "Rucksack · ") .. "$" .. D.format(D.einkommen(t)) .. "/s", TextColor3 = rgb(70, 90, 120), TextXAlignment = Enum.TextXAlignment.Left, RandDicke = 0, ZIndex = 22, Parent = z })
		local a = knopf({ Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -214, 0, 15), Text = if t.gehege then "RAUS" else "GEHEGE", ZIndex = 22, Parent = z }, rgb(90, 200, 110))
		local v = knopf({ Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -108, 0, 15), Text = "VERKAUFEN", ZIndex = 22, Parent = z }, rgb(240, 150, 60))
		a.Activated:Connect(function() R.TierAktion:FireServer(t.id, if t.gehege then "raus" else "gehege") end)
		v.Activated:Connect(function() R.TierAktion:FireServer(t.id, "verkaufen") end)
	end
	gehegeZaehler.Text = "Gehege " .. imGehege .. "/" .. status.Plaetze
end

-- ===== Fenster: Seifenladen =====
local seifenFenster, seifenInhalt = fenster("Seifenladen", 520, 420)
local function seifenZeichnen()
	for _, c in seifenInhalt:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	for i, s in D.Seifen do
		local hat = status.SeifenBesitz[tostring(i)]
		local an = status.Seife == i
		local z = neu("Frame", { Size = UDim2.new(1, -10, 0, 90), BackgroundColor3 = rgb(255, 255, 255), LayoutOrder = i, ZIndex = 21, Parent = seifenInhalt }, { ecke(12) })
		neu("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 13), BackgroundColor3 = s.farbe, ZIndex = 22, Parent = z }, { ecke(32), rand(3) })
		text({ Size = UDim2.new(0.45, 0, 0, 34), Position = UDim2.fromOffset(90, 8), Text = s.name, TextColor3 = rgb(60, 80, 120), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = z })
		local werte = "Weite ×" .. string.gsub(string.format("%.1f", s.weite), "%.", ",") .. (if s.glueck > 0 then " · Glück +" .. math.floor(s.glueck * 100) .. "%" else "")
		text({ Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.fromOffset(90, 48), Text = werte, TextColor3 = rgb(90, 110, 140), TextXAlignment = Enum.TextXAlignment.Left, RandDicke = 0, ZIndex = 22, Parent = z })
		local b
		if an then
			b = knopf({ Size = UDim2.fromOffset(150, 50), Position = UDim2.new(1, -162, 0, 20), Text = "AUSGERÜSTET", ZIndex = 22, Parent = z }, rgb(150, 150, 160))
		elseif hat then
			b = knopf({ Size = UDim2.fromOffset(150, 50), Position = UDim2.new(1, -162, 0, 20), Text = "AUSRÜSTEN", ZIndex = 22, Parent = z }, rgb(80, 170, 255))
			b.Activated:Connect(function() R.SeifeAusruesten:FireServer(i) end)
		else
			local genug = (spieler:GetAttribute("Geld") or 0) >= s.preis
			b = knopf({ Size = UDim2.fromOffset(150, 50), Position = UDim2.new(1, -162, 0, 20), Text = "$" .. D.format(s.preis), ZIndex = 22, Parent = z }, if genug then rgb(90, 200, 110) else rgb(220, 90, 90))
			b.Activated:Connect(function() R.SeifeKaufen:FireServer(i) end)
		end
	end
end
local letzteLeistbar = ""
spieler:GetAttributeChangedSignal("Geld"):Connect(function()
	-- nur neu zeichnen, wenn sich aendert, was man sich leisten kann (sonst gehen Klicks verloren)
	local sig = ""
	for _, s in D.Seifen do sig ..= if (spieler:GetAttribute("Geld") or 0) >= s.preis then "1" else "0" end
	if sig ~= letzteLeistbar then
		letzteLeistbar = sig
		if seifenFenster.Visible then seifenZeichnen() end
	end
end)
R.LadenOeffnen.OnClientEvent:Connect(function(art)
	if art and art ~= "seifen" then return end -- Tiere/Index oeffnet der Handler weiter unten
	seifenZeichnen()
	seifenFenster.Visible = true
	tierFenster.Visible = false
end)

-- ===== Seiten-Knoepfe =====
local function seitenKnopf(t, y, farbe, f)
	local b = knopf({ Size = UDim2.fromOffset(110, 56), Position = UDim2.new(0, 16, 0.5, y), Text = t }, farbe)
	b.Parent = gui
	b.Activated:Connect(f)
end
seitenKnopf("Tiere", -70, rgb(255, 150, 60), function()
	tierFensterZeichnen()
	tierFenster.Visible = not tierFenster.Visible
	seifenFenster.Visible = false
end)
seitenKnopf("Seifen", 0, rgb(80, 170, 255), function()
	seifenZeichnen()
	seifenFenster.Visible = not seifenFenster.Visible
	tierFenster.Visible = false
end)

rucksackZeichnen()

-- ===== Training =====
local trainFrame = neu("Frame", { Size = UDim2.fromOffset(420, 110), Position = UDim2.new(0.5, -210, 1, -250), BackgroundTransparency = 1, Visible = false, Parent = gui })
local trainTitel = text({ Size = UDim2.new(1, 0, 0, 30), Text = "Tritt auf den Blasebalg!", Parent = trainFrame })
local balkenHG = neu("Frame", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = rgb(40, 40, 70), Parent = trainFrame }, { ecke(15), rand(3, rgb(255, 255, 255)) })
local balken = neu("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = rgb(120, 220, 255), Parent = balkenHG }, { ecke(15) })
local balkenText = text({ Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3, Parent = balkenHG })
local haltKnopf = knopf({ Size = UDim2.fromOffset(140, 40), Position = UDim2.new(0.5, -70, 0, 70), Text = "HALT", Parent = trainFrame }, rgb(235, 70, 70))
haltKnopf.Activated:Connect(function() R.TrainingStop:FireServer() end)

local function trainAnzeige()
	local xp, bed = spieler:GetAttribute("XP") or 0, spieler:GetAttribute("XPBedarf") or 6
	balken.Size = UDim2.fromScale(math.clamp(xp / bed, 0, 1), 1)
	balkenText.Text = "Stufe " .. (spieler:GetAttribute("Stufe") or 1) .. " – " .. D.format(xp) .. "/" .. D.format(bed)
end
spieler:GetAttributeChangedSignal("XP"):Connect(trainAnzeige)
spieler:GetAttributeChangedSignal("Trainiert"):Connect(function()
	trainFrame.Visible = spieler:GetAttribute("Trainiert") == true
	trainAnzeige()
end)

local function meinGrundstueck()
	local nr = spieler:GetAttribute("Grundstueck")
	return nr and Grund:FindFirstChild("Grundstueck" .. nr), nr
end

local function weltZahl(pos, t, farbe)
	local a = neu("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos), Parent = workspace })
	local bb = neu("BillboardGui", { Size = UDim2.fromOffset(160, 50), AlwaysOnTop = true, LightInfluence = 0, Parent = a })
	local l = text({ Size = UDim2.fromScale(1, 1), Text = t, TextColor3 = farbe or rgb(255, 255, 255), Parent = bb })
	TweenService:Create(a, TweenInfo.new(0.9), { CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 4, 0)) }):Play()
	TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(0.9, function() a:Destroy() end)
end

R.TrainingTick.OnClientEvent:Connect(function(plus)
	local g = meinGrundstueck()
	local bb = g and g:FindFirstChild("Blasebalg")
	if not bb then return end
	local deckel = bb:FindFirstChild("Deckel")
	if deckel then
		local cf = deckel.CFrame
		local runter = TweenService:Create(deckel, TweenInfo.new(0.15), { CFrame = cf * CFrame.new(0, -1, 0) })
		runter:Play()
		runter.Completed:Once(function()
			TweenService:Create(deckel, TweenInfo.new(0.3), { CFrame = cf }):Play()
		end)
		-- Luftwoelkchen aus der Duese
		local duese = bb:FindFirstChild("Duese")
		if duese then
			for i = 1, 3 do
				local w = neu("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.ForceField, Color = rgb(200, 235, 255), CFrame = duese.CFrame * CFrame.new(0, 0, -2), Parent = workspace })
				TweenService:Create(w, TweenInfo.new(0.8), { Size = Vector3.one * 2.2, Transparency = 1, CFrame = duese.CFrame * CFrame.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1.5), -5 - i) }):Play()
				task.delay(0.8, function() w:Destroy() end)
			end
		end
	end
	weltZahl((deckel and deckel.Position or bb:GetPivot().Position) + Vector3.new(0, 4, 0), "+" .. D.format(plus) .. " XP", rgb(130, 220, 255))
end)

local function konfetti()
	local farben = { rgb(255, 120, 170), rgb(255, 215, 60), rgb(120, 220, 255), rgb(140, 255, 140), rgb(200, 150, 255) }
	for i = 1, 40 do
		local x = rng:NextNumber()
		local f = neu("Frame", { Size = UDim2.fromOffset(rng:NextInteger(10, 18), rng:NextInteger(10, 18)), Position = UDim2.new(x, 0, 0, -20), BackgroundColor3 = farben[rng:NextInteger(1, #farben)], Rotation = rng:NextNumber(0, 360), ZIndex = 40, Parent = gui }, { ecke(9) })
		local t = rng:NextNumber(1.5, 2.6)
		TweenService:Create(f, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(x + rng:NextNumber(-0.1, 0.1), 0, 1.05, 0), Rotation = f.Rotation + rng:NextNumber(-300, 300) }):Play()
		task.delay(t, function() f:Destroy() end)
	end
end

local function grosserText(t1, t2, farbe)
	local f = neu("Frame", { Size = UDim2.fromOffset(700, 140), Position = UDim2.new(0.5, -350, 0.28, 0), BackgroundTransparency = 1, ZIndex = 35, Parent = gui })
	local a = text({ Size = UDim2.new(1, 0, 0.6, 0), Text = t1, TextColor3 = farbe or rgb(255, 230, 80), ZIndex = 35, RandDicke = 4, Parent = f })
	text({ Size = UDim2.new(1, 0, 0.35, 0), Position = UDim2.fromScale(0, 0.62), Text = t2 or "", ZIndex = 35, Parent = f })
	local sc = neu("UIScale", { Scale = 0.3, Parent = f })
	TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.2, function()
		TweenService:Create(sc, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		f:Destroy()
	end)
	return a
end

R.StufeAuf.OnClientEvent:Connect(function(stufe, plus)
	grosserText("STUFE ERHÖHT!", "Stufe " .. stufe .. " · Pustkraft +" .. string.gsub(string.format("%.1f", plus), "%.0$", ""):gsub("%.", ","))
	konfetti()
end)

-- ===== Effekte fuer Flug / Enthuellung =====
local schwarz = neu("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })
local function blende(ziel, zeit)
	local tw = TweenService:Create(schwarz, TweenInfo.new(zeit), { BackgroundTransparency = ziel })
	tw:Play()
	tw.Completed:Wait()
end

-- Vignette (Tier-Augen): Kreise mit dickem Rand
local vignette = neu("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 45, Parent = gui })
for i, e in { { 0.78, 0.82 }, { 0.92, 0.6 }, { 1.06, 0.3 } } do
	neu("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(e[1], e[1]), SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundTransparency = 1, ZIndex = 45, Parent = vignette }, {
		ecke(10000), neu("UIStroke", { Thickness = 1400, Color = rgb(0, 0, 0), Transparency = e[2] }),
	})
end

local farbKorrektur = neu("ColorCorrectionEffect", { Name = "BiomFarbe", Parent = Lighting })
local BIOM_TINT = { Wiese = rgb(255, 255, 255), Pilzwald = rgb(215, 205, 255), Sumpf = rgb(220, 235, 210) }

-- Flug-HUD
local flugHUD = neu("Frame", { Size = UDim2.fromOffset(460, 100), Position = UDim2.new(0.5, -230, 0, 50), BackgroundTransparency = 1, Visible = false, Parent = gui })
local flugGlueck = text({ Size = UDim2.new(1, 0, 0.55, 0), Text = "", TextColor3 = rgb(140, 255, 160), RandDicke = 3, Parent = flugHUD })
local function gross(t) -- string.upper kennt keine Umlaute
	return (string.upper(t):gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))
end
local zonenFrame = neu("Frame", { Size = UDim2.fromOffset(190, 320), Position = UDim2.new(0, 140, 0.5, -160), BackgroundTransparency = 1, Visible = false, Parent = gui }, {
	neu("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local BIOM_FARBE = { Wiese = rgb(120, 215, 90), Pilzwald = rgb(170, 110, 230), Sumpf = rgb(110, 150, 110) }
local function zonenLeiste(aktiv)
	zonenFrame.Visible = true
	for _, c in zonenFrame:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	for i = #D.Biome, 1, -1 do -- weiteste Zone oben
		local b = D.Biome[i]
		local an = b.id == aktiv
		local z = neu("Frame", { Size = UDim2.fromOffset(if an then 190 else 150, if an then 64 else 46), BackgroundTransparency = 1, LayoutOrder = #D.Biome - i, Parent = zonenFrame })
		neu("Frame", { Size = UDim2.fromOffset(if an then 58 else 40, if an then 58 else 40), BackgroundColor3 = BIOM_FARBE[b.id] or rgb(200, 200, 200), Parent = z }, { ecke(10), rand(if an then 4 else 2, if an then rgb(255, 255, 255) else rgb(40, 40, 70)) })
		text({ Size = UDim2.new(1, if an then -66 else -48, 0.8, 0), Position = UDim2.new(0, if an then 66 else 48, 0.1, 0), Text = gross(b.name), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if an then rgb(255, 255, 255) else rgb(220, 225, 235), Parent = z })
	end
end
local flugBiom = text({ Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.58), Text = "", Parent = flugHUD })

-- Enthuellungs-HUD
local enthHUD = neu("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 46, Parent = gui })
local enthTitel = text({ Size = UDim2.fromOffset(600, 60), Position = UDim2.new(0.5, -300, 0, 40), Text = "", TextColor3 = rgb(255, 180, 60), ZIndex = 47, RandDicke = 4, Parent = enthHUD })
local enthChance = text({ Size = UDim2.fromOffset(400, 44), Position = UDim2.new(0.5, -200, 0, 100), Text = "", ZIndex = 47, Parent = enthHUD })
local enthWort = text({ Size = UDim2.fromOffset(700, 56), Position = UDim2.new(0.5, -350, 1, -230), Text = "", ZIndex = 47, RandDicke = 4, Parent = enthHUD })
local enthInfo = text({ Size = UDim2.fromOffset(500, 34), Position = UDim2.new(0.5, -250, 1, -170), Text = "", TextColor3 = rgb(140, 255, 140), ZIndex = 47, Parent = enthHUD })
local enthNeu = text({ Size = UDim2.fromOffset(220, 44), Position = UDim2.new(0.5, 150, 1, -270), Rotation = 12, Text = "", TextColor3 = rgb(255, 230, 60), ZIndex = 48, Parent = enthHUD })
local enthWeiter = text({ Size = UDim2.fromOffset(400, 28), Position = UDim2.new(0.5, -200, 1, -128), Text = "", ZIndex = 47, Parent = enthHUD })
local enthGroesse = text({ Size = UDim2.fromOffset(300, 40), Position = UDim2.new(0.5, -150, 1, -272), Text = "", TextColor3 = rgb(255, 200, 50), ZIndex = 47, RandDicke = 3, Parent = enthHUD })
local strahlen = neu("Frame", { Size = UDim2.fromOffset(420, 420), Position = UDim2.new(0.5, -210, 0, 70 - 210), BackgroundTransparency = 1, Visible = false, ZIndex = 46, Parent = enthHUD })
for i = 0, 11 do
	neu("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 24, 1, 0), Rotation = i * 15, BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 46, Parent = strahlen }, {
		neu("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
	})
end
RunService.RenderStepped:Connect(function(dt)
	if strahlen.Visible then strahlen.Rotation += dt * 25 end
end)
local blitz = neu("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 1, ZIndex = 49, Parent = gui })


local function titelFuer(n)
	if n >= 5000 then return "Regenbogenglück!!", rgb(255, 120, 230) end
	if n >= 500 then return "Blasenwahn!", rgb(80, 240, 230) end
	if n >= 50 then return "Riesenglück!", rgb(255, 110, 180) end
	if n >= 10 then return "Glück!", rgb(255, 170, 50) end
	return "", rgb(255, 255, 255)
end

local function lueckenWort(name, anteil, reihenfolge)
	local zeichen = {}
	for _, c in utf8.codes(gross(name)) do table.insert(zeichen, utf8.char(c)) end
	local zeigen = math.floor(#zeichen * anteil)
	local sichtbar = {}
	for i = 1, zeigen do sichtbar[reihenfolge[i]] = true end
	local out = {}
	for i, c in zeichen do
		table.insert(out, if (sichtbar[i] or c == " " or c == "-") then c else "_")
	end
	return table.concat(out, " ")
end

local function blaseBauen(farbe)
	local b = neu("Part", { Name = "Blase", Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.ForceField, Color = farbe, CastShadow = false, Parent = seqOrdner })
	local innen = neu("Part", { Name = "Innen", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.95, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Glass, Transparency = 0.85, Color = farbe, CastShadow = false, Parent = b })
	return b, innen
end
local function blaseSetzen(b, innen, pos, d)
	b.Size = Vector3.one * d
	b.CFrame = CFrame.new(pos)
	innen.Size = Vector3.one * d * 0.97
	innen.CFrame = b.CFrame
end

local function kameraZurueck()
	cam.CameraType = Enum.CameraType.Custom
	local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	cam.FieldOfView = 70
	-- Kamera hinter die Figur setzen, Blick Richtung Schlucht
	local hrp = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
	if hrp then cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 6, -13), hrp.Position + Vector3.new(0, 2, 10)) end
	farbKorrektur.TintColor = rgb(255, 255, 255)
end

-- Laufen eines Tiers (Pivot) mit Wippen
local function tierLaufen(m, von, nach, dauer, wippen)
	local start = os.clock()
	local blick = CFrame.lookAt(von, Vector3.new(nach.X, von.Y, nach.Z))
	while true do
		local t = math.min((os.clock() - start) / dauer, 1)
		local p = von:Lerp(nach, t)
		local hop = math.abs(math.sin(t * dauer * 9)) * wippen
		m:PivotTo((blick - blick.Position) + p + Vector3.new(0, hop, 0))
		if t >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end

local function warteKlickOder(sek)
	local fertig = false
	local c1 = UIS.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then fertig = true end
	end)
	local start = os.clock()
	while not fertig and os.clock() - start < sek do task.wait() end
	c1:Disconnect()
end

-- ===== Die ganze Sequenz: Flug -> Tier-Sicht -> Bodenkamera -> Ergebnis =====
local function sequenz(res, startPos)
	local seife = D.Seifen[spieler:GetAttribute("Seife") or 1]
	local blase, innen = blaseBauen(seife.farbe)
	local D_BLASE = 7
	-- 1) Blase waechst am Stab
	for i = 1, 15 do
		blaseSetzen(blase, innen, startPos, D_BLASE * i / 15)
		RunService.RenderStepped:Wait()
	end
	-- 2) Flug
	cam.CameraType = Enum.CameraType.Scriptable
	flugHUD.Visible = true
	local ziel = Vector3.new(math.clamp(startPos.X + res.drift, -(SB - 18), SB - 18), D_BLASE / 2, res.weite)
	local start = os.clock()
	local letzterBiom
	local gEnde = select(2, D.biomBei(res.weite))
	local bonus = res.glueck / gEnde
	while true do
		local t = math.min((os.clock() - start) / res.dauer, 1)
		local u = 1 - (1 - t) ^ 2.2
		local pos = startPos:Lerp(ziel, u) + Vector3.new(math.sin(t * 9) * 1.5, math.sin(math.pi * u) * 22, 0)
		blaseSetzen(blase, innen, pos, D_BLASE)
		local fwd = (ziel - startPos).Unit
		cam.CFrame = CFrame.lookAt(pos - Vector3.new(fwd.X, 0, fwd.Z).Unit * 26 + Vector3.new(0, 10, 0), pos + Vector3.new(0, 0, 18))
		local biom, g = D.biomBei(pos.Z)
		flugGlueck.Text = string.gsub(string.format("%.2fX Glück", g * bonus), "%.", ",")
		flugBiom.Text = gross(biom.name) .. " · " .. math.floor(pos.Z) .. " m"
		if biom.id ~= letzterBiom then
			letzterBiom = biom.id
			zonenLeiste(biom.id)
			TweenService:Create(farbKorrektur, TweenInfo.new(0.6), { TintColor = BIOM_TINT[biom.id] or rgb(255, 255, 255) }):Play()
			if pos.Z > 50 then grosserText(gross(biom.name), "", rgb(255, 255, 255)) end
		end
		if t >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	-- Landung: einmal federn
	TweenService:Create(blase, TweenInfo.new(0.35, Enum.EasingStyle.Bounce), { Size = Vector3.new(D_BLASE * 1.1, D_BLASE * 0.85, D_BLASE * 1.1) }):Play()
	task.wait(0.35)
	blaseSetzen(blase, innen, ziel, D_BLASE)
	flugHUD.Visible = false
	zonenFrame.Visible = false

	-- Tier vorbereiten
	local tier = TM.bauen(res.art, res.groesse, res.material)
	local h = TM.hoehe(tier)
	local kurz = (not res.neu) and res.selten == "Gewoehnlich"
	local chanceZiel = res.chance
	local reihenfolge = {}
	local nZeichen = utf8.len(res.name)
	for i = 1, nZeichen do reihenfolge[i] = i end
	for i = nZeichen, 2, -1 do
		local j = rng:NextInteger(1, i)
		reihenfolge[i], reihenfolge[j] = reihenfolge[j], reihenfolge[i]
	end
	local function spannung(anteil)
		anteil = math.clamp(anteil, 0, 1)
		local n = math.max(1, math.floor(chanceZiel ^ anteil + 0.5))
		enthChance.Text = "1 in " .. D.format(n)
		local t1, f1 = titelFuer(n)
		enthTitel.Text = t1
		enthTitel.TextColor3 = f1
		strahlen.Visible = n >= 50
		for _, s in strahlen:GetChildren() do
			if s:IsA("Frame") then s.BackgroundColor3 = f1 end
		end
		enthWort.Text = lueckenWort(res.name, anteil * 0.85, reihenfolge)
	end

	-- Silhouette: Farben merken, Tier bleibt schwarz bis zur Enthuellung
	local farben, effekte = {}, {}
	for _, p in tier:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			farben[p] = { p.Color, p.Material }
			p.Color = rgb(15, 15, 25)
			p.Material = Enum.Material.SmoothPlastic
		elseif p:IsA("ParticleEmitter") or p:IsA("PointLight") then
			effekte[p] = true
			p.Enabled = false
		end
	end
	local function farbeZurueck()
		for p, f in farben do p.Color, p.Material = f[1], f[2] end
		for e in effekte do e.Enabled = true end
	end

	local rang = D.Seltenheit[res.selten].rang
	local schnell = status.Einstellungen and status.Einstellungen.Schnell and rang <= 2
	local istGross = (res.groesse or 1) >= 2 or rang >= 5
	local ausmass = tier:GetExtentsSize()
	local endD = math.max(D_BLASE, math.max(h, ausmass.Z, ausmass.X) * 1.25)
	local mitte = Vector3.new(ziel.X, endD / 2 - h / 2, ziel.Z)
	local winkel = math.rad(rng:NextNumber(-30, 30))
	local dir = Vector3.new(math.sin(winkel), 0, math.cos(winkel)) -- Tier kommt von weiter hinten im Tal
	local k = math.max(1, h / 3, endD / 8)
	local seite = dir:Cross(Vector3.yAxis).Unit
	if math.sign(seite.X) == math.sign(ziel.X) then seite = -seite end -- Kamera zur Schluchtmitte hin
	local camPos = ziel + dir * (9 * k) + seite * math.min(3 * k, 8) + Vector3.new(0, 1.3 * k - D_BLASE / 2 + 0.5, 0)
	camPos = Vector3.new(math.clamp(camPos.X, -(SB - 10), SB - 10), camPos.Y, camPos.Z)
	enthNeu.Text, enthInfo.Text, enthWeiter.Text, enthGroesse.Text = "", "", "", ""

	if schnell then
		-- Schnelle Enthuellung: Tier ploppt direkt in die Blase
		enthHUD.Visible = true
		spannung(0.9)
		cam.FieldOfView = 75
		cam.CFrame = CFrame.lookAt(camPos, ziel + Vector3.new(0, 1, 0))
		tier:PivotTo(CFrame.lookAt(mitte, Vector3.new(camPos.X, mitte.Y, camPos.Z)))
		tier.Parent = seqOrdner
		blaseSetzen(blase, innen, Vector3.new(ziel.X, endD / 2, ziel.Z), endD)
		task.wait(0.2)
	else
		-- 3) Tier-Sicht: man ist das Tier und laeuft zur Blase
		blende(0, 0.25)
		local auge = math.max(1.3, h * 0.8)
		local povStart = ziel + dir * (34 + endD)
		povStart = Vector3.new(math.clamp(povStart.X, -(SB - 10), SB - 10), povStart.Y, povStart.Z)
		local povEnde = ziel + dir * (D_BLASE / 2 + 4 + h * 0.6)
		cam.FieldOfView = 100
		vignette.Visible = true
		enthHUD.Visible = true
		spannung(0)
		blende(1, 0.25)
		local povDauer = if kurz then 0.7 else 2.0
		local schrittTempo = if h > 6 then 5 elseif h > 3 then 8 else 13
		local beben = if h > 6 then 0.25 else 0
		local start3 = os.clock()
		while true do
			local t = math.min((os.clock() - start3) / povDauer, 1)
			local p = povStart:Lerp(povEnde, t)
			local wipp = math.sin(os.clock() * schrittTempo) * 0.12 * auge
			local seit = math.cos(os.clock() * schrittTempo * 0.5) * 0.06 * auge
			local stoss = if math.abs(math.sin(os.clock() * schrittTempo)) > 0.97 then rng:NextNumber(-1, 1) * beben else 0
			cam.CFrame = CFrame.lookAt(Vector3.new(p.X + stoss, auge + wipp, p.Z), ziel + Vector3.new(seit, auge * 0.6, 0))
			spannung(t * 0.45)
			if t >= 1 then break end
			RunService.RenderStepped:Wait()
		end

		-- 4) Schnitt: Bodenkamera, Tier (Silhouette) laeuft vorbei in die Blase
		blende(0, 0.12)
		vignette.Visible = false
		cam.FieldOfView = 75
		cam.CFrame = CFrame.lookAt(camPos, ziel + Vector3.new(0, 1, 0))
		local laufStart = camPos + dir * (5 * k) - seite * math.min(4.5 * k, 12)
		laufStart = Vector3.new(math.clamp(laufStart.X, -(SB - 10), SB - 10), 0, laufStart.Z)
		local laufEnde = Vector3.new(ziel.X, 0, ziel.Z) + dir * (D_BLASE / 2 + h * 0.4)
		tier:PivotTo(CFrame.new(laufStart))
		tier.Parent = seqOrdner
		blende(1, 0.12)
		local laufDauer = if kurz then 0.7 else 1.8
		task.spawn(function()
			local s0 = os.clock()
			while os.clock() - s0 < laufDauer do
				spannung(0.45 + (os.clock() - s0) / laufDauer * 0.45)
				RunService.RenderStepped:Wait()
			end
		end)
		tierLaufen(tier, laufStart, laufEnde, laufDauer, math.min(0.6, h * 0.12))

		-- 5) Sprung in die Blase; bei grossen Tieren dehnt sich die Blase in Stoessen
		local sprungVon = tier:GetPivot()
		local sprungD = if istGross then D_BLASE + (endD - D_BLASE) * 0.35 else endD
		local s0 = os.clock()
		while true do
			local t = math.min((os.clock() - s0) / 0.4, 1)
			local p = sprungVon.Position:Lerp(mitte, t) + Vector3.new(0, math.sin(math.pi * t) * h * 0.8, 0)
			tier:PivotTo((sprungVon - sprungVon.Position) + p)
			local dNow = D_BLASE + (sprungD - D_BLASE) * t
			blaseSetzen(blase, innen, Vector3.new(ziel.X, dNow / 2, ziel.Z), dNow)
			if t >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		tier:PivotTo(CFrame.lookAt(mitte, Vector3.new(camPos.X, mitte.Y, camPos.Z)))
		if istGross then
			local aktuell = sprungD
			for stufe = 1, 3 do
				local nach = D_BLASE + (endD - D_BLASE) * (0.35 + stufe * 0.65 / 3)
				local s1 = os.clock()
				while true do
					local t = math.min((os.clock() - s1) / 0.28, 1)
					local d = aktuell + (nach - aktuell) * t + math.sin(t * math.pi) * 0.12 * nach
					blaseSetzen(blase, innen, Vector3.new(ziel.X, d / 2, ziel.Z), d)
					if t >= 1 then break end
					RunService.RenderStepped:Wait()
				end
				aktuell = nach
				task.wait(0.18)
			end
		end
		-- Hit-Stop + Wackeln
		task.wait(0.1)
		local wackel = if res.chance >= 50 then 0.5 elseif res.chance >= 10 then 0.3 else 0.15
		for i = 1, 12 do
			local f = 1 + math.sin(i * 1.3) * 0.08 * (1 - i / 12)
			blase.Size = Vector3.new(endD * f, endD / f, endD * f)
			cam.CFrame = CFrame.lookAt(camPos + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * wackel * (1 - i / 12), ziel + Vector3.new(0, 1, 0))
			RunService.RenderStepped:Wait()
		end
	end
	blaseSetzen(blase, innen, Vector3.new(ziel.X, endD / 2, ziel.Z), endD)

	-- 6) Ergebnis: weisser Blitz, Tier bekommt seine Farben
	farbeZurueck()
	blitz.BackgroundTransparency = 0.15
	TweenService:Create(blitz, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	spannung(1)
	enthWort.Text = gross(res.name)
	enthWort.TextColor3 = D.Seltenheit[res.selten].farbe
	enthGroesse.Text = D.Groessen[res.groesse or 1].name
	enthInfo.Text = D.Seltenheit[res.selten].name .. " · $" .. D.format(res.einkommen) .. "/s"
	enthNeu.Text = if res.neu then "NEU!" else ""
	if res.chance >= 10 then konfetti() end
	local zurueckPos = camPos + dir * (4 * k) + Vector3.new(0, 2 * k, 0)
	TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(zurueckPos, Vector3.new(ziel.X, endD / 2, ziel.Z)) }):Play()
	task.wait(0.5)
	enthWeiter.Text = "Tippe zum Fortfahren"
	warteKlickOder(if kurz or schnell then 2.5 else 6)
	strahlen.Visible = false

	-- 7) Blase steigt auf und schwebt zurueck
	local hoch = TweenService:Create(blase, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = blase.CFrame + Vector3.new(0, 30, 0) })
	hoch:Play()
	local tierHoch = tier:GetPivot()
	task.spawn(function()
		local s1 = os.clock()
		while os.clock() - s1 < 0.6 do
			local t = (os.clock() - s1) / 0.6
			tier:PivotTo(tierHoch + Vector3.new(0, 30 * t * t, 0))
			innen.CFrame = blase.CFrame
			RunService.RenderStepped:Wait()
		end
	end)
	blende(0, 0.5)
	enthHUD.Visible = false
	enthWort.TextColor3 = rgb(255, 255, 255)
	tier:Destroy()
	blase:Destroy()
	kameraZurueck()
	blende(1, 0.35)
end

-- ===== Pusten (Balken) =====
local pustFrame = neu("Frame", { Size = UDim2.fromOffset(120, 360), Position = UDim2.new(1, -170, 0.5, -200), BackgroundTransparency = 1, Visible = false, Parent = gui })
local pustBalken = neu("Frame", { Size = UDim2.fromOffset(60, 300), Position = UDim2.fromOffset(30, 0), BackgroundColor3 = rgb(230, 90, 90), Parent = pustFrame }, { ecke(14), rand(4, rgb(255, 255, 255)) })
local function zone(von, bis, farbe)
	neu("Frame", { Size = UDim2.new(1, 0, bis - von, 0), Position = UDim2.new(0, 0, 1 - bis, 0), BackgroundColor3 = farbe, BorderSizePixel = 0, Parent = pustBalken })
end
zone(0.45, 1, rgb(255, 210, 70))
zone(0.84, 0.96, rgb(90, 230, 110))
local zeiger = neu("Frame", { Size = UDim2.new(1, 24, 0, 8), Position = UDim2.new(0, -12, 1, -4), BackgroundColor3 = rgb(255, 255, 255), ZIndex = 3, Parent = pustBalken }, { ecke(4), rand(2) })
local serieText = text({ Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(-20, 306), Text = "", TextColor3 = rgb(140, 255, 160), Parent = pustFrame })
local pustKnopf = knopf({ Size = UDim2.fromOffset(260, 80), Position = UDim2.new(0.5, -130, 1, -230), Text = "PUSTEN!", Visible = false, Parent = gui }, rgb(90, 190, 255))
local pustHinweis = text({ Size = UDim2.fromOffset(420, 34), Position = UDim2.new(0.5, -210, 1, -270), Text = "Tippe, wenn der Zeiger im grünen Feld ist!", Visible = false, Parent = gui })

local zeigerWert, zeigerRichtung = 0, 1
local function aufPustplatz()
	local wp = Map:FindFirstChild("Wurfplatz")
	local platte = wp and wp:FindFirstChild("Platte")
	local hrp = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
	if not platte or not hrp or not meinGrundstueck() then return nil end
	local d = platte.CFrame:PointToObjectSpace(hrp.Position)
	if math.abs(d.X) < platte.Size.X / 2 and math.abs(d.Z) < platte.Size.Z / 2 and d.Y < 8 then return wp end
	return nil
end

RunService.RenderStepped:Connect(function(dt)
	local zeigen = (not pustetGerade) and aufPustplatz() ~= nil
	pustFrame.Visible = zeigen
	pustKnopf.Visible = zeigen
	pustHinweis.Visible = zeigen
	if zeigen then
		zeigerWert += zeigerRichtung * dt * 1.25
		if zeigerWert >= 1 then zeigerWert, zeigerRichtung = 1, -1 end
		if zeigerWert <= 0 then zeigerWert, zeigerRichtung = 0, 1 end
		zeiger.Position = UDim2.new(0, -12, 1 - zeigerWert, -4)
	end
end)

local function pusten()
	if pustetGerade then return end
	local pp = aufPustplatz()
	if not pp then return end
	pustetGerade = true
	local wert = zeigerWert
	local _, qText = D.qualitaet(wert)
	local maxId = 0
	for _, t in status.Tiere do maxId = math.max(maxId, t.id) end
	versteckAb = maxId + 1
	local ok, res = pcall(function() return R.Pusten:InvokeServer(wert) end)
	if not ok or not res or res.fehler then
		meldung(if ok and res then res.fehler else "Fehler beim Pusten", "schlecht")
		versteckAb = math.huge
		pustetGerade = false
		return
	end
	grosserText(qText, if res.serie > 0 then "Serie x" .. res.serie .. " · +" .. res.serie * 10 .. "% Glück" else "", if qText == "PERFEKT!" then rgb(120, 255, 140) elseif qText == "GUT" then rgb(255, 220, 80) else rgb(255, 120, 120))
	serieText.Text = if res.serie > 0 then "Serie x" .. res.serie else ""
	local hrp = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
	local startPos = Vector3.new(0, 9, 0) -- im Blasenring vorne am Wurfdeck
	local ok2, err = pcall(sequenz, res, startPos)
	if not ok2 then
		warn("Sequenz-Fehler:", err)
		seqOrdner:ClearAllChildren()
		kameraZurueck()
		vignette.Visible = false
		enthHUD.Visible = false
		flugHUD.Visible = false
		schwarz.BackgroundTransparency = 1
	end
	versteckAb = math.huge
	rucksackZeichnen()
	if tierFenster.Visible then tierFensterZeichnen() end
	pustetGerade = false
end
pustKnopf.Activated:Connect(pusten)
UIS.InputBegan:Connect(function(i, verarbeitet)
	if verarbeitet then return end
	if i.KeyCode == Enum.KeyCode.E or i.KeyCode == Enum.KeyCode.Return then pusten() end
end)

-- ===== Fenster: Tier-Index =====
local indexFenster, indexInhalt = fenster("Tier-Index", 640, 520)
local indexZaehler = text({ Size = UDim2.fromOffset(300, 36), Position = UDim2.new(1, -316, 1, -46), Text = "", TextColor3 = rgb(70, 140, 230), ZIndex = 21, Parent = indexFenster })

local function vorschau(parent, artId, silhouette)
	local vp = neu("ViewportFrame", { Size = UDim2.new(1, 0, 0.72, 0), BackgroundTransparency = 1, ZIndex = parent.ZIndex + 1, Parent = parent })
	local m = TM.bauen(artId, 1, 1)
	if not m then return end
	if silhouette then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = rgb(25, 25, 35)
				p.Material = Enum.Material.SmoothPlastic
			elseif p:IsA("ParticleEmitter") or p:IsA("PointLight") then
				p:Destroy()
			end
		end
	end
	m:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	m.Parent = vp
	local h = TM.hoehe(m)
	local a = m:GetExtentsSize()
	local vc = Instance.new("Camera")
	vc.FieldOfView = 40
	local dist = math.max(h, a.Z, a.X) * 1.35
	vc.CFrame = CFrame.lookAt(Vector3.new(dist * 0.35, h * 0.75, -dist), Vector3.new(0, h * 0.45, 0))
	vc.Parent = vp
	vp.CurrentCamera = vc
end

local function indexZeichnen()
	for _, c in indexInhalt:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local gesamt, hat = 0, 0
	for bi, b in D.Biome do
		local kopf = text({ Size = UDim2.new(1, -10, 0, 30), Text = b.name, TextColor3 = rgb(70, 140, 230), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = bi * 10, ZIndex = 21, Parent = indexInhalt })
		local reihe = neu("Frame", { Size = UDim2.new(1, -10, 0, 96), BackgroundTransparency = 1, LayoutOrder = bi * 10 + 1, ZIndex = 21, Parent = indexInhalt }, {
			neu("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local n, voll = 0, 0
		for i, t in D.TierListe do
			if t.biom == b.id then
				voll += 1
				local bekannt = status.Index[t.id]
				if bekannt then n += 1 end
				local farbe = D.Seltenheit[t.selten].farbe
				local kachel = neu("Frame", { Size = UDim2.fromOffset(80, 92), BackgroundColor3 = if bekannt then rgb(255, 255, 255) else rgb(205, 210, 220), LayoutOrder = i, ZIndex = 22, Parent = reihe }, { ecke(10), rand(3, farbe) })
				vorschau(kachel, t.id, not bekannt)
				text({ Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 1, -24), Text = if bekannt then t.name else "???", TextColor3 = if bekannt then farbe else rgb(90, 95, 110), ZIndex = 23, Parent = kachel })
			end
		end
		gesamt += voll
		hat += n
		kopf.Text = b.name .. "  " .. n .. "/" .. voll .. (if status.IndexBelohnt[b.id] then "  · Belohnung erhalten" else "  · Belohnung: $" .. D.format(D.IndexBelohnung[b.id] or 0))
	end
	indexZaehler.Text = "Freigeschaltet: " .. hat .. "/" .. gesamt
end

-- ===== Fenster: Einstellungen =====
local optFenster, optInhalt = fenster("Einstellungen", 460, 260)
local schnellKnopf = knopf({ Size = UDim2.new(1, -10, 0, 56), Text = "", LayoutOrder = 1, ZIndex = 22, Parent = optInhalt }, rgb(150, 150, 160))
text({ Size = UDim2.new(1, -10, 0, 44), Text = "Überspringt die Tier-Sicht bei gewöhnlichen und ungewöhnlichen Tieren.", TextColor3 = rgb(80, 100, 130), RandDicke = 0, LayoutOrder = 2, ZIndex = 22, Parent = optInhalt })
local function optZeichnen()
	local an = status.Einstellungen and status.Einstellungen.Schnell
	schnellKnopf.Text = "Schnelle Enthüllung: " .. (if an then "AN" else "AUS")
	schnellKnopf.BackgroundColor3 = if an then rgb(90, 200, 110) else rgb(150, 150, 160)
end
schnellKnopf.Activated:Connect(function()
	R.Einstellung:FireServer("Schnell", not (status.Einstellungen and status.Einstellungen.Schnell))
end)
optZeichnen()

local function alleFensterZu()
	tierFenster.Visible, seifenFenster.Visible, indexFenster.Visible, optFenster.Visible = false, false, false, false
end
seitenKnopf("Index", 70, rgb(150, 110, 230), function()
	local war = indexFenster.Visible
	alleFensterZu()
	if not war then
		indexZeichnen()
		indexFenster.Visible = true
	end
end)
seitenKnopf("Optionen", 140, rgb(120, 130, 150), function()
	local war = optFenster.Visible
	alleFensterZu()
	optFenster.Visible = not war
end)

R.LadenOeffnen.OnClientEvent:Connect(function(art)
	if art == "tiere" then
		alleFensterZu()
		tierFensterZeichnen()
		tierFenster.Visible = true
	elseif art == "index" then
		alleFensterZu()
		indexZeichnen()
		indexFenster.Visible = true
	end
end)

local ersterStatus = true
R.Status.OnClientEvent:Connect(function(s)
	local altPlaetze = status.Plaetze
	status = s
	status.IndexBelohnt = status.IndexBelohnt or {}
	status.Einstellungen = status.Einstellungen or { Schnell = false }
	rucksackZeichnen()
	if tierFenster.Visible then tierFensterZeichnen() end
	if seifenFenster.Visible then seifenZeichnen() end
	if indexFenster.Visible then indexZeichnen() end
	optZeichnen()
	if not ersterStatus and s.Plaetze > altPlaetze then
		task.delay(0.4, function()
			grosserText("GEHEGE VERGRÖSSERT!", "Platz für " .. s.Plaetze .. " Tiere", rgb(140, 255, 160))
			konfetti()
		end)
	end
	ersterStatus = false
end)

-- ===== x2-Blase beim Training =====
local x2Knopf = knopf({ Size = UDim2.fromOffset(110, 110), Text = "x2", Visible = false, ZIndex = 30, Parent = gui }, rgb(255, 140, 40))
x2Knopf:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
local x2Skala = neu("UIScale", { Parent = x2Knopf })
local x2Version = 0
R.X2Angebot.OnClientEvent:Connect(function()
	x2Version += 1
	local v = x2Version
	x2Knopf.Position = UDim2.new(rng:NextNumber(0.25, 0.65), 0, rng:NextNumber(0.25, 0.55), 0)
	x2Knopf.Visible = true
	task.spawn(function()
		while x2Knopf.Visible and v == x2Version do
			x2Skala.Scale = 1 + math.sin(os.clock() * 8) * 0.08
			RunService.RenderStepped:Wait()
		end
	end)
	task.delay(6, function()
		if v == x2Version then x2Knopf.Visible = false end
	end)
end)
x2Knopf.Activated:Connect(function()
	x2Knopf.Visible = false
	R.X2Nehmen:FireServer()
end)
R.X2Aktiv.OnClientEvent:Connect(function(sek)
	trainTitel.Text = "x2 TRAINING!"
	trainTitel.TextColor3 = rgb(255, 160, 50)
	task.delay(sek, function()
		trainTitel.Text = "Tritt auf den Blasebalg!"
		trainTitel.TextColor3 = rgb(255, 255, 255)
	end)
end)

-- ===== Einfuehrung (erste Minute) =====
local tutText = text({ Size = UDim2.fromOffset(760, 40), Position = UDim2.new(0.5, -380, 0, 160), Text = "", TextColor3 = rgb(255, 230, 80), Visible = false, RandDicke = 3, Parent = gui })
local tutPfeil = text({ Size = UDim2.fromOffset(60, 50), Position = UDim2.new(0.5, -30, 1, -175), Text = "▼", TextColor3 = rgb(255, 220, 40), Visible = false, Parent = gui })
local TUT_TEXT = {
	"Stell dich in den Kreis bei deinem Blasebalg!",
	"Geh zum Wurfplatz und puste deine erste Blase!",
	"Klick dein Tier im Rucksack an und stell es ins Gehege!",
}
local a0 = Instance.new("Attachment")
a0.Parent = workspace.Terrain
local a1 = Instance.new("Attachment")
a1.Parent = workspace.Terrain
local beam = neu("Beam", { Color = ColorSequence.new(rgb(255, 220, 40)), Width0 = 0.8, Width1 = 0.8, FaceCamera = true, LightEmission = 1, Transparency = NumberSequence.new(0.25), Segments = 1, Enabled = false, Attachment0 = a0, Attachment1 = a1, Parent = workspace.Terrain })
RunService.Heartbeat:Connect(function()
	local schritt = spieler:GetAttribute("Tutorial") or 4
	local aktiv = schritt < 4 and not pustetGerade
	tutText.Visible = aktiv
	tutPfeil.Visible = aktiv and schritt == 3
	beam.Enabled = false
	if not aktiv then return end
	tutText.Text = TUT_TEXT[schritt] or ""
	if schritt == 3 then
		tutPfeil.Position = UDim2.new(0.5, -30, 1, -175 + math.sin(os.clock() * 6) * 6)
		return
	end
	local hrp = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
	local g = meinGrundstueck()
	local wp = Map:FindFirstChild("Wurfplatz")
	local ziel = if schritt == 1 then (g and g:FindFirstChild("TrainKreis")) else (wp and wp:FindFirstChild("Platte"))
	if hrp and ziel then
		a0.WorldPosition = hrp.Position - Vector3.new(0, 2.5, 0)
		a1.WorldPosition = ziel.Position + Vector3.new(0, 0.6, 0)
		beam.Enabled = (hrp.Position - ziel.Position).Magnitude > 9
	end
end)

-- ===== Gehege-Tiere laufen herum (nur lokal), Vögel schweben und schlagen mit den Flügeln =====
local wandern = {} -- [model] = Zustand
RunService.Heartbeat:Connect(function(dt)
	local kp = cam.CFrame.Position
	local zeit = os.clock()
	for _, g in Grund:GetChildren() do
		local ordner = g:FindFirstChild("GehegeTiere")
		local fl = g:FindFirstChild("GehegeFlaeche")
		if not ordner or not fl or (fl.Position - kp).Magnitude > 260 then continue end
		for _, m in ordner:GetChildren() do
			if not m:IsA("Model") or not m.PrimaryPart then continue end
			local w = wandern[m]
			if not w then
				local pv = m:GetPivot()
				w = { pos = pv.Position, blick = pv.LookVector, warte = rng:NextNumber(0, 3), tempo = rng:NextNumber(3, 5), phase = rng:NextNumber(0, 6), schwebt = m:GetAttribute("Schwebt"), fluegel = {} }
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") and p.Name == "Fluegel" then w.fluegel[p] = pv:ToObjectSpace(p.CFrame) end
				end
				wandern[m] = w
				m.Destroying:Once(function() wandern[m] = nil end)
			end
			local hop = 0
			if w.warte > 0 then
				w.warte -= dt
			else
				if not w.ziel then
					local s = fl.Size
					local z = fl.CFrame * CFrame.new(rng:NextNumber(-s.X / 2 + 4, s.X / 2 - 4), 0, rng:NextNumber(-s.Z / 2 + 4, s.Z / 2 - 4))
					w.ziel = Vector3.new(z.X, w.pos.Y, z.Z)
				end
				local weg = w.ziel - w.pos
				if weg.Magnitude < 0.5 then
					w.ziel = nil
					w.warte = rng:NextNumber(1.5, 5)
				else
					w.pos += weg.Unit * math.min(weg.Magnitude, w.tempo * dt)
					w.blick = weg.Unit
					w.phase += dt * 10
					hop = math.abs(math.sin(w.phase)) * 0.4
				end
			end
			if w.schwebt then hop = 2.5 + math.sin(zeit * 2 + w.phase) * 0.5 end
			local cf = CFrame.lookAt(w.pos, w.pos + Vector3.new(w.blick.X, 0, w.blick.Z)) + Vector3.new(0, hop, 0)
			m:PivotTo(cf)
			if next(w.fluegel) then
				local ang = math.sin(zeit * (if w.schwebt then 12 else 3) + w.phase) * (if w.schwebt then 0.6 else 0.15)
				for p, off in w.fluegel do
					local seite = if off.Position.X < 0 then -1 else 1
					local scharnier = -seite * p.Size.X / 2
					p.CFrame = cf * off * CFrame.new(scharnier, p.Size.Y / 2, 0) * CFrame.Angles(0, 0, seite * ang) * CFrame.new(-scharnier, -p.Size.Y / 2, 0)
				end
			end
		end
	end
end)

print("Bubble Safari Client bereit")
