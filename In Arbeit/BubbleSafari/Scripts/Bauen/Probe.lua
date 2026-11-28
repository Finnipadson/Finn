-- Bubble Safari: Probestueck im neuen Stil (Vorlage: TVA- und n1tro-Video, siehe Design-Bibliothek/Welt-Map.md)
-- Eigener Bereich bei X = 1000, damit die Spielkarte unveraendert bleibt.
local rng = Random.new(7)
local V, CF = Vector3.new, CFrame.new
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local OX = 1000 -- Versatz des Probebereichs
local SB = 50 -- halbe Schluchtbreite
local LANG = 260
local TIEFE = 14 -- Breite einer Terrasse
local STUFEN = 4

local alt = workspace:FindFirstChild("Probe")
if alt then alt:Destroy() end
local Probe = Instance.new("Folder")
Probe.Name = "Probe"
Probe.Parent = workspace

local MS = game:GetService("MaterialService")
local function variante(name)
	return MS:FindFirstChild(name) and name or nil
end
local V_ERDE, V_GRAS, V_NOPPEN, V_HOLZ = variante("BS_VoxelErde"), variante("BS_VoxelGras"), variante("BS_Noppen"), variante("BS_VoxelHolz")

local function P(parent, size, cf, color, mat, var, kollision)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if var then
		local mv = MS:FindFirstChild(var)
		p.Material = mv.BaseMaterial
		p.MaterialVariant = var
	end
	p.Anchored = true
	p.CanCollide = kollision == true
	p.CanQuery = kollision == true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function ordner(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or Probe
	return f
end

local GRUEN = { rgb(86, 200, 60), rgb(70, 180, 50), rgb(110, 215, 75) }
local ERDE = { rgb(140, 92, 55), rgb(122, 78, 46), rgb(158, 106, 64) }
local function zufall(t) return t[rng:NextInteger(1, #t)] end

-- ===== Voxel-Deko =====
local function voxelBaum(f, pos, s)
	s = s or 1
	local stamm = rng:NextNumber(3, 6) * s
	P(f, V(2, stamm, 2) * s ^ 0.5, CF(pos + V(0, stamm / 2, 0)), rgb(115, 75, 42), nil, V_HOLZ)
	local mitte = pos + V(0, stamm + 3 * s, 0)
	for i = 1, rng:NextInteger(9, 14) do
		local r = rng:NextNumber(2.4, 4) * s
		local off = V(rng:NextNumber(-3, 3), rng:NextNumber(-1.5, 2.5), rng:NextNumber(-3, 3)) * s
		P(f, V(r, r, r), CF(mitte + off) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), zufall(GRUEN), nil, V_GRAS)
	end
end
local function pilz(f, pos, s)
	P(f, V(1.2, 2.2, 1.2) * s, CF(pos + V(0, 1.1 * s, 0)), rgb(245, 235, 215))
	P(f, V(3.2, 1.4, 3.2) * s, CF(pos + V(0, 2.6 * s, 0)), rgb(225, 45, 45))
	P(f, V(2.2, 0.6, 2.2) * s, CF(pos + V(0, 3.4 * s, 0)), rgb(225, 45, 45))
	for _, o in { V(-0.9, 3.35, 0.6), V(0.8, 3.35, -0.5), V(0.2, 3.75, 0.2), V(-0.5, 2.6, -1.5) } do
		P(f, V(0.6, 0.4, 0.6) * s, CF(pos + o * s), rgb(255, 255, 255))
	end
end
local function sonnenblume(f, pos)
	local h = rng:NextNumber(5, 8)
	P(f, V(0.6, h, 0.6), CF(pos + V(0, h / 2, 0)), rgb(70, 150, 50))
	P(f, V(1.6, 0.4, 0.8), CF(pos + V(0.8, h * 0.45, 0)), rgb(80, 170, 55))
	local k = pos + V(0, h + 0.5, 0)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		P(f, V(1, 1, 0.5), CF(k + V(math.cos(a) * 1.3, math.sin(a) * 1.3, 0)), rgb(255, 205, 30))
	end
	P(f, V(1.6, 1.6, 0.6), CF(k), rgb(110, 70, 35))
end
local function blume(f, pos)
	local farben = { rgb(255, 110, 160), rgb(255, 225, 60), rgb(180, 120, 255), rgb(255, 255, 255), rgb(255, 140, 60) }
	P(f, V(0.35, 1.2, 0.35), CF(pos + V(0, 0.6, 0)), rgb(70, 150, 50))
	P(f, V(1, 0.6, 1), CF(pos + V(0, 1.4, 0)), zufall(farben))
end

-- ===== Terrassen-Waende =====
local Waende = ordner("Waende")
for _, seite in { -1, 1 } do
	for stufe = 0, STUFEN - 1 do
		local innen = SB + stufe * TIEFE
		local hoehe = 10 + stufe * 11
		for z = 0, LANG - 16, 16 do
			local h = hoehe + rng:NextInteger(-1, 1)
			local x = OX + seite * (innen + TIEFE / 2)
			-- Erdblock
			P(Waende, V(TIEFE, h, 16), CF(x, h / 2, z + 8), zufall(ERDE), nil, V_ERDE, true)
			-- dunklere Voxel-Flecken auf der Innenseite (Pixel-Look, auch ohne Material)
			for k = 1, 3 do
				local fh = rng:NextNumber(2, h - 4)
				local w = rng:NextInteger(1, 3) * 2
				P(Waende, V(0.4, 2, w), CF(OX + seite * (innen - 0.15), fh, z + rng:NextNumber(2, 14)), if k == 1 then rgb(105, 66, 38) else rgb(165, 115, 72))
			end
			-- Graskappe mit Ueberhang zur Schlucht
			P(Waende, V(TIEFE + 2, 3, 16), CF(x - seite * 1, h + 1.5, z + 8), zufall(GRUEN), nil, V_GRAS, true)
			-- herabhaengende Gras-Wuerfel ("Tropfen")
			for k = 1, rng:NextInteger(2, 4) do
				local lz = z + rng:NextNumber(1, 15)
				local lh = rng:NextInteger(1, 3) * 1.5
				P(Waende, V(2, lh, 2), CF(OX + seite * (innen - 1), h - lh / 2, lz), zufall(GRUEN), nil, V_GRAS)
			end
		end
		task.wait()
	end
end
-- aeusserste Hochebene (Abschluss)
for _, seite in { -1, 1 } do
	local innen = SB + STUFEN * TIEFE
	P(Waende, V(120, 52, LANG), CF(OX + seite * (innen + 60), 26, LANG / 2), ERDE[1], nil, V_ERDE, true)
	P(Waende, V(120, 3, LANG), CF(OX + seite * (innen + 60), 53.5, LANG / 2), GRUEN[1], nil, V_GRAS, true)
end

-- ===== Schluchtboden: Noppen-Schachbrett + heller Mittelweg =====
local Boden = ordner("Boden")
for x = -SB, SB - 8, 8 do
	for z = 0, LANG - 8, 8 do
		local c = if ((x + SB) / 8 + z / 8) % 2 == 0 then rgb(120, 220, 80) else rgb(100, 205, 65)
		P(Boden, V(8, 1, 8), CF(OX + x + 4, -0.5, z + 4), c, nil, V_NOPPEN, true)
	end
	task.wait()
end
for z = 0, LANG - 8, 8 do
	P(Boden, V(10, 0.2, 8), CF(OX, 0.1, z + 4), if (z / 8) % 2 == 0 then rgb(185, 240, 140) else rgb(165, 232, 120), nil, V_NOPPEN)
end
P(Boden, V(10, 0.3, 0.6), CF(OX, 0.25, 120), rgb(255, 255, 255), Enum.Material.Neon) -- leuchtende Weitenlinie

-- ===== Deko: auf jeder Terrasse und unten am Rand =====
local Deko = ordner("Deko")
for _, seite in { -1, 1 } do
	for stufe = 0, STUFEN do
		local innen = SB + stufe * TIEFE
		local y = if stufe < STUFEN then 10 + stufe * 11 + 3 else 55
		for z = 4, LANG - 4, 13 do
			local x = OX + seite * (innen + rng:NextNumber(3, TIEFE - 3))
			local pos = V(x, y, z + rng:NextNumber(-4, 4))
			local r = rng:NextNumber()
			if r < 0.55 then
				voxelBaum(Deko, pos, rng:NextNumber(0.8, 1.2))
			elseif r < 0.75 then
				pilz(Deko, pos, rng:NextNumber(0.8, 1.3))
			elseif r < 0.88 then
				sonnenblume(Deko, pos)
			end
			for k = 1, 3 do
				blume(Deko, V(OX + seite * (innen + rng:NextNumber(1, TIEFE - 1)), y, z + rng:NextNumber(-6, 6)))
			end
		end
		task.wait()
	end
	-- unten am Schluchtrand
	for z = 6, LANG - 6, 9 do
		local pos = V(OX + seite * rng:NextNumber(SB - 9, SB - 3), 0, z)
		if rng:NextNumber() < 0.5 then voxelBaum(Deko, pos, 0.8) else pilz(Deko, pos, 0.9) end
		blume(Deko, pos + V(-seite * 3, 0, 2))
	end
end

-- ===== Schwebende Inseln =====
local Inseln = ordner("Inseln")
for i = 1, 10 do
	local seite = if i % 2 == 0 then 1 else -1
	local c = V(OX + seite * rng:NextNumber(40, 150), rng:NextNumber(75, 120), rng:NextNumber(20, LANG + 80))
	local w = rng:NextNumber(10, 18)
	P(Inseln, V(w, 2.5, w), CF(c), zufall(GRUEN), nil, V_GRAS)
	local y, b = c.Y - 2.5, w
	while b > 3 do -- umgedrehte Erd-Pyramide
		b -= rng:NextNumber(2.5, 4)
		P(Inseln, V(b, 2.5, b), CF(c.X, y, c.Z), zufall(ERDE), nil, V_ERDE)
		y -= 2.5
	end
	if rng:NextNumber() < 0.6 then voxelBaum(Inseln, c + V(0, 1.25, 0), 0.7) else pilz(Inseln, c + V(0, 1.25, 0), 0.8) end
end

-- ===== Leuchtender Ring am Ende =====
for k = 0, 23 do
	local a = k / 24 * math.pi * 2
	P(Probe, V(2.4, 2.4, 2.4), CF(OX + math.cos(a) * 14, 22 + math.sin(a) * 14, LANG + 40), rgb(190, 235, 255), Enum.Material.Neon)
end

-- ===== Kessel-Stueck mit Wurfplatz (Noppen-Kacheln) =====
local Kessel = ordner("Kessel")
for x = -40, 32, 8 do
	for z = -48, -8, 8 do
		P(Kessel, V(8, 1, 8), CF(OX + x + 4, -0.5, z + 4), if ((x + 40) / 8 + (z + 48) / 8) % 2 == 0 then rgb(120, 220, 80) else rgb(100, 205, 65), nil, V_NOPPEN, true)
	end
end
for x = -12, 8, 4 do
	for z = -22, -6, 4 do
		P(Kessel, V(4, 0.6, 4), CF(OX + x + 2, 0.3, z + 2), if ((x + 12) / 4 + (z + 22) / 4) % 2 == 0 then rgb(255, 160, 45) else rgb(255, 195, 80), nil, V_NOPPEN, true)
	end
end
-- Noppen-Oberflaeche (Roblox-eigene Studs) auf Boden, Wurfplatz und Graskappen
for _, f in { Boden, Kessel } do
	for _, p in f:GetChildren() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.Plastic
			p.TopSurface = Enum.SurfaceType.Studs
		end
	end
end
for _, p in Waende:GetChildren() do
	if p:IsA("BasePart") and p.Size.Y == 3 then
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
	end
end
return "Probe fertig (Materialien: " .. tostring(V_ERDE) .. ", " .. tostring(V_GRAS) .. ", " .. tostring(V_NOPPEN) .. ", " .. tostring(V_HOLZ) .. ")"
