-- Bubble Safari: Animationen der Laeden (nur Optik, laeuft auf dem Client).
--   Seifenladen: Seife dreht/wippt, Pumpe drueckt alle 3,2 s und pustet Blasen.
--   Tier-Index:  Teleskop schwenkt, Karussell aus Blasen mit Tieren kreist ueber der Kuppel.
--   Verkaufen:   Waagebalken kippt (Schalen + Blase folgen), Glocke schwingt, Muenzen springen aus der Truhe.
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("Map", 30)
local hub = map and map:WaitForChild("Hub", 30)
if not hub then return end

local schritte = {} -- je Laden eine Funktion(t)

local function seifenladen(laden)
	local seife, pumpe = laden:FindFirstChild("Laden_Seife"), laden:FindFirstChild("Laden_Pumpe")
	if not (seife and pumpe) then return end
	local seifeBasis, pumpeBasis = seife.CFrame, pumpe.CFrame
	local duese = pumpe:FindFirstChild("Duese")
	local blasen = duese and duese:FindFirstChild("Blasen")
	local PERIODE, letzter = 3.2, 0
	table.insert(schritte, function(t)
		seife.CFrame = seifeBasis * CFrame.new(0, math.sin(t * 2) * 0.15, 0) * CFrame.Angles(0, t * 1.6, 0)
		local p = (t % PERIODE) / PERIODE
		local tief = if p < 0.12 then p / 0.12 elseif p < 0.4 then 1 - (p - 0.12) / 0.28 else 0
		tief = tief * tief * (3 - 2 * tief)
		pumpe.CFrame = pumpeBasis * CFrame.new(0, -0.9 * tief, 0)
		local stoss = math.floor(t / PERIODE)
		if stoss ~= letzter and p >= 0.1 then
			letzter = stoss
			if blasen then blasen:Emit(math.random(6, 10)) end
		end
	end)
end

local function indexLaden(laden)
	local tel, achse = laden:FindFirstChild("Laden_Teleskop"), laden:FindFirstChild("TeleskopAchse")
	local kar = laden:FindFirstChild("Karussell")
	local mitte = kar and kar:FindFirstChild("Mitte")
	local telOffset = tel and achse and achse.CFrame:ToObjectSpace(tel.CFrame)
	local blasen = {}
	if kar and mitte then
		for _, b in kar:GetChildren() do
			if b:IsA("Model") and b.PrimaryPart then
				local rel = mitte.CFrame:PointToObjectSpace(b.PrimaryPart.Position)
				table.insert(blasen, { modell = b, radius = Vector2.new(rel.X, rel.Z).Magnitude, winkel = math.atan2(rel.Z, rel.X) })
			end
		end
	end
	table.insert(schritte, function(t)
		if tel and achse then
			tel.CFrame = achse.CFrame * CFrame.Angles(0, math.sin(t * 0.35) * 0.9, 0) * telOffset
		end
		for i, b in blasen do
			local w = b.winkel + t * 0.45
			local pos = mitte.CFrame:PointToWorldSpace(Vector3.new(math.cos(w) * b.radius, math.sin(t * 1.7 + i) * 0.5, math.sin(w) * b.radius))
			-- Tier schaut in Laufrichtung, dreht sich dazu leicht
			b.modell:PivotTo(CFrame.new(pos) * CFrame.Angles(0, -w + math.sin(t + i) * 0.4, 0))
		end
	end)
end

local function verkaufLaden(laden)
	local balken, achse = laden:FindFirstChild("Laden_Balken"), laden:FindFirstChild("BalkenAchse")
	local schaleL, schaleR = laden:FindFirstChild("Laden_SchaleL"), laden:FindFirstChild("Laden_SchaleR")
	local blase = laden:FindFirstChild("WaagenBlase")
	local glocke, gAchse = laden:FindFirstChild("Laden_Glocke"), laden:FindFirstChild("GlockenAchse")
	local quelle = laden:FindFirstChild("MuenzQuelle")
	local muenzen = quelle and quelle:FindFirstChild("Muenzen")
	if not (balken and achse and schaleL and schaleR) then return end
	local bOff = achse.CFrame:ToObjectSpace(balken.CFrame)
	local basisL, basisR = schaleL.CFrame, schaleR.CFrame
	local blaseBasis = blase and blase.CFrame
	local gOff = glocke and gAchse and gAchse.CFrame:ToObjectSpace(glocke.CFrame)
	-- Abstand Achse -> Aufhaengepunkt der Schalen (entlang des Balkens)
	local dL = achse.CFrame:PointToObjectSpace(schaleL.Position).X
	local dR = achse.CFrame:PointToObjectSpace(schaleR.Position).X
	local letzter = 0
	table.insert(schritte, function(t)
		local a = math.sin(t * 1.1) * 0.16
		balken.CFrame = achse.CFrame * CFrame.Angles(0, 0, a) * bOff
		local hochL, hochR = math.sin(a) * dL, math.sin(a) * dR
		local oben = achse.CFrame.UpVector
		schaleL.CFrame = basisL + oben * hochL
		schaleR.CFrame = basisR + oben * hochR
		if blase then blase.CFrame = blaseBasis + oben * hochL end
		if glocke and gOff then glocke.CFrame = gAchse.CFrame * CFrame.Angles(math.sin(t * 2.4) * 0.3, 0, 0) * gOff end
		local takt = math.floor(t / 2.6)
		if muenzen and takt ~= letzter then
			letzter = takt
			muenzen:Emit(math.random(3, 6))
		end
	end)
end

-- Wurfdeck: goldener Kreis pulsiert; Wasserfaelle: Textur rutscht nach unten
do
	local wurf = map:WaitForChild("Wurfplatz", 30)
	local kreis = wurf and wurf:FindFirstChild("Wurfkreis")
	local decal = kreis and kreis:FindFirstChild("Kreis")
	local wasser = {}
	local gel = map:FindFirstChild("Gelaende")
	if gel then
		for _, w in gel:GetChildren() do
			if w.Name == "Wasserfall" and w:FindFirstChild("Wasser") then table.insert(wasser, w.Wasser) end
		end
	end
	table.insert(schritte, function(t)
		if decal then
			local p = 0.5 + 0.5 * math.sin(t * 2.2)
			decal.Transparency = 0.25 * (1 - p)
			decal.Color3 = Color3.new(1, 0.92 + 0.08 * p, 0.75 + 0.25 * p)
		end
		for _, tx in wasser do tx.OffsetStudsV = (t * 9) % 16 end
	end)
end

-- Blasenstab: Seifenfilm schimmert; alle ~3,5 s waechst eine Blase im Ring, loest sich und steigt wackelnd auf
local function blasenstab(m)
	local film, mitte = m:FindFirstChild("Seifenfilm"), m:FindFirstChild("RingMitte")
	if not (film and mitte) then return end
	local skala = m:GetScale()
	local fliegend = {}
	local naechste = 0
	table.insert(schritte, function(t)
		local h = (t * 0.08) % 1
		film.Color = Color3.fromHSV(h, 0.45, 1)
		film.Transparency = 0.4 + 0.12 * math.sin(t * 3)
		if t >= naechste then
			naechste = t + 3.5
			local b = Instance.new("Part")
			b.Shape = Enum.PartType.Ball
			b.Material = Enum.Material.ForceField
			b.Color = Color3.fromHSV(math.random(), 0.3, 1)
			b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
			b.Size = Vector3.one * 0.5
			b.CFrame = mitte.CFrame
			b.Parent = m
			table.insert(fliegend, { teil = b, start = t, seite = (math.random() - 0.5) * 2 })
		end
		for i = #fliegend, 1, -1 do
			local f = fliegend[i]
			local a = t - f.start
			local vorne = -mitte.CFrame.LookVector
			if a < 1.4 then -- waechst im Ring und wird nach vorne gedehnt
				local g = a / 1.4
				f.teil.Size = Vector3.one * (0.5 + 5.5 * g) * skala
				f.teil.CFrame = mitte.CFrame + vorne * (g * 2.5 * skala)
			else -- steigt auf, wackelt, verblasst nach 7 s
				local b = a - 1.4
				local w = 1 + 0.06 * math.sin(t * 9)
				f.teil.Size = Vector3.new(6 * w, 6 / w, 6 * w) * skala
				f.teil.CFrame = mitte.CFrame + vorne * (2.5 * skala + b * 2) + Vector3.new(f.seite * b * 1.5, b * 3.2 + math.sin(b * 2) * 0.6, 0)
				if b > 5.5 then f.teil.Transparency = math.min(1, (b - 5.5) / 1.5) end
				if b > 7 then
					f.teil:Destroy()
					table.remove(fliegend, i)
				end
			end
		end
	end)
end

-- Bestenliste: Krone dreht sich und schwebt
local function bestenliste(m)
	local krone = m:FindFirstChild("Krone")
	if not krone then return end
	local basis = krone.CFrame
	table.insert(schritte, function(t)
		krone.CFrame = basis * CFrame.new(0, math.sin(t * 1.6) * 0.5, 0) * CFrame.Angles(0, t * 0.9, 0)
	end)
end

for name, fn in { Seifenladen = seifenladen, IndexStand = indexLaden, VerkaufStand = verkaufLaden, Blasenstab = blasenstab, Bestenliste = bestenliste } do
	local l = hub:WaitForChild(name, 30)
	if l then fn(l) end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, s in schritte do s(t) end
end)
