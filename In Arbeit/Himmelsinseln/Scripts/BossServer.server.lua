-- Lavadrache: Bosskampf (Server). Liegt in ServerScriptService.
-- Zustand steht als Attribute am Boss-Modell (State, StateStart, HP, MaxHP, Phase),
-- die Animationen und der Lebensbalken laufen im Client und lesen nur diese Attribute.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LAVA = workspace:WaitForChild("Map"):WaitForChild("Lava")
local ARENA = LAVA:WaitForChild("Arena")
local CENTER = LAVA:GetAttribute("Center")
local boss = ARENA:WaitForChild("Lavadrache")

local CFG = {
	FloorY = boss:GetAttribute("FloorY") or 270.9,
	ArenaR = 92,
	BaseHP = 2500, HPPerExtraPlayer = 1500,
	RespawnTime = 45,
	TurnSpeed = math.rad(70),
	FireDamage = 9, FireTick = 0.25, FireRange = 80, FireHalfAngle = math.rad(28), FireTime = 2.6,
	TailDamage = 30, TailRadius = 50,
	StompDamage = 25, StompSpeed = 65, StompWidth = 7, StompJumpHeight = 3.2,
	MeteorDamage = 35, MeteorRadius = 12,
	XPReward = 500,
}

-- Remote events
local events = ReplicatedStorage:FindFirstChild("BossEvents") or Instance.new("Folder")
events.Name = "BossEvents"; events.Parent = ReplicatedStorage
local function remote(name)
	local r = events:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name; r.Parent = events; return r
end
local KnockbackRE = remote("Knockback")
local MessageRE = remote("Message")
local HitRE = remote("BossHit")

-- Boss geometry (rest pose, rotates with the model)
local function bone(name) return boss:FindFirstChild(name, true) end
local headBone = bone("Kopf")
local HIT_BONES = {}
for _, n in ipairs({"Koerper_V", "Koerper_H", "Kopf", "Kiefer", "Hals_1", "Hals_3",
	"Schwanz_1", "Schwanz_3", "Schwanz_5", "Schwanz_7", "Schwanz_9", "Schwanz_11",
	"B_VArm_O_L", "B_VArm_O_R", "B_VArm_U_L", "B_VArm_U_R", "B_HBein_M_L", "B_HBein_M_R", "B_HBein_U_L", "B_HBein_U_R",
	"B_VHand_L_Ballen", "B_VHand_R_Ballen", "B_HFuss_L_Ballen", "B_HFuss_R_Ballen"}) do
	local b = bone(n); if b then table.insert(HIT_BONES, b) end
end
local restPivot = boss:GetPivot()
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local headLocal = restPivot:PointToObjectSpace(headBone.WorldPosition)
local restForward = flat(headBone.WorldPosition - CENTER).Unit
local yaw = 0  -- rotation around the arena centre relative to rest
local function forward() return (CFrame.Angles(0, yaw, 0) * restForward) end
local function applyYaw()
	boss:PivotTo(CFrame.new(CENTER.X, restPivot.Y, CENTER.Z) * CFrame.Angles(0, yaw, 0)
		* CFrame.new(CENTER.X, restPivot.Y, CENTER.Z):Inverse() * restPivot)
end
local function headPos() return boss:GetPivot():PointToWorldSpace(headLocal) end

-- State helpers
local function setState(s)
	boss:SetAttribute("State", s)
	boss:SetAttribute("StateStart", workspace:GetServerTimeNow())
end
local damageBy = {}

local function arenaPlayers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = flat(hrp.Position - CENTER).Magnitude
			if d < CFG.ArenaR + 4 and hrp.Position.Y > CFG.FloorY - 6 and hrp.Position.Y < CFG.FloorY + 80 then
				table.insert(list, {player = p, hrp = hrp, hum = hum})
			end
		end
	end
	return list
end

-- Telegraph marker (red, pulsing, on the floor)
local function marker(cf, size, shape, duration, color)
	local m = Instance.new("Part")
	m.Anchored = true; m.CanCollide = false; m.CanQuery = false; m.CastShadow = false
	m.Material = Enum.Material.SmoothPlastic; m.Color = color or Color3.fromRGB(230, 30, 25)
	m.Transparency = 0.6; m.Size = size; m.CFrame = cf
	if shape then m.Shape = shape end
	m.Parent = ARENA
	TweenService:Create(m, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.35}):Play()
	Debris:AddItem(m, duration)
	return m
end
local function disk(pos, r, duration, color)
	return marker(CFrame.new(pos.X, CFG.FloorY + 0.15, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.2, r * 2, r * 2), Enum.PartType.Cylinder, duration, color)
end

local function hurt(entry, dmg, knock)
	entry.hum:TakeDamage(dmg)
	if knock then KnockbackRE:FireClient(entry.player, knock) end
end

local function turnTowards(pos, dt)
	local want = flat(pos - CENTER)
	if want.Magnitude < 1 then return end
	local f = forward()
	local cur = math.atan2(-f.X, -f.Z)
	local tgt = math.atan2(-want.Unit.X, -want.Unit.Z)
	local diff = (tgt - cur + math.pi) % (2 * math.pi) - math.pi
	local step = math.clamp(diff, -CFG.TurnSpeed * dt, CFG.TurnSpeed * dt)
	yaw += step
	applyYaw()
end

-- Turn while waiting for `t` seconds; returns false if the fight ended
local fighting = false
local defeated = false
local function track(target, t)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		local dt = RunService.Heartbeat:Wait()
		if not fighting then return false end
		if target and target.hrp.Parent then turnTowards(target.hrp.Position, dt) end
	end
	return fighting
end

---------------------------------------------------------------- attacks
local function attackFire(target)
	setState("FireWindup")
	local cone = marker(CFrame.new(), Vector3.new(1, 0.2, 1), nil, 8)
	local function placeCone()
		local f = forward(); local h = headPos()
		local start = Vector3.new(h.X, CFG.FloorY + 0.15, h.Z)
		local w = 2 * math.tan(CFG.FireHalfAngle) * CFG.FireRange
		cone.Size = Vector3.new(w * 0.6, 0.2, CFG.FireRange)
		cone.CFrame = CFrame.lookAt(start + f * CFG.FireRange / 2, start + f * CFG.FireRange)
	end
	local t0 = os.clock()
	while os.clock() - t0 < 1.1 do
		local dt = RunService.Heartbeat:Wait()
		if not fighting then return end
		turnTowards(target.hrp.Position, dt); placeCone()
	end
	setState("Fire")
	-- flame emitter at the mouth
	local nozzle = Instance.new("Part")
	nozzle.Anchored = true; nozzle.CanCollide = false; nozzle.CanQuery = false; nozzle.Transparency = 1
	nozzle.Size = Vector3.new(1, 1, 1); nozzle.Parent = ARENA
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 10))})
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 22)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	pe.Speed = NumberRange.new(70, 85); pe.Lifetime = NumberRange.new(0.9, 1.1); pe.Rate = 160
	pe.SpreadAngle = Vector2.new(14, 14); pe.LightEmission = 1; pe.EmissionDirection = Enum.NormalId.Front
	pe.Parent = nozzle
	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 130, 40); light.Range = 28; light.Brightness = 1.2; light.Parent = nozzle
	local t1, lastTick = os.clock(), 0
	local fireTime = boss:GetAttribute("Phase") == 2 and CFG.FireTime * 1.4 or CFG.FireTime
	while os.clock() - t1 < fireTime do
		local dt = RunService.Heartbeat:Wait()
		if not fighting then break end
		turnTowards(target.hrp.Position, dt * (boss:GetAttribute("Phase") == 2 and 0.7 or 0.35)); placeCone()
		local f = forward(); local h = headPos()
		nozzle.CFrame = CFrame.lookAt(h, h + f + Vector3.new(0, -0.35, 0))
		if os.clock() - lastTick > CFG.FireTick then
			lastTick = os.clock()
			for _, e in ipairs(arenaPlayers()) do
				local to = flat(e.hrp.Position - h)
				if to.Magnitude < CFG.FireRange and to.Magnitude > 0 and math.acos(math.clamp(to.Unit:Dot(f), -1, 1)) < CFG.FireHalfAngle then
					hurt(e, CFG.FireDamage)
				end
			end
		end
	end
	pe.Enabled = false; light:Destroy(); cone:Destroy()
	Debris:AddItem(nozzle, 1.5)
end

local function attackTail()
	setState("TailWindup")
	disk(CENTER, CFG.TailRadius, 1.0)
	if not track(nil, 1.0) then return end
	setState("Tail")
	if not track(nil, 0.25) then return end
	for _, e in ipairs(arenaPlayers()) do
		local to = flat(e.hrp.Position - CENTER)
		if to.Magnitude < CFG.TailRadius then
			hurt(e, CFG.TailDamage, (to.Unit * 90 + Vector3.new(0, 45, 0)))
		end
	end
	track(nil, 0.6)
end

local function attackStomp(target)
	setState("StompWindup")
	if not track(target, 1.0) then return end
	setState("Stomp")
	local ring = Instance.new("Part")
	ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder; ring.Material = Enum.Material.Neon; ring.Color = Color3.fromRGB(255, 120, 30)
	ring.Transparency = 0.25; ring.Parent = ARENA
	local inner = ring:Clone(); inner.Color = Color3.fromRGB(45, 38, 40); inner.Material = Enum.Material.Basalt; inner.Transparency = 0; inner.Parent = ARENA
	local hit = {}
	local r = 12
	while r < CFG.ArenaR + 6 do
		local dt = RunService.Heartbeat:Wait()
		if not fighting then break end
		r += CFG.StompSpeed * dt
		ring.Size = Vector3.new(1.6, r * 2, r * 2)
		ring.CFrame = CFrame.new(CENTER.X, CFG.FloorY + 0.8, CENTER.Z) * CFrame.Angles(0, 0, math.rad(90))
		inner.Size = Vector3.new(1.7, math.max(r - CFG.StompWidth, 1) * 2, math.max(r - CFG.StompWidth, 1) * 2)
		inner.CFrame = ring.CFrame
		for _, e in ipairs(arenaPlayers()) do
			local d = flat(e.hrp.Position - CENTER).Magnitude
			local feet = e.hrp.Position.Y - e.hum.HipHeight - e.hrp.Size.Y / 2
			if not hit[e.player] and d < r and d > r - CFG.StompWidth and feet - CFG.FloorY < CFG.StompJumpHeight then
				hit[e.player] = true
				hurt(e, CFG.StompDamage, (flat(e.hrp.Position - CENTER).Unit * 40 + Vector3.new(0, 35, 0)))
			end
		end
	end
	ring:Destroy(); inner:Destroy()
end

local function attackMeteor()
	setState("Meteor")
	local spots = {}
	for _, e in ipairs(arenaPlayers()) do table.insert(spots, flat(e.hrp.Position) + Vector3.new(0, CFG.FloorY, 0)) end
	while #spots < 9 do
		local a = math.random() * math.pi * 2; local rr = math.random(20, CFG.ArenaR - 8)
		table.insert(spots, Vector3.new(CENTER.X + math.cos(a) * rr, CFG.FloorY, CENTER.Z + math.sin(a) * rr))
	end
	for i, s in ipairs(spots) do
		task.delay((i - 1) * 0.12, function()
			disk(s, CFG.MeteorRadius, 1.7)
			task.wait(1.2)
			local rock = Instance.new("Part")
			rock.Anchored = true; rock.CanCollide = false; rock.CanQuery = false
			rock.Shape = Enum.PartType.Ball; rock.Size = Vector3.new(7, 7, 7)
			rock.Material = Enum.Material.CrackedLava; rock.Color = Color3.fromRGB(255, 110, 40)
			rock.Position = s + Vector3.new(0, 130, 0); rock.Parent = ARENA
			local fire = Instance.new("Fire"); fire.Size = 10; fire.Heat = 20; fire.Parent = rock
			local tw = TweenService:Create(rock, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = s + Vector3.new(0, 3, 0)})
			tw:Play(); tw.Completed:Wait()
			rock:Destroy()
			local ex = Instance.new("Explosion")
			ex.Position = s + Vector3.new(0, 2, 0); ex.BlastRadius = CFG.MeteorRadius; ex.BlastPressure = 0
			ex.DestroyJointRadiusPercent = 0; ex.Parent = workspace
			if not fighting then return end
			for _, e in ipairs(arenaPlayers()) do
				local to = flat(e.hrp.Position - s)
				if to.Magnitude < CFG.MeteorRadius then hurt(e, CFG.MeteorDamage, to.Unit * 30 + Vector3.new(0, 50, 0)) end
			end
		end)
	end
	track(nil, 2.6)
end

---------------------------------------------------------------- boss damage (from the sword)
local function hitPoints()
	local pts = {}
	for _, b in ipairs(HIT_BONES) do table.insert(pts, b.WorldPosition) end
	return pts
end

local function dealBossDamage(player, dmg)
	if not fighting then return end
	local hp = boss:GetAttribute("HP") - dmg
	damageBy[player] = (damageBy[player] or 0) + dmg
	boss:SetAttribute("HP", math.max(hp, 0))
	HitRE:FireAllClients(dmg)
	if hp <= 0 then defeated = true; fighting = false end
end

-- Exposed for the sword script
local api = game:GetService("ServerStorage"):FindFirstChild("BossAPI") or Instance.new("BindableFunction")
api.Name = "BossAPI"; api.Parent = game:GetService("ServerStorage")
api.OnInvoke = function(player, swordPos, reach, dmg)
	if not fighting then return false end
	for _, p in ipairs(hitPoints()) do
		if (p - swordPos).Magnitude < reach then
			dealBossDamage(player, dmg)
			return true
		end
	end
	return false
end

---------------------------------------------------------------- main loop
local function giveXP(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local xp = ls and ls:FindFirstChild("XP")
	if xp then xp.Value += amount end
end

local function setupStats(p)
	if not p:FindFirstChild("leaderstats") then
		local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = p
		local xp = Instance.new("IntValue"); xp.Name = "XP"; xp.Parent = ls
	end
end
Players.PlayerAdded:Connect(setupStats)
for _, p in ipairs(Players:GetPlayers()) do setupStats(p) end

-- Spieler sollen nicht am riesigen Mesh hängen bleiben
for _, d in ipairs(boss:GetDescendants()) do
	if d:IsA("BasePart") then d.CanCollide = false; d.CanTouch = false end
end

local function resetBoss()
	fighting = false
	defeated = false
	yaw = 0; applyYaw()
	boss:SetAttribute("Phase", 1)
	boss:SetAttribute("MaxHP", CFG.BaseHP)
	boss:SetAttribute("HP", CFG.BaseHP)
	damageBy = {}
	setState("Waiting")
end

local function fight()
	local n = #arenaPlayers()
	local maxHP = CFG.BaseHP + math.max(n - 1, 0) * CFG.HPPerExtraPlayer
	boss:SetAttribute("MaxHP", maxHP); boss:SetAttribute("HP", maxHP)
	fighting = true
	setState("Roar")
	MessageRE:FireAllClients("Der Lavadrache erwacht!")
	track(nil, 2.2)
	while fighting do
		local list = arenaPlayers()
		if #list == 0 then break end
		local hp, maxH = boss:GetAttribute("HP"), boss:GetAttribute("MaxHP")
		if hp <= 0 then break end
		if boss:GetAttribute("Phase") == 1 and hp < maxH * 0.5 then
			boss:SetAttribute("Phase", 2)
			MessageRE:FireAllClients("Der Lavadrache wird wütend!")
			setState("Roar"); track(nil, 1.8)
		end
		local phase2 = boss:GetAttribute("Phase") == 2
		local target = list[math.random(1, #list)]
		local dist = flat(target.hrp.Position - CENTER).Magnitude
		local roll = math.random()
		local near = dist < CFG.TailRadius - 5
		if phase2 and roll < 0.25 then
			attackMeteor()
		elseif near then
			local r2 = math.random()
			if r2 < 0.35 then attackTail() elseif r2 < 0.65 then attackStomp(target) else attackFire(target) end
		else
			if roll < 0.7 then attackFire(target) else attackStomp(target) end
		end
		if not fighting then break end
		setState("Idle")
		track(arenaPlayers()[1], phase2 and 0.9 or 1.6)
	end
	if defeated then
		setState("Dead")
		MessageRE:FireAllClients("Der Lavadrache ist besiegt!")
		for p, dmg in pairs(damageBy) do
			if p.Parent and dmg > 0 then giveXP(p, CFG.XPReward) end
		end
		task.wait(CFG.RespawnTime)
	end
	resetBoss()
end

resetBoss()
task.spawn(function()
	while true do
		task.wait(0.5)
		if boss:GetAttribute("State") == "Waiting" and #arenaPlayers() > 0 then
			fight()
		end
	end
end)
