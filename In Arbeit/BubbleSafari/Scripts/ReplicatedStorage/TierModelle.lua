-- Bubble Safari: Block-Tiere per Skript bauen (ModuleScript in ReplicatedStorage)
-- Vorne = -Z. Pivot = Boden-Mitte. T.bauen(artId, groesse, material) -> Model
local T = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local V = Vector3.new
local WEISS, SCHWARZ, ROSA = rgb(250, 250, 250), rgb(25, 25, 30), rgb(255, 150, 170)

-- Spezifikationen: koerper/kopf = Groessen, bein = Beinlaenge, extras: {an, g, p, f, m, form, t, neon}
local S = {}

S.Wiesenhase = {
	koerper = V(1.6, 1.4, 2.2), kopf = V(1.5, 1.4, 1.3), farbe = rgb(235, 230, 220), bein = 0.5, dicke = 0.45,
	extras = {
		{ an = "kopf", g = V(0.35, 1.5, 0.25), p = V(-0.4, 1.35, 0.15) },
		{ an = "kopf", g = V(0.35, 1.5, 0.25), p = V(0.4, 1.35, 0.15) },
		{ an = "kopf", g = V(0.18, 1.1, 0.05), p = V(-0.4, 1.35, 0.0), f = ROSA },
		{ an = "kopf", g = V(0.18, 1.1, 0.05), p = V(0.4, 1.35, 0.0), f = ROSA },
		{ an = "kopf", g = V(0.6, 0.6, 0.1), p = V(0.62, 1.55, -0.05), f = WEISS },
		{ an = "kopf", g = V(0.25, 0.25, 0.12), p = V(0.62, 1.55, -0.12), f = rgb(255, 210, 40) },
		{ an = "kopf", g = V(0.3, 0.2, 0.1), p = V(0, -0.25, -0.7), f = ROSA },
		{ an = "koerper", g = V(0.7, 0.7, 0.7), p = V(0, 0.3, 1.2), f = WEISS, form = "Ball" },
	},
}

S.Bluetenlamm = {
	koerper = V(2.2, 1.9, 2.8), kopf = V(1.3, 1.4, 1.2), farbe = rgb(248, 246, 240), kopfFarbe = rgb(70, 60, 60),
	beinFarbe = rgb(70, 60, 60), bein = 0.9, dicke = 0.45,
	extras = {
		{ an = "kopf", g = V(1.35, 0.4, 0.9), p = V(0, 0.75, 0.2), f = rgb(248, 246, 240) },
		{ an = "kopf", g = V(0.6, 0.25, 0.35), p = V(-0.85, 0.3, 0.2) },
		{ an = "kopf", g = V(0.6, 0.25, 0.35), p = V(0.85, 0.3, 0.2) },
		{ an = "kopf", g = V(1.45, 0.15, 1.0), p = V(0, 0.9, 0.05), f = rgb(90, 170, 70) },
		{ an = "kopf", g = V(0.35, 0.3, 0.35), p = V(-0.6, 1.05, -0.3), f = rgb(255, 120, 170) },
		{ an = "kopf", g = V(0.35, 0.3, 0.35), p = V(-0.2, 1.08, -0.42), f = rgb(255, 215, 60) },
		{ an = "kopf", g = V(0.35, 0.3, 0.35), p = V(0.2, 1.08, -0.42), f = rgb(190, 140, 255) },
		{ an = "kopf", g = V(0.35, 0.3, 0.35), p = V(0.6, 1.05, -0.3), f = rgb(255, 120, 170) },
	},
}

S.Blumenigel = {
	koerper = V(2, 1.4, 2.4), kopf = V(1.2, 1.0, 1.0), farbe = rgb(150, 105, 70), kopfFarbe = rgb(205, 170, 130),
	bein = 0.35, dicke = 0.4, kopfY = 0.95,
	extras = {
		{ an = "kopf", g = V(0.45, 0.35, 0.5), p = V(0, -0.15, -0.65), f = rgb(205, 170, 130) },
		{ an = "kopf", g = V(0.2, 0.2, 0.1), p = V(0, -0.05, -0.93), f = SCHWARZ },
	},
}
do -- Blueten statt Stacheln
	local farben = { rgb(255, 120, 170), rgb(255, 215, 60), rgb(190, 140, 255), WEISS }
	local i = 0
	for _, x in { -0.6, 0, 0.6 } do
		for _, z in { -0.7, 0.1, 0.9 } do
			i += 1
			table.insert(S.Blumenigel.extras, { an = "koerper", g = V(0.5, 0.35, 0.5), p = V(x, 0.85, z), f = farben[i % 4 + 1] })
			table.insert(S.Blumenigel.extras, { an = "koerper", g = V(0.2, 0.12, 0.2), p = V(x, 1.06, z), f = rgb(255, 230, 90) })
		end
	end
end

S.Pusteblumenfuchs = {
	skala = 1.25, koerper = V(1.6, 1.5, 2.8), kopf = V(1.6, 1.4, 1.5), farbe = rgb(235, 125, 45),
	beinFarbe = rgb(60, 40, 30), bein = 0.8, dicke = 0.4,
	extras = {
		{ an = "kopf", g = V(0.7, 0.55, 0.6), p = V(0, -0.3, -0.9), f = WEISS },
		{ an = "kopf", g = V(0.25, 0.2, 0.1), p = V(0, -0.1, -1.22), f = SCHWARZ },
		{ an = "kopf", g = V(0.45, 0.7, 0.2), p = V(-0.5, 0.95, 0.2) },
		{ an = "kopf", g = V(0.45, 0.7, 0.2), p = V(0.5, 0.95, 0.2) },
		{ an = "kopf", g = V(0.46, 0.22, 0.22), p = V(-0.5, 1.25, 0.2), f = SCHWARZ },
		{ an = "kopf", g = V(0.46, 0.22, 0.22), p = V(0.5, 1.25, 0.2), f = SCHWARZ },
		{ an = "koerper", g = V(1.2, 1.0, 0.2), p = V(0, -0.1, -1.42), f = WEISS },
		{ an = "koerper", g = V(0.35, 0.35, 1.2), p = V(0, 0.4, 1.9) },
		{ an = "koerper", g = V(2.2, 2.2, 2.2), p = V(0, 1.2, 2.9), f = WEISS, form = "Ball", t = 0.25, neon = true, name = "Flaum" },
	},
	partikel = "flaum",
}

S.Moosmaus = {
	koerper = V(1.2, 1.0, 1.6), kopf = V(1.1, 1.0, 1.0), farbe = rgb(140, 120, 100), bein = 0.3, dicke = 0.3,
	extras = {
		{ an = "kopf", g = V(0.75, 0.75, 0.15), p = V(-0.5, 0.65, 0.2), f = rgb(170, 140, 125) },
		{ an = "kopf", g = V(0.75, 0.75, 0.15), p = V(0.5, 0.65, 0.2), f = rgb(170, 140, 125) },
		{ an = "kopf", g = V(0.45, 0.45, 0.05), p = V(-0.5, 0.65, 0.11), f = ROSA },
		{ an = "kopf", g = V(0.45, 0.45, 0.05), p = V(0.5, 0.65, 0.11), f = ROSA },
		{ an = "kopf", g = V(0.22, 0.18, 0.1), p = V(0, -0.2, -0.55), f = ROSA },
		{ an = "koerper", g = V(1.0, 0.25, 1.3), p = V(0, 0.55, 0.05), f = rgb(90, 160, 60), m = Enum.Material.Grass },
		{ an = "koerper", g = V(0.15, 0.15, 1.4), p = V(0, -0.1, 1.45), f = ROSA },
	},
}

S.Fliegenpilzkroete = {
	koerper = V(2.4, 1.1, 2.0), kopf = V(2.0, 1.0, 1.2), farbe = rgb(120, 145, 75), bein = 0.3, dicke = 0.55,
	kopfY = 1.2, augen = "oben",
	extras = {
		{ an = "kopf", g = V(2.5, 0.55, 2.1), p = V(0, 0.95, 0.4), f = rgb(220, 40, 40) },
		{ an = "kopf", g = V(2.2, 0.15, 1.9), p = V(0, 0.62, 0.4), f = WEISS },
		{ an = "kopf", g = V(0.4, 0.12, 0.4), p = V(-0.6, 1.26, 0.0), f = WEISS },
		{ an = "kopf", g = V(0.4, 0.12, 0.4), p = V(0.7, 1.26, 0.3), f = WEISS },
		{ an = "kopf", g = V(0.4, 0.12, 0.4), p = V(0, 1.26, 1.0), f = WEISS },
		{ an = "kopf", g = V(0.3, 0.12, 0.3), p = V(-0.8, 1.26, 0.95), f = WEISS },
		{ an = "kopf", g = V(1.3, 0.1, 0.05), p = V(0, -0.25, -0.62), f = rgb(60, 70, 40) },
	},
}

S.Pilzhutwaschbaer = {
	koerper = V(1.8, 1.5, 2.6), kopf = V(1.6, 1.4, 1.4), farbe = rgb(125, 125, 130), beinFarbe = rgb(50, 50, 55),
	bein = 0.6, dicke = 0.45,
	extras = {
		{ an = "kopf", g = V(1.62, 0.5, 0.08), p = V(0, 0.12, -0.7), f = rgb(40, 40, 45) },
		{ an = "kopf", g = V(0.6, 0.45, 0.4), p = V(0, -0.3, -0.85), f = rgb(205, 205, 205) },
		{ an = "kopf", g = V(0.22, 0.18, 0.1), p = V(0, -0.15, -1.08), f = SCHWARZ },
		{ an = "kopf", g = V(0.4, 0.4, 0.2), p = V(-0.55, 0.85, 0.25) },
		{ an = "kopf", g = V(0.4, 0.4, 0.2), p = V(0.55, 0.85, 0.25) },
		{ an = "kopf", g = V(0.7, 0.3, 0.7), p = V(0, 0.82, 0.1), f = rgb(235, 220, 190) },
		{ an = "kopf", g = V(1.9, 0.5, 1.7), p = V(0, 1.15, 0.1), f = rgb(150, 95, 60) },
	},
}
for i = 0, 3 do
	table.insert(S.Pilzhutwaschbaer.extras, { an = "koerper", g = V(0.55, 0.55, 0.4), p = V(0, 0.25 + i * 0.12, 1.5 + i * 0.4), f = if i % 2 == 0 then rgb(125, 125, 130) else rgb(40, 40, 45) })
end

S.Moosdachs = {
	skala = 1.25, koerper = V(2.2, 1.4, 3.0), kopf = V(1.6, 1.2, 1.4), farbe = rgb(70, 70, 78), beinFarbe = rgb(40, 40, 45),
	bein = 0.45, dicke = 0.5,
	extras = {
		{ an = "kopf", g = V(0.45, 0.1, 1.42), p = V(0, 0.62, 0), f = WEISS },
		{ an = "kopf", g = V(0.45, 0.9, 0.06), p = V(0, 0.15, -0.72), f = WEISS },
		{ an = "kopf", g = V(0.6, 0.4, 0.5), p = V(0, -0.25, -0.85), f = rgb(120, 120, 125) },
		{ an = "kopf", g = V(0.22, 0.18, 0.1), p = V(0, -0.15, -1.12), f = SCHWARZ },
		{ an = "koerper", g = V(1.9, 0.35, 2.6), p = V(0, 0.85, 0), f = rgb(80, 150, 60), m = Enum.Material.Grass },
	},
}
for _, pos in { V(-0.5, 1.2, -0.6), V(0.6, 1.2, 0.3), V(-0.3, 1.2, 0.9) } do
	table.insert(S.Moosdachs.extras, { an = "koerper", g = V(0.15, 0.45, 0.15), p = pos, f = rgb(235, 230, 210) })
	table.insert(S.Moosdachs.extras, { an = "koerper", g = V(0.55, 0.22, 0.55), p = pos + V(0, 0.3, 0), f = rgb(90, 240, 255), neon = true })
end

S.Seerosenfrosch = {
	koerper = V(1.8, 1.1, 1.8), kopf = V(1.8, 0.9, 1.0), farbe = rgb(85, 175, 75), bein = 0.3, dicke = 0.5,
	kopfY = 1.15, augen = "oben",
	extras = {
		{ an = "koerper", g = V(1.4, 0.6, 0.1), p = V(0, -0.15, -0.91), f = rgb(190, 225, 140) },
		{ an = "kopf", g = V(1.2, 0.1, 0.05), p = V(0, -0.2, -0.52), f = rgb(40, 90, 40) },
		{ an = "kopf", g = V(2.1, 0.15, 2.1), p = V(0, 0.95, 0.2), f = rgb(60, 140, 60) },
		{ an = "kopf", g = V(0.4, 0.35, 0.4), p = V(0.25, 1.15, 0.0), f = rgb(255, 150, 200) },
		{ an = "kopf", g = V(0.4, 0.35, 0.4), p = V(0.65, 1.15, 0.4), f = rgb(255, 150, 200) },
		{ an = "kopf", g = V(0.4, 0.35, 0.4), p = V(0.25, 1.15, 0.4), f = rgb(255, 190, 220) },
		{ an = "kopf", g = V(0.4, 0.35, 0.4), p = V(0.65, 1.15, 0.0), f = rgb(255, 190, 220) },
		{ an = "kopf", g = V(0.25, 0.3, 0.25), p = V(0.45, 1.3, 0.2), f = rgb(255, 220, 60) },
	},
}

S.Schilfente = {
	koerper = V(1.6, 1.3, 2.2), kopf = V(1.1, 1.1, 1.1), farbe = rgb(150, 120, 85), kopfFarbe = rgb(40, 120, 60),
	beinFarbe = rgb(240, 150, 40), beine = 2, bein = 0.6, dicke = 0.25, kopfY = 2.3,
	extras = {
		{ an = "kopf", g = V(0.8, 0.3, 0.6), p = V(0, -0.15, -0.8), f = rgb(245, 200, 40) },
		{ an = "kopf", g = V(1.12, 0.15, 1.12), p = V(0, -0.5, 0), f = WEISS },
		{ an = "koerper", g = V(0.8, 0.4, 0.5), p = V(0, 0.5, 1.2) },
		{ an = "koerper", g = V(0.12, 1.6, 0.12), p = V(-0.3, 1.3, 0.5), f = rgb(110, 160, 60) },
		{ an = "koerper", g = V(0.12, 1.6, 0.12), p = V(0.3, 1.2, 0.7), f = rgb(110, 160, 60) },
		{ an = "koerper", g = V(0.28, 0.55, 0.28), p = V(-0.3, 2.2, 0.5), f = rgb(110, 70, 40) },
		{ an = "koerper", g = V(0.28, 0.55, 0.28), p = V(0.3, 2.1, 0.7), f = rgb(110, 70, 40) },
	},
}

S.Moosschildkroete = {
	koerper = V(1.8, 0.8, 2.2), kopf = V(0.9, 0.8, 0.9), farbe = rgb(150, 170, 100), bein = 0.4, dicke = 0.5,
	kopfY = 0.8, kopfZ = -1.55,
	extras = {
		{ an = "koerper", g = V(2.4, 1.1, 2.6), p = V(0, 0.75, 0), f = rgb(90, 130, 60) },
		{ an = "koerper", g = V(2.5, 0.2, 2.7), p = V(0, 0.25, 0), f = rgb(70, 100, 50) },
		{ an = "koerper", g = V(1.6, 0.3, 1.8), p = V(0, 1.4, 0), f = rgb(110, 170, 70), m = Enum.Material.Grass },
		{ an = "koerper", g = V(0.35, 0.3, 0.35), p = V(0.4, 1.65, -0.3), f = WEISS },
		{ an = "koerper", g = V(0.15, 0.32, 0.15), p = V(0.4, 1.66, -0.3), f = rgb(255, 220, 60) },
	},
}

S.Nebelotter = {
	skala = 1.25, koerper = V(1.4, 1.2, 3.2), kopf = V(1.3, 1.1, 1.2), farbe = rgb(170, 190, 215), bein = 0.4, dicke = 0.4,
	transparenz = 0.12,
	extras = {
		{ an = "kopf", g = V(0.8, 0.5, 0.4), p = V(0, -0.25, -0.75), f = rgb(225, 232, 242) },
		{ an = "kopf", g = V(0.25, 0.2, 0.1), p = V(0, -0.08, -0.98), f = rgb(60, 70, 90) },
		{ an = "kopf", g = V(0.3, 0.3, 0.2), p = V(-0.5, 0.6, 0.2) },
		{ an = "kopf", g = V(0.3, 0.3, 0.2), p = V(0.5, 0.6, 0.2) },
		{ an = "koerper", g = V(0.5, 0.4, 2.0), p = V(0, -0.2, 2.5) },
	},
	partikel = "nebel",
}

T.Specs = S

local function teil(modell, name, groesse, cf, farbe, material, form, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = groesse
	p.CFrame = cf
	p.Color = farbe
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if form == "Ball" then p.Shape = Enum.PartType.Ball end
	p.Transparency = transp or 0
	p.Parent = modell
	return p
end

local GOLD, DIAMANT = rgb(255, 196, 50), rgb(160, 225, 255)

function T.bauen(artId, groesse, material)
	local s = S[artId]
	if not s then return nil end
	local m = Instance.new("Model")
	m.Name = artId
	local wurzel = teil(m, "Wurzel", V(1, 1, 1), CFrame.new(), WEISS, nil, nil, 1)
	m.PrimaryPart = wurzel

	local k, kp = s.koerper, s.kopf
	local bein = s.bein
	local kFarbe = s.farbe
	local kopfFarbe = s.kopfFarbe or kFarbe
	local t = s.transparenz or 0
	local kc = CFrame.new(0, bein + k.Y / 2, 0)
	teil(m, "Koerper", k, kc, kFarbe, nil, nil, t)
	local kopfY = s.kopfY or (bein + k.Y * 0.8 + kp.Y * 0.25)
	local kopfZ = s.kopfZ or -(k.Z / 2 + kp.Z * 0.35)
	local hc = CFrame.new(0, kopfY, kopfZ)
	teil(m, "Kopf", kp, hc, kopfFarbe, nil, nil, t)

	-- Beine
	local d = s.dicke or 0.4
	local bf = s.beinFarbe or kFarbe
	local bx = k.X / 2 - d / 2
	local zs = if s.beine == 2 then { 0 } else { -(k.Z / 2 - d / 2), k.Z / 2 - d / 2 }
	for _, z in zs do
		for _, x in { -bx, bx } do
			teil(m, "Bein", V(d, bein + 0.1, d), CFrame.new(x, (bein + 0.1) / 2, z), bf, nil, nil, t)
		end
	end

	-- Augen
	if s.augen == "oben" then
		for _, x in { -kp.X * 0.3, kp.X * 0.3 } do
			teil(m, "Auge", V(0.6, 0.55, 0.6), hc * CFrame.new(x, kp.Y / 2 + 0.2, -kp.Z * 0.2), WEISS)
			teil(m, "Pupille", V(0.3, 0.3, 0.1), hc * CFrame.new(x, kp.Y / 2 + 0.25, -kp.Z * 0.2 - 0.31), SCHWARZ)
		end
	else
		for _, x in { -kp.X * 0.24, kp.X * 0.24 } do
			teil(m, "Auge", V(kp.X * 0.24, kp.Y * 0.3, 0.1), hc * CFrame.new(x, kp.Y * 0.1, -kp.Z / 2 - 0.06), WEISS)
			teil(m, "Pupille", V(kp.X * 0.13, kp.Y * 0.18, 0.1), hc * CFrame.new(x, kp.Y * 0.07, -kp.Z / 2 - 0.12), SCHWARZ)
		end
	end

	for _, e in s.extras do
		local basis = if e.an == "kopf" then hc else kc
		local p = teil(m, e.name or "Deko", e.g, basis * CFrame.new(e.p), e.f or (if e.an == "kopf" then kopfFarbe else kFarbe),
			if e.neon then Enum.Material.Neon else e.m, e.form, e.t or t)
		if e.name == "Flaum" and s.partikel == "flaum" then
			local pe = Instance.new("ParticleEmitter")
			pe.Color = ColorSequence.new(WEISS)
			pe.Size = NumberSequence.new(0.25)
			pe.Rate = 4
			pe.Lifetime = NumberRange.new(2, 3)
			pe.Speed = NumberRange.new(1, 2)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Acceleration = V(0, 0.5, 0)
			pe.Parent = p
		end
	end

	if s.partikel == "nebel" then
		local koerper = m:FindFirstChild("Koerper")
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(rgb(200, 215, 235))
		pe.Size = NumberSequence.new(2, 4)
		pe.Transparency = NumberSequence.new(0.6, 1)
		pe.Rate = 5
		pe.Lifetime = NumberRange.new(2, 3)
		pe.Speed = NumberRange.new(0.3, 0.8)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = koerper
	end

	-- Material-Variante (Phase 3, schon vorbereitet)
	material = material or 1
	if material > 1 then
		local i = 0
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Wurzel" and p.Name ~= "Pupille" and p.Name ~= "Auge" then
				i += 1
				if material == 2 then
					p.Color = GOLD:Lerp(p.Color, 0.25); p.Material = Enum.Material.Metal
				elseif material == 3 then
					p.Color = DIAMANT:Lerp(p.Color, 0.15); p.Material = Enum.Material.Glass; p.Transparency = math.max(p.Transparency, 0.2)
				else
					p.Color = Color3.fromHSV((i * 0.09) % 1, 0.6, 1); p.Material = Enum.Material.Neon
				end
			end
		end
	end

	local skala = (s.skala or 1) * (if groesse then require(script.Parent.Daten).Groessen[groesse].skala else 1)
	if skala ~= 1 then m:ScaleTo(skala) end
	m:SetAttribute("Art", artId)
	return m
end

-- Hoehe (Studs) eines gebauten Modells
function T.hoehe(m)
	return m:GetExtentsSize().Y
end

return T
