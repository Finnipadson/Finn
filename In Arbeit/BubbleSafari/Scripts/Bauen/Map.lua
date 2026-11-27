-- Bubble Safari: Welt bauen (einmalig per execute_luau: loadstring(GetAsync(".../Bauen/Map.lua"))())
-- Koordinaten: Plateau Y=60 (Grundstuecke, Hub), Tal-Boden Y=0, Tal X -220..220, Z 0..2420 (+Z = Flugrichtung)
local rng = Random.new(42)
local V, CF = Vector3.new, CFrame.new
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local alt = workspace:FindFirstChild("Map")
if alt then alt:Destroy() end
for _, n in { "Baseplate", "_Tierschau" } do
	local x = workspace:FindFirstChild(n)
	if x then x:Destroy() end
end

local Map = Instance.new("Folder")
Map.Name = "Map"
Map.Parent = workspace

local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do p[k] = v end
	end
	p.Parent = parent
	return p
end
local function deko(parent, name, size, cf, color, mat, extra)
	local p = P(parent, name, size, cf, color, mat, extra)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end
local function ordner(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or Map
	return f
end
local function schildText(part, text, farbe, seite)
	local sg = Instance.new("SurfaceGui")
	sg.Face = seite or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 8
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = farbe or rgb(255, 255, 255)
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = rgb(40, 40, 60)
	st.Parent = t
	t.Parent = sg
end

-- ===== Plateau, Klippen, Tal-Grundform =====
local Gelaende = ordner("Gelaende")
local GRAS1, GRAS2, ERDE = rgb(110, 200, 80), rgb(100, 188, 72), rgb(150, 105, 65)
P(Gelaende, "Plateau", V(800, 60, 400), CF(0, 30, -200), ERDE, Enum.Material.SmoothPlastic)
for ix = -10, 9 do
	for iz = -10, -1 do
		local c = if (ix + iz) % 2 == 0 then GRAS1 else GRAS2
		P(Gelaende, "Gras", V(40, 1, 40), CF(ix * 40 + 20, 60, iz * 40 + 20), c, Enum.Material.SmoothPlastic)
	end
end
task.wait()
for _, s in { -1, 1 } do
	P(Gelaende, "Seitenplateau", V(200, 60, 2440), CF(s * 320, 30, 1220), ERDE)
	P(Gelaende, "SeitenGras", V(200, 1, 2440), CF(s * 320, 60, 1220), GRAS1)
	for z = 0, 2420, 20 do
		local d = rng:NextNumber(6, 16)
		local h = rng:NextInteger(50, 66)
		local x = s * (220 - d / 2)
		P(Gelaende, "Klippe", V(d, h - 6, 20), CF(x, (h - 6) / 2, z + 10), if (z / 20) % 2 == 0 then ERDE else rgb(140, 97, 60))
		P(Gelaende, "KlippeGras", V(d + 1, 6, 20), CF(x, h - 3, z + 10), if (z / 20) % 2 == 0 then GRAS1 else GRAS2)
	end
	task.wait()
end
P(Gelaende, "TalEnde", V(460, 70, 20), CF(0, 35, 2430), ERDE)
P(Gelaende, "TalBoden", V(440, 10, 2440), CF(0, -5.5, 1220), ERDE)
-- Absperrungen (unsichtbar)
local function wand(size, cf)
	P(Gelaende, "Absperrung", size, cf, rgb(255, 255, 255), nil, { Transparency = 1 })
end
wand(V(800, 40, 1), CF(0, 80, 0.5))
wand(V(800, 40, 1), CF(0, 80, -400))
wand(V(1, 40, 400), CF(-400, 80, -200))
wand(V(1, 40, 400), CF(400, 80, -200))

-- ===== Tal-Biome =====
local BIOME = {
	{ id = "Wiese", name = "BLUMENWIESE", von = 0, bis = 600, b1 = rgb(125, 210, 95), b2 = rgb(115, 198, 88) },
	{ id = "Pilzwald", name = "PILZWALD", von = 600, bis = 1400, b1 = rgb(70, 120, 90), b2 = rgb(62, 110, 82) },
	{ id = "Sumpf", name = "SUMPF", von = 1400, bis = 2420, b1 = rgb(100, 115, 72), b2 = rgb(90, 105, 65) },
}
local Tal = ordner("Tal")
for _, b in BIOME do
	local f = ordner(b.id, Tal)
	local boden = ordner("Boden", f)
	for z = b.von, b.bis - 40, 40 do
		for x = -220, 180, 40 do
			local c = if ((x + 220) / 40 + z / 40) % 2 == 0 then b.b1 else b.b2
			P(boden, "Boden", V(40, 1, 40), CF(x + 20, -0.5, z + 20), c)
		end
	end
	-- Schild am Biom-Anfang (an beiden Waenden)
	for _, s in { -1, 1 } do
		local sp = deko(f, "BiomSchild", V(1, 14, 70), CF(s * 199, 40, b.von + 45), rgb(255, 245, 220))
		schildText(sp, b.name, rgb(255, 255, 255), if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left)
		sp.Color = rgb(90, 70, 50)
	end
	task.wait()
end

local function zufallsPos(b, rand)
	return rng:NextNumber(-205, 205), rng:NextNumber(b.von + (rand or 10), b.bis - (rand or 10))
end

-- Blumenwiese
do
	local f = Tal.Wiese
	local farben = { rgb(255, 120, 170), rgb(255, 215, 60), rgb(190, 140, 255), rgb(255, 255, 255), rgb(255, 140, 80) }
	local d = ordner("Deko", f)
	-- Blumen in Gruppen (Felder), damit es aus der Luft bunt wirkt
	for gruppe = 1, 70 do
		local gx, gz = zufallsPos(BIOME[1])
		local farbe = farben[rng:NextInteger(1, #farben)]
		for i = 1, rng:NextInteger(6, 12) do
			local x, z = gx + rng:NextNumber(-8, 8), gz + rng:NextNumber(-8, 8)
			local h = rng:NextNumber(1, 2.5)
			deko(d, "Stiel", V(0.35, h, 0.35), CF(x, h / 2, z), rgb(70, 150, 60))
			deko(d, "Bluete", V(1.8, 0.6, 1.8), CF(x, h + 0.2, z), farbe)
			deko(d, "Mitte", V(0.7, 0.3, 0.7), CF(x, h + 0.55, z), rgb(255, 230, 90))
		end
		if gruppe % 15 == 0 then task.wait() end
	end
	for i = 1, 55 do
		local x, z = zufallsPos(BIOME[1])
		local s = rng:NextNumber(4, 8)
		deko(d, "Busch", V(s, s * 0.7, s), CF(x, s * 0.35, z), rgb(80, 170, 70))
		if rng:NextNumber() < 0.5 then
			deko(d, "Bluete", V(1.2, 0.8, 1.2), CF(x + s * 0.2, s * 0.72, z - s * 0.1), farben[rng:NextInteger(1, #farben)])
		end
	end
	for i = 1, 22 do -- Bluetenbaeume
		local x, z = zufallsPos(BIOME[1])
		local h = rng:NextNumber(10, 16)
		deko(d, "Stamm", V(2, h, 2), CF(x, h / 2, z), rgb(120, 85, 55))
		local k = rng:NextNumber(9, 13)
		deko(d, "Krone", V(k, k * 0.65, k), CF(x, h + k * 0.15, z), if i % 2 == 0 then rgb(255, 180, 210) else rgb(255, 225, 235))
	end
	-- Landmarke: Riesen-Gaensebluemchen
	local lm = ordner("Landmarke", f)
	deko(lm, "Stiel", V(4, 70, 4), CF(110, 35, 380), rgb(70, 160, 60))
	deko(lm, "Blatt", V(14, 2, 6), CF(116, 20, 380) * CFrame.Angles(0, 0, math.rad(20)), rgb(80, 175, 65))
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		deko(lm, "Blatt", V(6, 1.6, 16), CF(110, 70, 380) * CFrame.Angles(0, a, 0) * CF(0, 0, 11), rgb(255, 255, 255))
	end
	deko(lm, "Mitte", V(14, 4, 14), CF(110, 71, 380), rgb(255, 210, 40))
	task.wait()
end

-- Pilzwald
do
	local f = Tal.Pilzwald
	local d = ordner("Deko", f)
	local kappen = { rgb(210, 50, 50), rgb(150, 80, 210), rgb(90, 140, 230), rgb(160, 105, 65) }
	for i = 1, 130 do
		local x, z = zufallsPos(BIOME[2])
		local s = rng:NextNumber(1.5, 8)
		local stiel = deko(d, "Stiel", V(s * 0.35, s, s * 0.35), CF(x, s / 2, z), rgb(235, 225, 200))
		local leucht = rng:NextNumber() < 0.3
		local k = deko(d, "Kappe", V(s * 1.1, s * 0.35, s * 1.1), CF(x, s + s * 0.15, z),
			if leucht then rgb(90, 240, 255) else kappen[rng:NextInteger(1, #kappen)],
			if leucht then Enum.Material.Neon else nil)
		if not leucht and rng:NextNumber() < 0.5 then
			deko(d, "Punkt", V(s * 0.25, 0.1, s * 0.25), CF(x + s * 0.2, s + s * 0.33, z - s * 0.15), rgb(255, 255, 255))
		end
		if i % 50 == 0 then task.wait() end
	end
	for i = 1, 55 do
		local x, z = zufallsPos(BIOME[2])
		local h = rng:NextNumber(14, 26)
		deko(d, "Stamm", V(2.5, h, 2.5), CF(x, h / 2, z), rgb(90, 65, 45))
		local k = rng:NextNumber(10, 16)
		deko(d, "Krone", V(k, k * 0.7, k), CF(x, h + k * 0.2, z), rgb(40, 95, 60))
		deko(d, "Krone", V(k * 0.6, k * 0.5, k * 0.6), CF(x, h + k * 0.6, z), rgb(50, 110, 70))
	end
	local lm = ordner("Landmarke", f)
	deko(lm, "Stiel", V(14, 90, 14), CF(-100, 45, 1100), rgb(235, 225, 210))
	deko(lm, "Kappe", V(80, 22, 80), CF(-100, 98, 1100), rgb(170, 90, 230))
	deko(lm, "Kappe", V(56, 10, 56), CF(-100, 113, 1100), rgb(185, 110, 240))
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 32)
		deko(lm, "Punkt", V(7, 2, 7), CF(-100 + math.cos(a) * r, 110, 1100 + math.sin(a) * r), rgb(120, 250, 255), Enum.Material.Neon)
	end
	local licht = Instance.new("PointLight")
	licht.Color = rgb(170, 110, 255)
	licht.Range = 60
	licht.Brightness = 2
	licht.Parent = lm.Kappe
	task.wait()
end

-- Sumpf
do
	local f = Tal.Sumpf
	local d = ordner("Deko", f)
	for i = 1, 30 do
		local x, z = zufallsPos(BIOME[3], 30)
		local w, l = rng:NextNumber(18, 45), rng:NextNumber(18, 45)
		deko(d, "Wasser", V(w, 0.4, l), CF(x, 0.1, z), rgb(70, 115, 105), Enum.Material.Glass, { Transparency = 0.25 })
		for j = 1, rng:NextInteger(2, 5) do
			local px, pz = x + rng:NextNumber(-w / 3, w / 3), z + rng:NextNumber(-l / 3, l / 3)
			deko(d, "Seerose", V(3, 0.2, 3), CF(px, 0.4, pz), rgb(70, 150, 70))
			if rng:NextNumber() < 0.4 then
				deko(d, "Bluete", V(1, 0.6, 1), CF(px, 0.7, pz), rgb(255, 160, 210))
			end
		end
	end
	task.wait()
	for i = 1, 160 do
		local x, z = zufallsPos(BIOME[3])
		for j = 1, 3 do
			local h = rng:NextNumber(3, 6)
			local ox, oz = rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
			deko(d, "Schilf", V(0.3, h, 0.3), CF(x + ox, h / 2, z + oz), rgb(110, 150, 60))
			if j == 1 then deko(d, "Kolben", V(0.6, 1.2, 0.6), CF(x + ox, h, z + oz), rgb(110, 70, 40)) end
		end
		if i % 50 == 0 then task.wait() end
	end
	for i = 1, 40 do
		local x, z = zufallsPos(BIOME[3])
		local h = rng:NextNumber(12, 22)
		local neig = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
		local stamm = deko(d, "Stamm", V(2.5, h, 2.5), CF(x, h / 2, z) * neig, rgb(85, 75, 60))
		local top = stamm.CFrame * CF(0, h / 2, 0)
		deko(d, "Krone", V(12, 6, 12), CF(top.Position), rgb(95, 120, 70))
		for j = 1, 3 do
			deko(d, "Moos", V(0.6, 6, 0.6), CF(top.Position + V(rng:NextNumber(-5, 5), -5, rng:NextNumber(-5, 5))), rgb(120, 140, 90))
		end
	end
	local lm = ordner("Landmarke", f)
	local basis = V(70, 0, 2000)
	local pos = basis
	for i = 1, 6 do
		local seg = deko(lm, "Stamm", V(12 - i, 16, 12 - i), CF(pos + V(0, 8, 0)) * CFrame.Angles(0, 0, math.rad((i % 2 == 0) and 12 or -12)), rgb(80, 70, 55))
		pos = (seg.CFrame * CF(0, 8, 0)).Position
	end
	deko(lm, "Krone", V(60, 18, 60), CF(pos + V(0, 4, 0)), rgb(85, 115, 65))
	deko(lm, "Krone", V(40, 12, 40), CF(pos + V(0, 16, 0)), rgb(95, 125, 72))
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		deko(lm, "Moos", V(1.2, 16, 1.2), CF(pos + V(math.cos(a) * 26, -6, math.sin(a) * 26)), rgb(120, 140, 90))
	end
	task.wait()
end

-- ===== Grundstuecke + Pustplaetze =====
local Grund = ordner("Grundstuecke")
local XS = { -150, -50, 50, 150 }
for i, cx in XS do
	local g = Instance.new("Model")
	g.Name = "Grundstueck" .. i
	g:SetAttribute("Nummer", i)
	g:SetAttribute("Besitzer", 0)
	local c = CF(cx, 60, -60) -- Mitte, Boden-Oberkante 60
	local function L(x, y, z) return c * CF(x, y, z) end -- lokal: +Z Richtung Tal
	P(g, "Boden", V(90, 1, 100), L(0, 0.55, 0), rgb(235, 225, 195))
	for _, s in { -1, 1 } do
		P(g, "Rand", V(1.5, 1.2, 100), L(s * 44.25, 0.7, 0), rgb(190, 160, 120))
	end
	-- Gehege
	local geh = P(g, "GehegeFlaeche", V(40, 0.4, 75), L(-20, 1.2, -2.5), rgb(120, 205, 90))
	geh.CanCollide = true
	local zaun = ordner("Zaun", g)
	local function zaunStueck(a, b)
		local d = (b - a)
		local n = math.max(1, math.floor(d.Magnitude / 5))
		for k = 0, n do
			local p = a + d * (k / n)
			deko(zaun, "Pfosten", V(0.8, 4, 0.8), CF(p + V(0, 2, 0)), rgb(250, 250, 250))
		end
		local mitte = (a + b) / 2
		for _, h in { 1.6, 3.2 } do
			deko(zaun, "Latte", V(0.4, 0.5, d.Magnitude), CF(mitte + V(0, h, 0), mitte + V(0, h, 0) + d.Unit), rgb(250, 250, 250))
		end
	end
	local y = 61.2
	local x1, x2, z1, z2 = cx - 40, cx, -60 - 40, -60 + 35
	zaunStueck(V(x1, y, z1), V(x2, y, z1))
	zaunStueck(V(x1, y, z2), V(x2, y, z2))
	zaunStueck(V(x1, y, z1), V(x1, y, z2))
	zaunStueck(V(x2, y, z1), V(x2, y, -65))
	zaunStueck(V(x2, y, -55), V(x2, y, z2))
	-- Blasebalg-Platz
	local kreis = deko(g, "TrainKreis", V(0.3, 15, 15), L(22, 1.2, -20) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 255, 255),
		Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Transparency = 0.35 })
	deko(g, "BlasebalgAnker", V(1, 1, 1), L(22, 1.2, -20), rgb(255, 255, 255), nil, { Transparency = 1 })
	-- Aufwerten-Schild
	deko(g, "SchildPfosten", V(0.8, 6, 0.8), L(34, 4, -32), rgb(120, 85, 55))
	local sch = P(g, "AufwertenSchild", V(7, 4, 0.5), L(34, 7.5, -32) * CFrame.Angles(0, math.rad(200), 0), rgb(120, 85, 55))
	-- Anzeige-Anker fuer Name + $/s
	deko(g, "SchildAnker", V(1, 1, 1), L(0, 30, -10), rgb(255, 255, 255), nil, { Transparency = 1 })
	-- Weg zum Pustplatz
	P(g, "Weg", V(10, 0.2, 14), L(22, 1.1, 43), rgb(215, 205, 180))
	g.Parent = Grund

	-- Pustplatz an der Kante (vor dem Grundstueck)
	local pp = Instance.new("Model")
	pp.Name = "Pustplatz" .. i
	pp:SetAttribute("Nummer", i)
	local platte = P(pp, "Platte", V(1.2, 13, 13), CF(cx + 22, 60.6, -6.5) * CFrame.Angles(0, 0, math.rad(90)), rgb(150, 210, 255),
		nil, { Shape = Enum.PartType.Cylinder })
	pp.PrimaryPart = platte
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		deko(pp, "Ring", V(0.8, 0.8, 0.8), CF(cx + 22 + math.cos(a) * 1.6, 66 + math.sin(a) * 1.6, -11.5), rgb(255, 255, 255))
	end
	deko(pp, "Stab", V(0.4, 4, 0.4), CF(cx + 22, 62.6, -11.5), rgb(255, 255, 255))
	pp.Parent = Grund
	task.wait()
end

-- ===== Hub =====
local Hub = ordner("Hub")
P(Hub, "Platz", V(1.2, 90, 90), CF(0, 60.1, -190) * CFrame.Angles(0, 0, math.rad(90)), rgb(220, 220, 230), nil, { Shape = Enum.PartType.Cylinder })
P(Hub, "WegHub", V(12, 0.2, 40), CF(0, 60.6, -130), rgb(215, 205, 180))
P(Hub, "WegQuer", V(400, 0.2, 10), CF(0, 60.6, -115), rgb(215, 205, 180))
-- Brunnen mit Seifenblasen
P(Hub, "Becken", V(3, 18, 18), CF(0, 61.5, -195) * CFrame.Angles(0, 0, math.rad(90)), rgb(190, 200, 215), nil, { Shape = Enum.PartType.Cylinder })
local wasser = deko(Hub, "Wasser", V(0.4, 16, 16), CF(0, 63, -195) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 200, 255), Enum.Material.Glass,
	{ Shape = Enum.PartType.Cylinder, Transparency = 0.3 })
local pe = Instance.new("ParticleEmitter")
pe.Color = ColorSequence.new(rgb(200, 235, 255), rgb(255, 200, 240))
pe.Size = NumberSequence.new(0.8, 1.6)
pe.Transparency = NumberSequence.new(0.3, 0.8)
pe.LightEmission = 0.4
pe.Rate = 8
pe.Lifetime = NumberRange.new(3, 5)
pe.Speed = NumberRange.new(2, 4)
pe.SpreadAngle = Vector2.new(30, 30)
pe.EmissionDirection = Enum.NormalId.Right
pe.Parent = wasser
-- Seifenladen
local laden = Instance.new("Model")
laden.Name = "Seifenladen"
local theke = P(laden, "Theke", V(18, 4, 5), CF(-38, 62.5, -200) * CFrame.Angles(0, math.rad(60), 0), rgb(240, 240, 250))
for k = -1, 1, 2 do
	deko(laden, "Pfosten", V(1, 12, 1), theke.CFrame * CF(k * 8.5, 4, 3), rgb(255, 255, 255))
end
for k = 0, 5 do
	deko(laden, "Markise", V(3.2, 0.6, 8), theke.CFrame * CF(-7.5 + k * 3, 10, 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		if k % 2 == 0 then rgb(80, 170, 255) else rgb(255, 255, 255))
end
local ls = deko(laden, "LadenSchild", V(14, 3.5, 0.5), theke.CFrame * CF(0, 12.2, 3.6), rgb(80, 170, 255))
schildText(ls, "SEIFENLADEN", rgb(255, 255, 255), Enum.NormalId.Back)
for k = -2, 2 do
	deko(laden, "Seife", V(1.6, 1, 1.2), theke.CFrame * CF(k * 3, 2.5, 0), ({ rgb(235, 245, 255), rgb(255, 200, 70), rgb(110, 240, 190), rgb(255, 150, 200), rgb(190, 140, 255) })[k + 3])
end
laden.PrimaryPart = theke
laden.Parent = Hub

local spawn = workspace:FindFirstChild("SpawnLocation")
if spawn then
	spawn.CFrame = CF(0, 60.7, -165)
	spawn.Size = V(8, 1, 8)
	spawn.Transparency = 1
	local dec = spawn:FindFirstChildOfClass("Decal")
	if dec then dec:Destroy() end
end

local L = game:GetService("Lighting")
L.ClockTime = 14
L.Brightness = 2.5
local atm = L:FindFirstChildOfClass("Atmosphere")
if atm then atm.Density = 0.18; atm.Haze = 0.6 end
workspace.StreamingEnabled = false -- Phase 1: Tal ist klein genug; spaeter Streaming + Persistent pruefen
return "Map fertig"
