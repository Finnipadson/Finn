-- Bubble Safari: Welt bauen (per execute_luau: loadstring(GetAsync(".../Bauen/Map.lua"))())
-- Aufbau wie ein Kessel mit Schlucht: Boden ueberall Y=0, Klippen Y=0..RAND ringsum.
--   Kessel (Grundstuecke, Spawn, Laden): X -150..150, Z -200..0
--   Wurfplatz in der Mitte am Schlucht-Eingang (0, 0, -12)
--   Schlucht: X -50..50, Z 0..2420 (+Z = Flugrichtung), Biome hintereinander
local rng = Random.new(42)
local V, CF = Vector3.new, CFrame.new
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local RAND = 45 -- Hoehe der Klippen-Oberkante
local SB = 50 -- halbe Schluchtbreite (Schlucht 100 breit)
local KX, KZ = 150, -200 -- Kessel: X -KX..KX, Z KZ..0
local ENDE = 2420

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

local GRAS1, GRAS2 = rgb(110, 200, 80), rgb(98, 186, 70)
local ERDE1, ERDE2 = rgb(150, 105, 65), rgb(136, 94, 58)

-- ===== Gelaende: Hochebene rundherum (Bloecke 0..RAND) =====
local Gelaende = ordner("Gelaende")
local function hochebene(x1, x2, z1, z2)
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	P(Gelaende, "Hochebene", V(x2 - x1, RAND, z2 - z1), CF(mx, RAND / 2, mz), ERDE1)
	P(Gelaende, "HochGras", V(x2 - x1, 1, z2 - z1), CF(mx, RAND + 0.5, mz), GRAS1)
end
hochebene(-KX - 110, KX + 110, KZ - 110, KZ) -- hinten
hochebene(-KX - 110, -KX, KZ, 0) -- links neben Kessel
hochebene(KX, KX + 110, KZ, 0) -- rechts neben Kessel
hochebene(-KX - 110, -SB, 0, ENDE + 40) -- links der Schlucht (inkl. Kessel-Vorderwand)
hochebene(SB, KX + 110, 0, ENDE + 40) -- rechts der Schlucht
hochebene(-SB, SB, ENDE, ENDE + 40) -- Schlucht-Ende
task.wait()

-- Voxel-Klippen: Saeulen an den Innenwaenden, mit Gras-Kappe (Ueberhang wie im Vorbild)
local function wandReihe(a, b, innen, breite)
	local laenge = (b - a).Magnitude
	local richtung = (b - a).Unit
	local n = math.floor(laenge / breite)
	for i = 0, n - 1 do
		local mitte = a + richtung * (i + 0.5) * breite
		local d = rng:NextNumber(2, 7)
		local h = RAND + rng:NextInteger(-6, 4)
		local cf = CFrame.lookAt(mitte + innen * (d / 2), mitte + innen * (d / 2) + richtung)
		local erde = if i % 2 == 0 then ERDE1 else ERDE2
		P(Gelaende, "Klippe", V(d, h - 5, breite), cf * CF(0, (h - 5) / 2, 0), erde)
		P(Gelaende, "KlippeGras", V(d + 1.5, 5, breite), cf * CF(0, h - 2.5, 0), if i % 2 == 0 then GRAS1 else GRAS2)
		if i % 10 == 9 then task.wait() end
	end
end
wandReihe(V(-KX, 0, KZ), V(KX, 0, KZ), V(0, 0, 1), 16) -- Kessel hinten
wandReihe(V(-KX, 0, KZ), V(-KX, 0, 0), V(1, 0, 0), 16) -- Kessel links
wandReihe(V(KX, 0, KZ), V(KX, 0, 0), V(-1, 0, 0), 16) -- Kessel rechts
wandReihe(V(-KX, 0, 0), V(-SB, 0, 0), V(0, 0, -1), 16) -- Kessel vorne links
wandReihe(V(SB, 0, 0), V(KX, 0, 0), V(0, 0, -1), 16) -- Kessel vorne rechts
wandReihe(V(-SB, 0, 0), V(-SB, 0, ENDE), V(1, 0, 0), 14) -- Schlucht links
wandReihe(V(SB, 0, 0), V(SB, 0, ENDE), V(-1, 0, 0), 14) -- Schlucht rechts
task.wait()

-- Kessel-Boden (Schachbrett)
local KB = ordner("KesselBoden", Gelaende)
for x = -KX, KX - 20, 20 do
	for z = KZ, -20, 20 do
		local c = if ((x + KX) / 20 + (z - KZ) / 20) % 2 == 0 then GRAS1 else GRAS2
		P(KB, "Boden", V(20, 1, 20), CF(x + 10, -0.5, z + 10), c)
	end
end
-- Unsichtbare Sperre am Schlucht-Eingang (Spieler bleiben im Kessel)
P(Gelaende, "Absperrung", V(SB * 2, 30, 1), CF(0, 15, 2), rgb(255, 255, 255), nil, { Transparency = 1 })
task.wait()

-- ===== Schlucht mit Biomen =====
local BIOME = {
	{ id = "Wiese", name = "BLUMENWIESE", von = 0, bis = 600, b1 = rgb(125, 210, 95), b2 = rgb(112, 196, 86) },
	{ id = "Pilzwald", name = "PILZWALD", von = 600, bis = 1400, b1 = rgb(70, 120, 90), b2 = rgb(60, 108, 80) },
	{ id = "Sumpf", name = "SUMPF", von = 1400, bis = ENDE, b1 = rgb(100, 115, 72), b2 = rgb(88, 103, 64) },
}
local Tal = ordner("Tal")
local KACHEL = 20
for _, b in BIOME do
	local f = ordner(b.id, Tal)
	local boden = ordner("Boden", f)
	local zi = 0
	for z = b.von, b.bis - KACHEL, KACHEL do
		zi += 1
		for xi = 0, (2 * SB) / KACHEL - 1 do
			local c = if (xi + zi) % 2 == 0 then b.b1 else b.b2
			P(boden, "Boden", V(KACHEL, 1, KACHEL), CF(-SB + xi * KACHEL + KACHEL / 2, -0.5, z + KACHEL / 2), c)
		end
		if zi % 40 == 0 then task.wait() end
	end
	-- Bogen mit Biom-Namen ueber der Schlucht
	if b.von > 0 then
		for _, s in { -1, 1 } do
			P(f, "BogenPfosten", V(3, 14, 3), CF(s * (SB + 3), RAND + 7, b.von), rgb(120, 85, 55))
		end
		local balken = P(f, "BiomBogen", V(SB * 2 + 12, 8, 1.5), CF(0, RAND + 12, b.von), rgb(120, 85, 55))
		schildText(balken, b.name, rgb(255, 255, 255), Enum.NormalId.Front)
		schildText(balken, b.name, rgb(255, 255, 255), Enum.NormalId.Back)
	end
	task.wait()
end

local function zufallsPos(b, rand)
	return rng:NextNumber(-SB + 5, SB - 5), rng:NextNumber(b.von + (rand or 10), b.bis - (rand or 10))
end
-- Position oben am Schluchtrand (links oder rechts)
local function randPos(b)
	local s = if rng:NextNumber() < 0.5 then -1 else 1
	return s * rng:NextNumber(SB + 8, SB + 90), rng:NextNumber(b.von + 5, b.bis - 5)
end

-- Blumenwiese
do
	local b = BIOME[1]
	local f = Tal.Wiese
	local farben = { rgb(255, 120, 170), rgb(255, 215, 60), rgb(190, 140, 255), rgb(255, 255, 255), rgb(255, 140, 80) }
	local d = ordner("Deko", f)
	local function blumenFeld(gx, gz, y, anzahl)
		local farbe = farben[rng:NextInteger(1, #farben)]
		for i = 1, anzahl do
			local x, z = gx + rng:NextNumber(-6, 6), gz + rng:NextNumber(-6, 6)
			local h = rng:NextNumber(1, 2.5)
			deko(d, "Stiel", V(0.35, h, 0.35), CF(x, y + h / 2, z), rgb(70, 150, 60))
			deko(d, "Bluete", V(1.8, 0.6, 1.8), CF(x, y + h + 0.2, z), farbe)
			deko(d, "Mitte", V(0.7, 0.3, 0.7), CF(x, y + h + 0.55, z), rgb(255, 230, 90))
		end
	end
	for i = 1, 22 do
		local x, z = zufallsPos(b)
		blumenFeld(x, z, 0, rng:NextInteger(5, 9))
	end
	for i = 1, 14 do
		local x, z = zufallsPos(b)
		local s = rng:NextNumber(3, 6)
		deko(d, "Busch", V(s, s * 0.7, s), CF(x, s * 0.35, z), rgb(80, 170, 70))
	end
	task.wait()
	-- oben am Rand: Bluetenbaeume + Blumen
	for i = 1, 40 do
		local x, z = randPos(b)
		if i % 3 == 0 then
			local h = rng:NextNumber(10, 16)
			deko(d, "Stamm", V(2, h, 2), CF(x, RAND + h / 2, z), rgb(120, 85, 55))
			local k = rng:NextNumber(9, 13)
			deko(d, "Krone", V(k, k * 0.65, k), CF(x, RAND + h + k * 0.15, z), if i % 2 == 0 then rgb(255, 180, 210) else rgb(255, 225, 235))
		else
			blumenFeld(x, z, RAND + 1, 5)
		end
	end
	-- Landmarke: Riesen-Gaensebluemchen am Rand
	local lm = ordner("Landmarke", f)
	local lx, lz = 62, 380
	deko(lm, "Stiel", V(4, 60, 4), CF(lx, RAND + 30, lz), rgb(70, 160, 60))
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		deko(lm, "Blatt", V(6, 1.6, 16), CF(lx, RAND + 60, lz) * CFrame.Angles(0, a, 0) * CF(0, 0, 11), rgb(255, 255, 255))
	end
	deko(lm, "Mitte", V(14, 4, 14), CF(lx, RAND + 61, lz), rgb(255, 210, 40))
	task.wait()
end

-- Pilzwald
do
	local b = BIOME[2]
	local f = Tal.Pilzwald
	local d = ordner("Deko", f)
	local kappen = { rgb(210, 50, 50), rgb(150, 80, 210), rgb(90, 140, 230), rgb(160, 105, 65) }
	local function pilz(x, y, z, s)
		deko(d, "Stiel", V(s * 0.35, s, s * 0.35), CF(x, y + s / 2, z), rgb(235, 225, 200))
		local leucht = rng:NextNumber() < 0.3
		deko(d, "Kappe", V(s * 1.1, s * 0.35, s * 1.1), CF(x, y + s + s * 0.15, z),
			if leucht then rgb(90, 240, 255) else kappen[rng:NextInteger(1, #kappen)],
			if leucht then Enum.Material.Neon else nil)
		if not leucht and rng:NextNumber() < 0.5 then
			deko(d, "Punkt", V(s * 0.25, 0.1, s * 0.25), CF(x + s * 0.2, y + s + s * 0.33, z - s * 0.15), rgb(255, 255, 255))
		end
	end
	for i = 1, 40 do
		local x, z = zufallsPos(b)
		pilz(x, 0, z, rng:NextNumber(1.5, 6))
	end
	for i = 1, 60 do
		local x, z = randPos(b)
		if i % 2 == 0 then
			local h = rng:NextNumber(14, 26)
			deko(d, "Stamm", V(2.5, h, 2.5), CF(x, RAND + h / 2, z), rgb(90, 65, 45))
			local k = rng:NextNumber(10, 16)
			deko(d, "Krone", V(k, k * 0.7, k), CF(x, RAND + h + k * 0.2, z), rgb(40, 95, 60))
		else
			pilz(x, RAND, z, rng:NextNumber(3, 10))
		end
		if i % 20 == 0 then task.wait() end
	end
	local lm = ordner("Landmarke", f)
	local lx, lz = -70, 1100
	deko(lm, "Stiel", V(12, 60, 12), CF(lx, RAND + 30, lz), rgb(235, 225, 210))
	deko(lm, "Kappe", V(60, 16, 60), CF(lx, RAND + 66, lz), rgb(170, 90, 230))
	deko(lm, "Kappe", V(42, 8, 42), CF(lx, RAND + 78, lz), rgb(185, 110, 240))
	for i = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(6, 24)
		deko(lm, "Punkt", V(6, 2, 6), CF(lx + math.cos(a) * r, RAND + 75, lz + math.sin(a) * r), rgb(120, 250, 255), Enum.Material.Neon)
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
	local b = BIOME[3]
	local f = Tal.Sumpf
	local d = ordner("Deko", f)
	for i = 1, 12 do
		local x, z = zufallsPos(b, 20)
		local w, l = rng:NextNumber(10, 22), rng:NextNumber(14, 30)
		x = math.clamp(x, -SB + w / 2, SB - w / 2)
		deko(d, "Wasser", V(w, 0.4, l), CF(x, 0.1, z), rgb(70, 115, 105), Enum.Material.Glass, { Transparency = 0.25 })
		for j = 1, rng:NextInteger(2, 4) do
			local px, pz = x + rng:NextNumber(-w / 3, w / 3), z + rng:NextNumber(-l / 3, l / 3)
			deko(d, "Seerose", V(3, 0.2, 3), CF(px, 0.4, pz), rgb(70, 150, 70))
			if rng:NextNumber() < 0.4 then deko(d, "Bluete", V(1, 0.6, 1), CF(px, 0.7, pz), rgb(255, 160, 210)) end
		end
	end
	local function schilf(x, y, z)
		for j = 1, 3 do
			local h = rng:NextNumber(3, 6)
			local ox, oz = rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
			deko(d, "Schilf", V(0.3, h, 0.3), CF(x + ox, y + h / 2, z + oz), rgb(110, 150, 60))
			if j == 1 then deko(d, "Kolben", V(0.6, 1.2, 0.6), CF(x + ox, y + h, z + oz), rgb(110, 70, 40)) end
		end
	end
	for i = 1, 45 do
		local x, z = zufallsPos(b)
		schilf(x, 0, z)
	end
	task.wait()
	for i = 1, 60 do
		local x, z = randPos(b)
		if i % 2 == 0 then
			local h = rng:NextNumber(12, 22)
			local neig = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
			local stamm = deko(d, "Stamm", V(2.5, h, 2.5), CF(x, RAND + h / 2, z) * neig, rgb(85, 75, 60))
			local top = stamm.CFrame * CF(0, h / 2, 0)
			deko(d, "Krone", V(12, 6, 12), CF(top.Position), rgb(95, 120, 70))
			for j = 1, 3 do
				deko(d, "Moos", V(0.6, 6, 0.6), CF(top.Position + V(rng:NextNumber(-5, 5), -5, rng:NextNumber(-5, 5))), rgb(120, 140, 90))
			end
		else
			schilf(x, RAND, z)
		end
		if i % 20 == 0 then task.wait() end
	end
	local lm = ordner("Landmarke", f)
	local pos = V(68, RAND, 2000)
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

-- ===== Wurfplatz in der Mitte =====
local wurf = Instance.new("Model")
wurf.Name = "Wurfplatz"
local platte = P(wurf, "Platte", V(26, 0.6, 18), CF(0, 0.3, -12), rgb(255, 170, 40))
wurf.PrimaryPart = platte
for xi = 0, 5 do
	for zi = 0, 3 do
		deko(wurf, "Kachel", V(3.6, 0.1, 3.6), CF(-11 + xi * 4.4, 0.65, -18 + zi * 4.4 - 0.5), if (xi + zi) % 2 == 0 then rgb(255, 205, 70) else rgb(255, 140, 40))
	end
end
-- Blasenring-Gestell vorne
for k = 0, 13 do
	local a = k / 14 * math.pi * 2
	deko(wurf, "Ring", V(0.9, 0.9, 0.9), CF(math.cos(a) * 3, 9 + math.sin(a) * 3, -3), rgb(255, 255, 255))
end
for _, s in { -1, 1 } do
	deko(wurf, "Stange", V(0.6, 9, 0.6), CF(s * 3.2, 4.5, -3), rgb(255, 255, 255))
end
wurf.Parent = Map

-- Gelbe Pfeile vom Spawn zum Wurfplatz
local Pfeile = ordner("Pfeile")
for z = -70, -26, 6 do
	for _, s in { -1, 1 } do
		deko(Pfeile, "Pfeil", V(0.4, 0.15, 2.4), CF(s * 0.8, 0.1, z) * CFrame.Angles(0, math.rad(-s * 40), 0), rgb(255, 220, 40), Enum.Material.Neon)
	end
end

-- ===== Grundstuecke hinten im Kessel =====
local Grund = ordner("Grundstuecke")
local XS = { -108, -36, 36, 108 }
for i, cx in XS do
	local g = Instance.new("Model")
	g.Name = "Grundstueck" .. i
	g:SetAttribute("Nummer", i)
	g:SetAttribute("Besitzer", 0)
	local c = CF(cx, 0, -150) -- Mitte, +Z Richtung Schlucht
	local function L(x, y, z) return c * CF(x, y, z) end
	P(g, "Boden", V(66, 1, 80), L(0, 0.05, 0), rgb(235, 225, 195))
	-- Gehege (Flaeche + Zaun) baut der Server je nach Ausbaustufe
	deko(g, "TrainKreis", V(0.3, 15, 15), L(17, 0.65, -14) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 255, 255), nil,
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.35 })
	deko(g, "BlasebalgAnker", V(1, 1, 1), L(17, 0.65, -14), rgb(255, 255, 255), nil, { Transparency = 1 })
	deko(g, "SchildPfosten", V(0.8, 6, 0.8), L(26, 3.5, -26), rgb(120, 85, 55))
	P(g, "AufwertenSchild", V(7, 4, 0.5), L(26, 7, -26), rgb(120, 85, 55))
	deko(g, "SchildAnker", V(1, 1, 1), L(-15, 24, -30), rgb(255, 255, 255), nil, { Transparency = 1 })
	g.Parent = Grund
	task.wait()
end

-- ===== Spawn, Laden, Brunnen (vorne im Kessel) =====
local Hub = ordner("Hub")
P(Hub, "Weg", V(12, 0.2, 60), CF(0, 0.1, -80), rgb(215, 205, 180))
P(Hub, "WegQuer", V(260, 0.2, 10), CF(0, 0.1, -105), rgb(215, 205, 180))
P(Hub, "Becken", V(3, 18, 18), CF(70, 1.5, -60) * CFrame.Angles(0, 0, math.rad(90)), rgb(190, 200, 215), nil, { Shape = Enum.PartType.Cylinder })
local wasser = deko(Hub, "Wasser", V(0.4, 16, 16), CF(70, 3, -60) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 200, 255), Enum.Material.Glass,
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
local laden = Instance.new("Model")
laden.Name = "Seifenladen"
local theke = P(laden, "Theke", V(18, 4, 5), CF(-70, 2, -60) * CFrame.Angles(0, math.rad(-90), 0), rgb(240, 240, 250))
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
	spawn.CFrame = CF(0, 0.7, -85) * CFrame.Angles(0, math.pi, 0) -- schaut zur Schlucht
	spawn.Size = V(8, 1, 8)
	spawn.Transparency = 1
	local dec = spawn:FindFirstChildOfClass("Decal")
	if dec then dec:Destroy() end
end

local Lt = game:GetService("Lighting")
Lt.ClockTime = 14
Lt.Brightness = 2.5
local atm = Lt:FindFirstChildOfClass("Atmosphere")
if atm then atm.Density = 0.18; atm.Haze = 0.6 end
workspace.StreamingEnabled = false -- Phase 1: Welt ist klein genug; spaeter Streaming + Persistent pruefen
return "Map fertig"
