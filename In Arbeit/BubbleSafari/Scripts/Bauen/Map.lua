-- Bubble Safari: Welt bauen (per execute_luau: loadstring(GetAsync(".../Bauen/Map.lua"))())
-- Aufbau wie ein Kessel mit Schlucht: Boden ueberall Y=0, Klippen Y=0..RAND ringsum.
--   Kessel (Grundstuecke, Spawn, Laden): X -150..150, Z -200..0
--   Wurfplatz in der Mitte am Schlucht-Eingang (0, 0, -12)
--   Schlucht: X -50..50, Z 0..2420 (+Z = Flugrichtung), Biome hintereinander
local rng = Random.new(42)
local V, CF = Vector3.new, CFrame.new
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local RAND = 81 -- Hoehe der Klippen-Oberkante (3 Stufen a 27)
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

local GRAS1, GRAS2 = rgb(105, 215, 65), rgb(88, 198, 55) -- kraeftiges Spielzeug-Gruen
local ERDE1, ERDE2 = rgb(172, 96, 64), rgb(156, 86, 57) -- rotbraune Felsen

-- ===== Voxel-Stil (Vorlage: Probe.lua / TVA-Video) =====
local GRUEN = { rgb(86, 200, 60), rgb(70, 180, 50), rgb(110, 215, 75) }
local ERDE = { rgb(140, 92, 55), rgb(122, 78, 46), rgb(158, 106, 64) }
local function zufall(t) return t[rng:NextInteger(1, #t)] end
local function noppen(p) -- Roblox-Noppen wie bei Bausteinen
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	return p
end
local Gelaende = ordner("Gelaende")
local KDeko = ordner("KesselDeko", Gelaende)

-- Blender-Baeume (ServerStorage.BS_Deko, je 1 MeshPart mit Paletten-Textur; Quelle Blender/VoxelBaum)
local DEKO = game:GetService("ServerStorage"):FindFirstChild("BS_Deko")
local BAUM_VORLAGEN = DEKO and { DEKO:FindFirstChild("Baum_Rund"), DEKO:FindFirstChild("Baum_Hoch"), DEKO:FindFirstChild("Baum_Breit") }
local function voxelBaum(f, pos, s, gruen)
	if BAUM_VORLAGEN and BAUM_VORLAGEN[1] and not gruen then -- Wiesen-Gruen: Mesh-Baum
		local b = BAUM_VORLAGEN[rng:NextInteger(1, #BAUM_VORLAGEN)]:Clone()
		b.Size = b.Size * (s * 1.5)
		b.CFrame = CF(pos + V(0, b.Size.Y / 2 - 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		b.Parent = f
		return
	end
	local stamm = rng:NextNumber(3, 6) * s
	deko(f, "Stamm", V(2, stamm, 2) * s ^ 0.5, CF(pos + V(0, stamm / 2, 0)), rgb(115, 75, 42))
	local mitte = pos + V(0, stamm + 3 * s, 0)
	for i = 1, rng:NextInteger(8, 12) do
		local r = rng:NextNumber(2.4, 4) * s
		local off = V(rng:NextNumber(-3, 3), rng:NextNumber(-1.5, 2.5), rng:NextNumber(-3, 3)) * s
		deko(f, "Laub", V(r, r, r), CF(mitte + off) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), zufall(gruen or GRUEN))
	end
end
-- Blender-Deko (Pilze, Sonnenblume, Blumenbusch, Stein; gleiche Wuerfelgroesse wie die Baeume)
local function meshDeko(name, f, pos, skala)
	local v = DEKO and DEKO:FindFirstChild(name)
	if not v then return false end
	local b = v:Clone()
	b.Size = b.Size * skala
	b.CFrame = CF(pos + V(0, b.Size.Y / 2 - 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	b.Parent = f
	return true
end
local function voxelPilz(f, pos, s, farbe)
	if not farbe then
		local name = if rng:NextNumber() < 0.7 then "Pilz_Rot" else "Pilz_Braun"
		if meshDeko(name, f, pos, s * 1.4) then return end
	end
	farbe = farbe or rgb(225, 45, 45)
	deko(f, "Stiel", V(1.2, 2.2, 1.2) * s, CF(pos + V(0, 1.1 * s, 0)), rgb(245, 235, 215))
	deko(f, "Kappe", V(3.2, 1.4, 3.2) * s, CF(pos + V(0, 2.6 * s, 0)), farbe)
	deko(f, "Kappe", V(2.2, 0.6, 2.2) * s, CF(pos + V(0, 3.4 * s, 0)), farbe)
	for _, o in { V(-0.9, 3.35, 0.6), V(0.8, 3.35, -0.5), V(0.2, 3.75, 0.2), V(-0.5, 2.6, -1.5) } do
		deko(f, "Punkt", V(0.6, 0.4, 0.6) * s, CF(pos + o * s), rgb(255, 255, 255))
	end
end
local function sonnenblume(f, pos)
	if meshDeko("Sonnenblume", f, pos, rng:NextNumber(1.1, 1.5)) then return end
	local h = rng:NextNumber(5, 8)
	deko(f, "Stiel", V(0.6, h, 0.6), CF(pos + V(0, h / 2, 0)), rgb(70, 150, 50))
	deko(f, "Blatt", V(1.6, 0.4, 0.8), CF(pos + V(0.8, h * 0.45, 0)), rgb(80, 170, 55))
	local k = pos + V(0, h + 0.5, 0)
	for i = 0, 7 do
		local w = i / 8 * math.pi * 2
		deko(f, "Bluete", V(1, 1, 0.5), CF(k + V(math.cos(w) * 1.3, math.sin(w) * 1.3, 0)), rgb(255, 205, 30))
	end
	deko(f, "Mitte", V(1.6, 1.6, 0.6), CF(k), rgb(110, 70, 35))
end
local BLUMEN = { rgb(255, 110, 160), rgb(255, 225, 60), rgb(180, 120, 255), rgb(255, 255, 255), rgb(255, 140, 60) }
local function blume(f, pos)
	if meshDeko("Blumen", f, pos, rng:NextNumber(0.5, 0.7)) then return end
	deko(f, "Stiel", V(0.35, 1.2, 0.35), CF(pos + V(0, 0.6, 0)), rgb(70, 150, 50))
	deko(f, "Bluete", V(1, 0.6, 1), CF(pos + V(0, 1.4, 0)), zufall(BLUMEN))
end
local function zufallsDeko(f, pos)
	local r = rng:NextNumber()
	if r < 0.45 then
		voxelBaum(f, pos, rng:NextNumber(0.8, 1.2))
	elseif r < 0.63 then
		voxelPilz(f, pos, rng:NextNumber(0.8, 1.3))
	elseif r < 0.73 then
		sonnenblume(f, pos)
	elseif r < 0.87 then
		meshDeko("Blumenbusch", f, pos, rng:NextNumber(1.2, 1.6))
	elseif r < 0.95 then
		meshDeko("Stein", f, pos, rng:NextNumber(1.0, 1.6))
	end
end

-- Pixel-Erdtextur (Variante B "Schichten", Texturen/erde_varianten.py) auf die Seitenflaechen der Erdbloecke.
-- Bloecke laufen am Stueck durch (Laenge Vielfaches von 16 = Kachelbreite), damit die Baender ohne Versatz/Fugen weiterlaufen.
local WAND_TEXTUR = "rbxassetid://116301489467986"
local function erdTextur(p)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local t = Instance.new("Texture")
		t.Name = "ErdTextur"
		t.Texture = WAND_TEXTUR
		t.Face = face
		t.StudsPerTileU = 16
		t.StudsPerTileV = 32
		t.Parent = p
	end
end

-- Hochebene ganz aussen: Erde + 3 Studs dicke Noppen-Grasdecke
local function hochebene(x1, x2, z1, z2)
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	erdTextur(P(Gelaende, "Hochebene", V(x2 - x1, RAND, z2 - z1), CF(mx, RAND / 2, mz), ERDE[1]))
	noppen(P(Gelaende, "HochGras", V(x2 - x1, 3, z2 - z1), CF(mx, RAND + 1.5, mz), GRUEN[1]))
end

-- Eine Terrassenstufe: Erdbloecke mit Pixel-Flecken, Graskappe mit Ueberhang, Gras-Tropfen, Deko oben
-- innen = Richtung zum Kessel (Einheitsvektor entlang X oder Z)
-- Gegen Flackern (Z-Fighting): nichts darf sich mit gleich hoher/gleich tiefer Flaeche ueberlappen.
--   Flecken bekommen eigene Zeilen, Tropfen eigene 4er-Plaetze, und der Gras-Ueberhang laesst
--   an den Enden (trimA/trimB) die Ecken frei, wo eine quer laufende Stufe gleicher Hoehe steht.
local function terrasse(x1, x2, z1, z2, h0, innen, wackeln, stil, trimA, trimB)
	stil = stil or {}
	trimA, trimB = trimA or 0, trimB or 0
	local gr = stil.gruen or GRUEN
	local dekoOrdner = stil.ordner or KDeko
	local entlangX = innen.X == 0
	local laenge = if entlangX then x2 - x1 else z2 - z1
	local tiefe = if entlangX then z2 - z1 else x2 - x1
	local n = math.max(1, math.round(laenge / 16))
	local stueck = laenge / n
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	local seite = if entlangX then V(1, 0, 0) else V(0, 0, 1)
	do -- Erde am Stueck (max. 1600 Studs je Teil)
		local start, rest = (if entlangX then x1 else z1), laenge
		while rest > 0.01 do
			local len = math.min(rest, 1600)
			local a = start + len / 2
			local c = if entlangX then V(a, 0, mz) else V(mx, 0, a)
			erdTextur(P(Gelaende, "Terrasse", if entlangX then V(len, h0, tiefe) else V(tiefe, h0, len), CF(c + V(0, h0 / 2, 0)), ERDE[1]))
			start += len
			rest -= len
		end
	end
	for i = 0, n - 1 do
		local a = (if entlangX then x1 else z1) + (i + 0.5) * stueck
		local c = if entlangX then V(a, 0, mz) else V(mx, 0, a)
		local h = h0
		local farbe = zufall(gr)
		noppen(P(Gelaende, "TerrasseGras", if entlangX then V(stueck, 3, tiefe) else V(tiefe, 3, stueck), CF(c + V(0, h + 1.5, 0)), farbe))
		local kante = c + innen * (tiefe / 2)
		-- Ueberhang (2 Studs zur Schlucht), an den Enden ggf. gekuerzt
		local L0 = (if entlangX then x1 else z1)
		local s0 = math.max(a - stueck / 2, L0 + trimA)
		local s1 = math.min(a + stueck / 2, L0 + laenge - trimB)
		if s1 - s0 > 0.5 then
			local m = (s0 + s1) / 2 - a
			noppen(P(Gelaende, "TerrasseGras", if entlangX then V(s1 - s0, 3, 2) else V(2, 3, s1 - s0), CF(kante + innen + seite * m + V(0, h + 1.5, 0)), farbe))
			-- Tropfen auf getrennten 4-Stud-Plaetzen
			local plaetze = {}
			for q = s0 + 2, s1 - 2, 4 do table.insert(plaetze, q - a) end
			for _ = 1, math.min(#plaetze, rng:NextInteger(2, 4)) do
				local q = table.remove(plaetze, rng:NextInteger(1, #plaetze))
				local lh = rng:NextInteger(1, 3) * 1.5
				deko(Gelaende, "Tropfen", V(2, lh, 2), CF(kante + innen + seite * q + V(0, h - lh / 2, 0)), farbe)
			end
		end
	end
	-- Deko oben auf der Stufe
	local y = h0 + 3
	local mittig = if entlangX then V(0, 0, mz) else V(mx, 0, 0)
	for t = 6, laenge - 6, stil.abstand or 14 do
		local entlang = (if entlangX then x1 else z1) + t + rng:NextNumber(-3, 3)
		local quer = rng:NextNumber(-tiefe / 2 + 3, tiefe / 2 - 3)
		local pos = mittig + seite * entlang + innen * quer + V(0, y, 0)
		local dk = stil.deko or zufallsDeko
		dk(dekoOrdner, pos)
		for k = 1, stil.blumen or 2 do
			blume(dekoOrdner, mittig + seite * (entlang + rng:NextNumber(-6, 6)) + innen * rng:NextNumber(-tiefe / 2 + 1, tiefe / 2 - 1) + V(0, y, 0))
		end
	end
end

-- Kessel-Rand: 5 Stufen nach aussen, oberste = Hochebenen-Hoehe
local T, STUFEN = 16, 3
local AUSSEN = T * STUFEN -- 48
for k = 0, STUFEN - 1 do
	local h = math.floor(RAND * (k + 1) / STUFEN) -- 27, 54, 81
	local w = k < STUFEN - 1
	local a, b = k * T, (k + 1) * T
	terrasse(-KX - b, KX + b, KZ - b, KZ - a, h, V(0, 0, 1), w, nil, T, T) -- hinten (Ecken frei)
	terrasse(-KX - b, -KX - a, KZ - a, a, h, V(1, 0, 0), w, nil, 2, 2) -- links (Innenecken gehoeren dem Querueberhang)
	terrasse(KX + a, KX + b, KZ - a, a, h, V(-1, 0, 0), w, nil, 2, 2) -- rechts
	terrasse(-KX - b, -SB - b, a, b, h, V(0, 0, -1), w, nil, T, 0) -- vorne links (Ecke gehoert zur Schlucht-Terrasse)
	terrasse(SB + b, KX + b, a, b, h, V(0, 0, -1), w, nil, 0, T) -- vorne rechts
	task.wait()
end
hochebene(-KX - AUSSEN - 110, KX + AUSSEN + 110, KZ - AUSSEN - 110, KZ - AUSSEN) -- hinten
hochebene(-KX - AUSSEN - 110, -KX - AUSSEN, KZ - AUSSEN, AUSSEN) -- links neben Kessel
hochebene(KX + AUSSEN, KX + AUSSEN + 110, KZ - AUSSEN, AUSSEN) -- rechts neben Kessel
hochebene(-KX - AUSSEN - 110, -SB - AUSSEN, AUSSEN, ENDE + 40) -- links der Schlucht
hochebene(SB + AUSSEN, KX + AUSSEN + 110, AUSSEN, ENDE + 40) -- rechts der Schlucht
hochebene(-SB, SB, ENDE, ENDE + 40) -- Schlucht-Ende
task.wait()

-- Boden: EIN Teil je Flaeche, Schachbrett (10er-Felder) + Pixelgras + gemalte Noppen stecken in der Textur
-- (Texturen/boden_textur.py schach). Farbe = hellere Kachelfarbe per Texture.Color3 (Textur-Grundhelligkeit 236).
local BODEN_TEXTUR = "rbxassetid://110670065747246"
local function bodenFlaeche(parent, x1, x2, z1, z2, hell)
	local p = P(parent, "Boden", V(x2 - x1, 1, z2 - z1), CF((x1 + x2) / 2, -0.5, (z1 + z2) / 2), hell)
	local t = Instance.new("Texture")
	t.Name = "BodenTextur"
	t.Texture = BODEN_TEXTUR
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU = 20
	t.StudsPerTileV = 20
	local k = 255 / 236
	t.Color3 = Color3.new(math.min(1, hell.R * k), math.min(1, hell.G * k), math.min(1, hell.B * k))
	t.Parent = p
	return p
end
local KB = ordner("KesselBoden", Gelaende)
bodenFlaeche(KB, -KX, KX, KZ, 0, rgb(120, 220, 80))
-- Deko unten am Kesselrand (nur wo keine Grundstuecke/Staende sind)
for z = -100, -8, 11 do
	for _, sx in { -1, 1 } do
		local pos = V(sx * rng:NextNumber(KX - 8, KX - 4), 0, z + rng:NextNumber(-3, 3))
		if rng:NextNumber() < 0.6 then voxelBaum(KDeko, pos, 0.8) else voxelPilz(KDeko, pos, 0.9) end
		blume(KDeko, pos + V(-sx * 3, 0, 2))
	end
end
for x = 58, KX - 6, 11 do
	for _, sx in { -1, 1 } do
		local pos = V(sx * x, 0, -rng:NextNumber(4, 8))
		if rng:NextNumber() < 0.6 then voxelBaum(KDeko, pos, 0.8) else voxelPilz(KDeko, pos, 0.9) end
		blume(KDeko, pos + V(0, 0, -3))
	end
end
-- Schwebende Inseln rund um den Kessel
for i = 1, 9 do
	local w = i / 9 * math.pi * 2
	local c = V(math.cos(w) * rng:NextNumber(150, 210), rng:NextNumber(120, 165), -100 + math.sin(w) * rng:NextNumber(130, 170))
	local g = rng:NextNumber(10, 18)
	local insel = DEKO and DEKO:FindFirstChild("Insel")
	if insel then -- Voxel-Insel aus Blender: Oberkante liegt auf Hoehe c.Y
		local b = insel:Clone()
		b.Size = b.Size * (g / 12)
		b.CFrame = CF(c - V(0, b.Size.Y / 2 - 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		b.Parent = KDeko
		c = c - V(0, 1.25, 0) -- Baum/Pilz unten wird bei c + 1,25 gesetzt -> steht auf der Grasoberkante
	else
		noppen(deko(KDeko, "Insel", V(g, 2.5, g), CF(c), zufall(GRUEN)))
		local y, bb = c.Y - 2.5, g
		while bb > 3 do -- umgedrehte Erd-Pyramide
			bb -= rng:NextNumber(2.5, 4)
			deko(KDeko, "InselErde", V(bb, 2.5, bb), CF(c.X, y, c.Z), zufall(ERDE))
			y -= 2.5
		end
	end
	if rng:NextNumber() < 0.6 then voxelBaum(KDeko, c + V(0, 1.25, 0), 0.7) else voxelPilz(KDeko, c + V(0, 1.25, 0), 0.8) end
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

for _, b in BIOME do
	local f = ordner(b.id, Tal)
	local boden = ordner("Boden", f)
	bodenFlaeche(boden, -SB, SB, b.von, b.bis, b.b1)
	-- Bogen mit Biom-Namen ueber der Schlucht
	if b.von > 0 then
		for _, s in { -1, 1 } do
			P(f, "BogenPfosten", V(3, RAND + 14, 3), CF(s * (SB + 3), (RAND + 14) / 2, b.von), rgb(120, 85, 55))
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
for _, b in BIOME do
	local f = ordner("Kleinkram", Tal[b.id])
	for i = 1, math.floor((b.bis - b.von) / 40) do
		local x, z = rng:NextNumber(-SB + 6, SB - 6), rng:NextNumber(b.von + 10, b.bis - 10)
		if i % 2 == 0 then
			local l = rng:NextNumber(5, 9)
			if meshDeko("Baumstamm", f, V(x, 0, z), l / 8.4) then continue end
			deko(f, "Stamm", V(l, 1.8, 1.8), CF(x, 0.9, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(130, 85, 50), Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
			deko(f, "Moos", V(l * 0.5, 0.3, 1.2), CF(x, 1.85, z), rgb(110, 190, 70))
		else
			local r = rng:NextNumber(2, 4.5)
			if not meshDeko("Stein", f, V(x, 0, z), r / 2.2) then
				deko(f, "Stein", V(r * 1.3, r * 0.8, r), CF(x, r * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(150, 150, 160), nil, { Shape = Enum.PartType.Ball })
			end
		end
	end
end
-- Position oben am Schluchtrand (links oder rechts)
local function randPos(b)
	local s = if rng:NextNumber() < 0.5 then -1 else 1
	return s * rng:NextNumber(SB + AUSSEN + 5, SB + AUSSEN + 70), rng:NextNumber(b.von + 5, b.bis - 5)
end

-- Blumenwiese
do
	local b = BIOME[1]
	local f = Tal.Wiese
	local farben = { rgb(255, 120, 170), rgb(255, 215, 60), rgb(190, 140, 255), rgb(255, 255, 255), rgb(255, 140, 80) }
	local d = ordner("Deko", f)
	local function blumenFeld(gx, gz, y, anzahl)
		if DEKO and DEKO:FindFirstChild("Blumen") then
			for i = 1, math.max(1, math.floor(anzahl / 3)) do
				meshDeko("Blumen", d, V(gx + rng:NextNumber(-5, 5), y, gz + rng:NextNumber(-5, 5)), rng:NextNumber(0.8, 1.1))
			end
			return
		end
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
		if not meshDeko("Blumenbusch", d, V(x, 0, z), s / 3.5) then
			deko(d, "Busch", V(s, s * 0.7, s), CF(x, s * 0.35, z), rgb(80, 170, 70))
		end
	end
	task.wait()
	-- oben am Rand: Bluetenbaeume + Blumen
	for i = 1, 40 do
		local x, z = randPos(b)
		local oben = V(x, RAND + 3, z)
		if i % 3 == 0 then -- Kirschbaum (rosa) oder gruener Voxel-Baum
			local kirsch = if rng:NextNumber() < 0.5 then "Baum_Kirsch_Rund" else "Baum_Kirsch_Breit"
			if not (i % 2 == 0 and meshDeko(kirsch, d, oben, rng:NextNumber(1.2, 1.6))) then
				voxelBaum(d, oben, rng:NextNumber(0.9, 1.2))
			end
		elseif i % 3 == 1 then
			zufallsDeko(d, oben)
		else
			blumenFeld(x, z, RAND + 3, 5)
		end
	end
	-- Landmarke: Riesen-Gaensebluemchen am Rand
	local lm = ordner("Landmarke", f)
	local lx, lz = SB + AUSSEN + 18, 380
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
	local lx, lz = -(SB + AUSSEN + 32), 1100
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
	local pos = V(SB + AUSSEN + 25, RAND, 2000)
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

-- ===== Schlucht-Waende: Terrassen je Biom =====
do
	local PILZ_KAPPEN = { rgb(225, 45, 45), rgb(160, 80, 220), rgb(70, 140, 235) }
	local stile = {
		Wiese = { gruen = GRUEN, abstand = 20, blumen = 1 },
		Pilzwald = {
			gruen = { rgb(60, 150, 85), rgb(50, 135, 75), rgb(75, 165, 95) }, abstand = 20, blumen = 1,
			deko = function(f, pos)
				if rng:NextNumber() < 0.6 then
					voxelPilz(f, pos, rng:NextNumber(1, 1.8), PILZ_KAPPEN[rng:NextInteger(1, #PILZ_KAPPEN)])
				else
					voxelBaum(f, pos, rng:NextNumber(0.9, 1.2), { rgb(40, 110, 70), rgb(50, 125, 80) })
				end
			end,
		},
		Sumpf = {
			gruen = { rgb(115, 145, 70), rgb(100, 130, 62), rgb(125, 155, 80) }, abstand = 22, blumen = 0,
			deko = function(f, pos)
				if rng:NextNumber() < 0.7 then
					voxelBaum(f, pos, rng:NextNumber(0.9, 1.3), { rgb(95, 125, 65), rgb(110, 135, 72) })
				else
					for j = 1, 3 do
						local hh = rng:NextNumber(3, 6)
						deko(f, "Schilf", V(0.4, hh, 0.4), CF(pos + V(rng:NextNumber(-1.5, 1.5), hh / 2, rng:NextNumber(-1.5, 1.5))), rgb(110, 150, 60))
					end
				end
			end,
		},
	}
	for _, bm in BIOME do
		local stil = table.clone(stile[bm.id])
		stil.ordner = Tal[bm.id]:FindFirstChild("Deko") or ordner("Deko", Tal[bm.id])
		for k = 0, STUFEN - 1 do
			local h = math.floor(RAND * (k + 1) / STUFEN)
			local a, b = k * T, (k + 1) * T
			local z1 = math.max(bm.von, a)
			local z2 = if bm.bis >= ENDE then ENDE + 40 else bm.bis
			terrasse(-SB - b, -SB - a, z1, z2, h, V(1, 0, 0), k < STUFEN - 1, stil) -- links
			terrasse(SB + a, SB + b, z1, z2, h, V(-1, 0, 0), k < STUFEN - 1, stil) -- rechts
			task.wait()
		end
	end
end

-- ===== Wurfdeck in der Mitte (Holzdeck mit Treppe, Gelaender, gelber Scheibe) =====
local HOLZ, HOLZ_DUNKEL, HOLZ_HELL = rgb(160, 105, 62), rgb(95, 60, 35), rgb(185, 128, 78)
local wurf = Instance.new("Model")
wurf.Name = "Wurfplatz"
local platte = P(wurf, "Platte", V(28, 2.6, 24), CF(0, 1.3, -12), HOLZ, Enum.Material.WoodPlanks)
wurf.PrimaryPart = platte
for i = 0, 9 do -- Plankenfugen
	deko(wurf, "Fuge", V(28, 0.05, 0.25), CF(0, 2.62, -23 + i * 2.4), HOLZ_DUNKEL)
end
for k = 1, 3 do -- Treppe Richtung Kessel
	P(wurf, "Stufe", V(14, 2.6 * (1 - (k - 1) / 3), 2.2), CF(0, 1.3 * (1 - (k - 1) / 3), -24 - (k - 0.5) * 2.2), HOLZ_HELL, Enum.Material.WoodPlanks)
end
local function gelaender(a, b)
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 4))
	for k = 0, n do
		P(wurf, "Pfosten", V(1.1, 3.4, 1.1), CF(a + d * (k / n) + V(0, 1.7, 0)), HOLZ_DUNKEL, Enum.Material.Wood)
	end
	local m = (a + b) / 2
	for _, h in { 1.3, 2.8 } do
		P(wurf, "Latte", V(0.7, 0.6, d.Magnitude), CF(m + V(0, h, 0), m + V(0, h, 0) + d.Unit), HOLZ_DUNKEL, Enum.Material.Wood)
	end
end
gelaender(V(-13.5, 2.6, -23.5), V(-13.5, 2.6, -0.5))
gelaender(V(13.5, 2.6, -23.5), V(13.5, 2.6, -0.5))
gelaender(V(-13.5, 2.6, -23.5), V(-7.5, 2.6, -23.5))
gelaender(V(7.5, 2.6, -23.5), V(13.5, 2.6, -23.5))
deko(wurf, "Scheibe", V(0.3, 10, 10), CF(0, 2.75, -9) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 210, 55), nil, { Shape = Enum.PartType.Cylinder })
for k = 0, 15 do -- gestrichelter Ring aus orangen Kacheln
	local a = k / 16 * math.pi * 2
	local pos = V(math.cos(a) * 6.6, 2.7, -9 + math.sin(a) * 6.6)
	deko(wurf, "Ringkachel", V(1.8, 0.2, 0.9), CF(pos, pos + V(-math.sin(a), 0, math.cos(a))), rgb(255, 130, 35))
end
-- Blasenring-Gestell vorne am Deck
for k = 0, 15 do
	local a = k / 16 * math.pi * 2
	deko(wurf, "Ring", V(0.9, 0.9, 0.9), CF(math.cos(a) * 3, 9 + math.sin(a) * 3, -1), rgb(255, 255, 255))
end
for _, s in { -1, 1 } do
	deko(wurf, "Stange", V(0.6, 6.4, 0.6), CF(s * 3.2, 5.8, -1), rgb(255, 255, 255))
end
-- schwebende Schrift
local hinweis = deko(wurf, "HinweisAnker", V(1, 1, 1), CF(0, 12, -9), rgb(255, 255, 255), nil, { Transparency = 1 })
local hbb = Instance.new("BillboardGui")
hbb.Size = UDim2.fromOffset(420, 80)
hbb.MaxDistance = 160
hbb.LightInfluence = 0
hbb.Parent = hinweis
local ht = Instance.new("TextLabel")
ht.Size = UDim2.fromScale(1, 1)
ht.BackgroundTransparency = 1
ht.Text = "HIER PUSTEN!"
ht.TextScaled = true
ht.Font = Enum.Font.FredokaOne
ht.TextColor3 = rgb(255, 215, 50)
local hst = Instance.new("UIStroke")
hst.Thickness = 4
hst.Color = rgb(120, 60, 20)
hst.Parent = ht
ht.Parent = hbb
wurf.Parent = Map

-- ===== Orange Kachelwege =====
local Wege = ordner("Wege")
local OR1, OR2, ORRAND = rgb(255, 150, 40), rgb(255, 185, 70), rgb(225, 110, 30)
local function kachelWeg(x1, x2, z1, z2, kachel)
	local nx, nz = math.floor((x2 - x1) / kachel), math.floor((z2 - z1) / kachel)
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			noppen(P(Wege, "Kachel", V(kachel, 0.3, kachel), CF(x1 + (ix + 0.5) * kachel, 0.15, z1 + (iz + 0.5) * kachel), if (ix + iz) % 2 == 0 then OR1 else OR2))
		end
	end
end
kachelWeg(-6, 6, -104, -32, 4) -- Hauptweg zum Deck
kachelWeg(-140, 140, -110, -100, 5) -- Querweg vor den Grundstuecken
for _, s in { -1, 1 } do
	P(Wege, "Rand", V(1, 0.35, 72), CF(s * 6.5, 0.17, -68), ORRAND)
end
P(Wege, "RandQuer", V(280, 0.35, 1), CF(0, 0.17, -99.5), ORRAND)
task.wait()

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
	P(g, "Boden", V(66, 1, 80), L(0, 0.05, 0), rgb(130, 225, 85), nil, { Transparency = 1, CanCollide = false, CanQuery = false }) -- nur Bezugspunkt
	-- Gehege (Flaeche + Zaun) baut der Server je nach Ausbaustufe
	-- Trainingsplatz: Steinmatte, Holzteller mit Zackenring
	P(g, "Steinmatte", V(20, 0.3, 20), L(15, 0.65, -14), rgb(150, 150, 158), Enum.Material.Slate)
	deko(g, "TrainKreis", V(0.4, 14, 14), L(17, 0.85, -14) * CFrame.Angles(0, 0, math.rad(90)), rgb(150, 100, 60), Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder })
	for k = 0, 19 do
		local a = k / 20 * math.pi * 2
		deko(g, "Zacke", V(1.3, 0.5, 1.3), L(17 + math.cos(a) * 7.4, 0.95, -14 + math.sin(a) * 7.4) * CFrame.Angles(0, -a, 0), if k % 2 == 0 then rgb(255, 170, 205) else rgb(255, 255, 255))
	end
	deko(g, "BlasebalgAnker", V(1, 1, 1), L(17, 1, -14), rgb(255, 255, 255), nil, { Transparency = 1 })
	-- gelbe Aufwerten-Scheibe neben dem Trainingsplatz
	deko(g, "ScheibenRand", V(0.3, 8, 8), L(29.5, 0.7, -14) * CFrame.Angles(0, 0, math.rad(90)), rgb(60, 45, 35), nil, { Shape = Enum.PartType.Cylinder })
	P(g, "AufwertenSchild", V(0.35, 7, 7), L(29.5, 0.8, -14) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 210, 55), nil, { Shape = Enum.PartType.Cylinder })
	-- grosses Holz-Namensschild vorne
	for _, s in { -1, 1 } do
		deko(g, "SchildPfosten", V(1, 7, 1), L(12 + s * 6, 3.5, 37), HOLZ_DUNKEL, Enum.Material.Wood)
	end
	local ns = P(g, "NamensSchild", V(15, 5, 0.8), CFrame.lookAt(L(12, 6.5, 37).Position, L(12, 6.5, 37).Position + V(0, 0, 1)) * CFrame.Angles(0, 0, math.rad(-4)), HOLZ, Enum.Material.WoodPlanks)
	ns.CanCollide = false
	deko(g, "SchildAnker", V(1, 1, 1), L(-15, 24, 22), rgb(255, 255, 255), nil, { Transparency = 1 })
	g.Parent = Grund
	task.wait()
end

-- ===== Ladenstrasse am Hauptweg =====
local Hub = ordner("Hub")
local function stand(name, pos, blick, markise, schild, schildFarbe)
	local m = Instance.new("Model")
	m.Name = name
	local cf = CFrame.lookAt(pos, pos + blick)
	local theke = P(m, "Theke", V(12, 3.5, 4), cf * CF(0, 1.75, 0), rgb(250, 248, 240))
	P(m, "ThekeRand", V(12.4, 0.5, 4.4), cf * CF(0, 3.6, 0), schildFarbe)
	P(m, "Rueckwand", V(12, 9, 0.8), cf * CF(0, 4.5, 4.5), rgb(240, 235, 225))
	for _, s in { -1, 1 } do
		P(m, "Pfosten", V(0.9, 11, 0.9), cf * CF(s * 5.8, 5.5, -1.6), rgb(255, 255, 255))
	end
	for k = 0, 5 do
		deko(m, "Markise", V(2.05, 0.5, 7), cf * CF(-5.1 + k * 2.05, 10.4, 0.6) * CFrame.Angles(math.rad(-14), 0, 0), if k % 2 == 0 then markise else rgb(255, 255, 255))
	end
	local sc = deko(m, "Schild", V(13, 3.6, 0.6), cf * CF(0, 13.4, 0.8), schildFarbe)
	schildText(sc, schild, rgb(255, 255, 255), Enum.NormalId.Front)
	m.PrimaryPart = theke
	m:ScaleTo(1.4)
	m:PivotTo(m:GetPivot() + V(0, 0.7, 0)) -- nach dem Skalieren wieder auf den Boden
	m.Parent = Hub
	return m
end
-- Voxel-Seifenladen aus Blender (ServerStorage.BS_Deko.Seifenladen, Vorlage am Ursprung, Vorderseite -Z, Boden y=0).
-- Quelle: Blender/_Skripte/voxelladen_seife.py; Animation (Pumpe, drehende Seife, Blasen) macht LadenAnimation.client.lua.
local BLASE_TEXTUR = "rbxassetid://93711487994021"
local function seifenladenVoxel(pos, blick)
	local vorlage = DEKO and DEKO:FindFirstChild("Seifenladen")
	if not vorlage then return nil end
	local m = vorlage:Clone()
	-- unsichtbare Theke (ProximityPrompt vom Server) + Kollision fuer den Hauskoerper
	P(m, "Theke", V(8, 4.5, 2.5), CF(-2.5, 2.25, -3.25), rgb(255, 255, 255), nil, { Transparency = 1 })
	P(m, "Kollision", V(16, 14, 7), CF(0, 7, 1.75), rgb(255, 255, 255), nil, { Transparency = 1, CanQuery = false })
	-- Schrift auf dem Holzschild
	local st = deko(m, "SchildText", V(7.6, 3.6, 0.1), CF(-2.75, 12, -5.06), rgb(255, 255, 255), nil, { Transparency = 1 })
	schildText(st, "SEIFEN", rgb(255, 255, 255), Enum.NormalId.Front)
	st.SurfaceGui.PixelsPerStud = 30
	-- Lichter in den Laternen
	for _, l in { V(2, 7, -5), V(-7.5, 7, -5), V(9, 8, -2.5), V(-8.5, 8, -2.5) } do
		local lp = deko(m, "Laternenlicht", V(0.5, 0.5, 0.5), CF(l), rgb(255, 220, 120), nil, { Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Color = rgb(255, 210, 120)
		pl.Range = 12
		pl.Brightness = 1.2
		pl.Parent = lp
	end
	-- Duese der Pumpe (Blasen) und Schornstein (Rauch)
	local duese = Instance.new("Attachment")
	duese.Name = "Duese"
	duese.Parent = m.Laden_Pumpe
	duese.WorldPosition = V(-6.4, 24.25, 2.25)
	local blasen = Instance.new("ParticleEmitter")
	blasen.Name = "Blasen"
	blasen.Texture = BLASE_TEXTUR
	blasen.Rate = 2
	blasen.Lifetime = NumberRange.new(2.5, 4)
	blasen.Speed = NumberRange.new(3, 6)
	blasen.SpreadAngle = Vector2.new(25, 25)
	blasen.EmissionDirection = Enum.NormalId.Left
	blasen.Acceleration = V(0, 2.5, 0)
	blasen.Drag = 1
	blasen.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 1.4, 0.6), NumberSequenceKeypoint.new(1, 1.8, 0.8) })
	blasen.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.85, 0.15), NumberSequenceKeypoint.new(1, 1) })
	blasen.RotSpeed = NumberRange.new(-30, 30)
	blasen.LightEmission = 0.2
	blasen.Parent = duese
	local kamin = Instance.new("Attachment")
	kamin.Name = "Kamin"
	kamin.Parent = m.Laden_Haus
	kamin.WorldPosition = V(5.75, 20, 3.5)
	local rauch = Instance.new("ParticleEmitter")
	rauch.Name = "Rauch"
	rauch.Rate = 3
	rauch.Lifetime = NumberRange.new(2, 3)
	rauch.Speed = NumberRange.new(2, 3)
	rauch.SpreadAngle = Vector2.new(10, 10)
	rauch.EmissionDirection = Enum.NormalId.Top
	rauch.Color = ColorSequence.new(rgb(245, 245, 250))
	rauch.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.5) })
	rauch.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	rauch.Parent = kamin
	-- leuchtender Ring am Boden
	for k = 0, 47 do
		local w = k / 48 * math.pi * 2
		deko(m, "Ring", V(1.9, 0.12, 0.5), CF(math.cos(w) * 13, 0.06, -1 + math.sin(w) * 13) * CFrame.Angles(0, -w + math.pi / 2, 0), rgb(120, 210, 255), Enum.Material.Neon, { Transparency = 0.15 })
	end
	m.WorldPivot = CFrame.new()
	m:ScaleTo(1.3)
	m:PivotTo(CFrame.lookAt(pos, pos + blick))
	m.Name = "Seifenladen"
	m.Parent = Hub
	return m
end
local laden = seifenladenVoxel(V(-32, 0, -50), V(1, 0, -0.25))
if not laden then
	laden = stand("Seifenladen", V(-24, 0, -62), V(1, 0, -0.6), rgb(70, 160, 255), "SEIFENLADEN", rgb(70, 160, 255))
	for k = -2, 2 do
		deko(laden, "Seife", V(1.6, 1, 1.2), laden.Theke.CFrame * CF(k * 2.2, 2.3, 0), ({ rgb(235, 245, 255), rgb(255, 200, 70), rgb(110, 240, 190), rgb(255, 150, 200), rgb(190, 140, 255) })[k + 3])
	end
end
stand("VerkaufStand", V(-24, 0, -88), V(1, 0, -0.6), rgb(235, 60, 60), "VERKAUFEN", rgb(235, 60, 60))
stand("IndexStand", V(24, 0, -62), V(-1, 0, -0.6), rgb(150, 100, 230), "TIER-INDEX", rgb(150, 100, 230))
-- Bestenliste mit Krone
do
	local m = Instance.new("Model")
	m.Name = "Bestenliste"
	local cf = CFrame.lookAt(V(21, 0, -86), V(20, 0, -86))
	for _, s in { -1, 1 } do
		P(m, "Pfosten", V(1, 13, 1), cf * CF(s * 6.5, 6.5, 0), HOLZ_DUNKEL, Enum.Material.Wood)
	end
	P(m, "Rahmen", V(13.5, 10, 0.8), cf * CF(0, 7.5, 0.1), HOLZ, Enum.Material.Wood)
	local tafel = P(m, "Tafel", V(12, 8.6, 0.3), cf * CF(0, 7.5, -0.4), rgb(40, 60, 45))
	for k = -1, 1 do
		deko(m, "Krone", V(1.6, if k == 0 then 3 else 2.2, 1), cf * CF(k * 1.8, 13.6 + (if k == 0 then 0.4 else 0), 0), rgb(255, 205, 40), Enum.Material.Neon)
	end
	deko(m, "KroneBasis", V(6, 1, 1.2), cf * CF(0, 12.6, 0), rgb(255, 190, 30))
	m.PrimaryPart = tafel
	m.Parent = Hub
end
-- Holz-Laternen am Weg
for z = -96, -36, 15 do
	for _, s in { -1, 1 } do
		P(Hub, "Laterne", V(0.9, 6, 0.9), CF(s * 8.5, 3, z), HOLZ_DUNKEL, Enum.Material.Wood)
		local lampe = deko(Hub, "Lampe", V(1.6, 1.6, 1.6), CF(s * 8.5, 6.6, z), rgb(255, 220, 110), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 210, 120)
		l.Range = 14
		l.Brightness = 1
		l.Parent = lampe
	end
end
-- Wahrzeichen: Riesen-Blasenstab mit schwebenden Blasen
do
	local m = Instance.new("Model")
	m.Name = "Blasenstab"
	local basis = V(72, 0, -58)
	P(m, "Sockel", V(10, 2, 10), CF(basis + V(0, 1, 0)), rgb(250, 248, 240))
	local griff = deko(m, "Griff", V(2.4, 22, 2.4), CF(basis + V(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(-12)), rgb(255, 120, 180))
	local spitze = (griff.CFrame * CF(0, 11, 0)).Position
	for k = 0, 19 do
		local a = k / 20 * math.pi * 2
		deko(m, "Ring", V(1.6, 1.6, 1.6), CF(spitze + V(math.cos(a) * 7, 7 + math.sin(a) * 7, 0)), rgb(120, 200, 255))
	end
	for k, gr in { 9, 6, 4.5 } do
		deko(m, "Blase", V(gr, gr, gr), CF(spitze + V(-6 - k * 7, 10 + k * 4, k * 3)), rgb(200, 230, 255), Enum.Material.ForceField, { Shape = Enum.PartType.Ball })
	end
	m.Parent = Hub
end
-- Riesen-Seifenflasche auf der anderen Seite
do
	local basis = V(-74, 0, -58)
	deko(Hub, "Flasche", V(16, 11, 11), CF(basis + V(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 210, 255), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.25 })
	deko(Hub, "Etikett", V(16.5, 5, 0.2), CF(basis + V(0, 8, 0)) * CF(0, 0, 0), rgb(255, 255, 255))
	deko(Hub, "Hals", V(4, 4, 4), CF(basis + V(0, 18, 0)), rgb(255, 255, 255))
	deko(Hub, "Pumpe", V(1.2, 4, 1.2), CF(basis + V(0, 22, 0)), rgb(255, 120, 180))
	deko(Hub, "Duese", V(5, 1.2, 1.2), CF(basis + V(2, 24, 0)), rgb(255, 120, 180))
end

local spawn = workspace:FindFirstChild("SpawnLocation")
if spawn then
	spawn.CFrame = CF(0, 0.7, -95) * CFrame.Angles(0, math.pi, 0) -- schaut zum Wurfdeck
	spawn.Size = V(8, 1, 8)
	spawn.Transparency = 1
	local dec = spawn:FindFirstChildOfClass("Decal")
	if dec then dec:Destroy() end
end

-- Licht: sonnig, warm, kraeftige Farben
local Lt = game:GetService("Lighting")
Lt.ClockTime = 13.5
Lt.Brightness = 3
Lt.OutdoorAmbient = rgb(150, 140, 130)
local atm = Lt:FindFirstChildOfClass("Atmosphere")
if atm then atm.Density = 0.22; atm.Haze = 0.8; atm.Color = rgb(200, 225, 255) end
local bloom = Lt:FindFirstChildOfClass("BloomEffect")
if bloom then bloom.Intensity = 0.6; bloom.Size = 24; bloom.Threshold = 0.95 end
local sun = Lt:FindFirstChildOfClass("SunRaysEffect")
if sun then sun.Intensity = 0.06 end
local dof = Lt:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then dof.Enabled = false end
local cc = Lt:FindFirstChild("Grundfarbe") or Instance.new("ColorCorrectionEffect")
cc.Name = "Grundfarbe"
cc.Saturation = 0.15
cc.Contrast = 0.05
cc.Parent = Lt
workspace.StreamingEnabled = false -- Phase 1: Welt ist klein genug; spaeter Streaming + Persistent pruefen
return "Map fertig"
