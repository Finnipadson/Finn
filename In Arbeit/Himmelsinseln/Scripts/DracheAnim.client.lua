-- Lavadrache: Knochen-Animationen im Client (LocalScript in StarterPlayerScripts).
-- Liest State/StateStart vom Boss-Modell und bewegt die Knochen über Bone.Transform.
-- Drehachsen werden aus der Geometrie berechnet (vorne/oben/seitlich des Drachen),
-- damit es egal ist, wie die Knochen nach dem Import lokal ausgerichtet sind.
local RunService = game:GetService("RunService")
local LAVA = workspace:WaitForChild("Map"):WaitForChild("Lava")
local CENTER = LAVA:GetAttribute("Center")
local boss = LAVA:WaitForChild("Arena"):WaitForChild("Lavadrache")
-- Modell ist "Persistent"; trotzdem warten, bis alle Knochen da sind
repeat task.wait(0.5) until boss:FindFirstChild("Kopf", true) and boss:FindFirstChild("Schwanz_11", true) and boss:FindFirstChild("WR_F4", true)
task.wait(0.5)

local UP = Vector3.yAxis
local bones = {}
for _, d in ipairs(boss:GetDescendants()) do
	if d:IsA("Bone") then bones[d.Name] = d end
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- Ruhelage relativ zum Modell (Transform ist hier noch Identität)
local head = bones.Kopf
local F = flat(head.WorldPosition - CENTER).Unit                -- vorne (Welt)
local PITCH_UP = F:Cross(UP).Unit                                 -- Achse: Vorderteil hebt sich

local rig = {}
local function axisLocal(b, worldAxis)
	return b.WorldCFrame:VectorToObjectSpace(worldAxis).Unit
end
for name, b in pairs(bones) do
	rig[name] = {
		bone = b,
		yaw = axisLocal(b, UP), pitch = axisLocal(b, PITCH_UP), roll = axisLocal(b, F),
		cur = {0, 0, 0}, -- yaw, pitch, roll (Grad)
	}
end
-- Flügel: Achse so wählen, dass positiver Winkel die Spitze hebt
for _, side in ipairs({"WL_", "WR_"}) do
	local root, tip = bones[side .. "Arm"], bones[side .. "F2"] or bones[side .. "Hand"]
	if root and tip then
		local d = flat(tip.WorldPosition - root.WorldPosition).Unit
		local k = d:Cross(UP).Unit
		for _, n in ipairs({"Arm", "Hand", "F1", "F2", "F3", "F4"}) do
			local r = rig[side .. n]
			if r then r.flap = axisLocal(r.bone, k) end
		end
	end
end

local function list(prefix, n0, n1)
	local t = {}
	for i = n0, n1 do if rig[prefix .. i] then table.insert(t, rig[prefix .. i]) end end
	return t
end
local NECK = list("Hals_", 0, 4)
local TAIL = list("Schwanz_", 0, 11)
local WINGS = {}
for _, side in ipairs({"WL_", "WR_"}) do
	for _, n in ipairs({"Arm", "Hand", "F1", "F2", "F3", "F4"}) do
		if rig[side .. n] then table.insert(WINGS, {r = rig[side .. n], depth = (n == "Arm") and 0 or (n == "Hand" and 1 or 2)}) end
	end
end

-- Leuchten der Haut (EmissiveStrength) pulsiert
local surfaces = {}
for _, d in ipairs(boss:GetDescendants()) do
	if d:IsA("SurfaceAppearance") then table.insert(surfaces, d) end
end
local parts = {}
for _, d in ipairs(boss:GetDescendants()) do
	if d:IsA("MeshPart") then table.insert(parts, d) end
end

local targets = {}
local function set(r, yaw, pitch, roll)
	if not r then return end
	local t = targets[r]
	if not t then t = {0, 0, 0}; targets[r] = t end
	t[1] += yaw or 0; t[2] += pitch or 0; t[3] += roll or 0
end

local function smooth01(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

RunService.RenderStepped:Connect(function(dt)
	local state = boss:GetAttribute("State") or "Waiting"
	local st = workspace:GetServerTimeNow() - (boss:GetAttribute("StateStart") or 0)
	local t = os.clock()
	table.clear(targets)
	local speed = 6
	local flapAmp, flapRate, jaw = 6, 1.4, 0

	-- Grundbewegung (immer)
	set(rig.Koerper_V, 0, math.sin(t * 1.6) * 1.5, 0)
	for i, r in ipairs(NECK) do set(r, math.sin(t * 0.7) * 2.5, math.sin(t * 1.2 - i * 0.3) * 1.8, 0) end
	for i, r in ipairs(TAIL) do set(r, math.sin(t * 1.8 - i * 0.45) * (2.5 + i * 0.5), 0, 0) end

	if state == "Waiting" then
		for _, r in ipairs(NECK) do set(r, 0, -3, 0) end
		flapAmp, flapRate = 3, 0.8
	elseif state == "Roar" or state == "Meteor" then
		local k = smooth01(st / 0.5)
		for _, r in ipairs(NECK) do set(r, 0, 9 * k, 0) end
		set(rig.Kopf, 0, 12 * k, 0); set(rig.Koerper_H, 0, 6 * k, 0)
		jaw = 32 * k; flapAmp, flapRate = 26, 5.5
	elseif state == "FireWindup" then
		local k = smooth01(st / 1.0)
		for _, r in ipairs(NECK) do set(r, 0, 7 * k, 0) end
		set(rig.Kopf, 0, 8 * k, 0); jaw = 14 * k; flapAmp = 12
	elseif state == "Fire" then
		local k = smooth01(st / 0.25)
		for i, r in ipairs(NECK) do set(r, math.sin(t * 2.2) * 3, -4 * k, 0) end
		set(rig.Kopf, 0, -6 * k, 0); jaw = 34; flapAmp, flapRate = 10, 2.5
		speed = 10
	elseif state == "TailWindup" then
		local k = smooth01(st / 0.9)
		for i, r in ipairs(TAIL) do set(r, -7 * k, 2 * k, 0) end
		set(rig.Koerper_H, -10 * k, 0, 0); for _, r in ipairs(NECK) do set(r, 4 * k, 0, 0) end
	elseif state == "Tail" then
		local k = smooth01(st / 0.22)
		for i, r in ipairs(TAIL) do set(r, -7 + 19 * k, 2, 0) end
		set(rig.Koerper_H, -10 + 22 * k, 0, 0); for _, r in ipairs(NECK) do set(r, 4 - 9 * k, 0, 0) end
		speed = 22
	elseif state == "StompWindup" then
		local k = smooth01(st / 0.9)
		set(rig.Koerper_H, 0, 20 * k, 0); set(rig.Koerper_V, 0, 6 * k, 0)
		for _, r in ipairs(NECK) do set(r, 0, 3 * k, 0) end
		jaw = 18 * k; flapAmp, flapRate = 30, 3
	elseif state == "Stomp" then
		local k = smooth01(st / 0.15)
		set(rig.Koerper_H, 0, 20 - 24 * k, 0)
		for _, r in ipairs(NECK) do set(r, 0, -2 * k, 0) end
		jaw = 10; flapAmp = 8
		speed = 25
	elseif state == "Dead" then
		local k = smooth01(st / 2.0)
		set(rig.Koerper_H, 0, -3 * k, 24 * k)
		for _, r in ipairs(NECK) do set(r, 0, -9 * k, 4 * k) end
		for _, r in ipairs(TAIL) do set(r, 0, -2 * k, 0) end
		jaw = 20 * k; flapAmp = 0
	end

	-- Flügelschlag
	for _, w in ipairs(WINGS) do
		local a = math.sin(t * flapRate - w.depth * 0.6) * flapAmp * (w.depth == 0 and 1 or 0.6)
		if state == "Dead" then a = -18 * smooth01(st / 2) end
		local tt = targets[w.r] or {0, 0, 0}; targets[w.r] = tt
		tt.flap = a
	end
	if rig.Kiefer then set(rig.Kiefer, 0, -jaw, 0) end

	-- anwenden (geglättet)
	local alpha = math.min(1, dt * speed)
	for _, r in pairs(rig) do
		local tg = targets[r] or {0, 0, 0}
		local c = r.cur
		c[1] += ((tg[1] or 0) - c[1]) * alpha
		c[2] += ((tg[2] or 0) - c[2]) * alpha
		c[3] += ((tg[3] or 0) - c[3]) * alpha
		c.flap = (c.flap or 0) + ((tg.flap or 0) - (c.flap or 0)) * math.min(1, dt * 10)
		local cf = CFrame.fromAxisAngle(r.yaw, math.rad(c[1])) * CFrame.fromAxisAngle(r.pitch, math.rad(c[2]))
			* CFrame.fromAxisAngle(r.roll, math.rad(c[3]))
		if r.flap then cf = cf * CFrame.fromAxisAngle(r.flap, math.rad(c.flap)) end
		r.bone.Transform = cf
	end

	-- Leuchten + Ausblenden beim Tod
	local glow = 1.6 + math.sin(t * 2.4) * 0.5 + ((state == "Fire" or state == "Roar" or state == "Meteor") and 1.2 or 0)
	for _, s in ipairs(surfaces) do s.EmissiveStrength = glow end
	local fade = 0
	if state == "Dead" then fade = math.clamp((st - 2.5) / 2, 0, 1) end
	for _, p in ipairs(parts) do p.LocalTransparencyModifier = fade end
end)
