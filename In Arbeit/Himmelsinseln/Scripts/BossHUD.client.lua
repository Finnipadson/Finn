-- Boss-Lebensbalken, Meldungen und Rückstoß (LocalScript im ScreenGui "BossHUD" in StarterGui)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local events = ReplicatedStorage:WaitForChild("BossEvents")
local LAVA = workspace:WaitForChild("Map"):WaitForChild("Lava")
local CENTER = LAVA:GetAttribute("Center")
local boss = LAVA:WaitForChild("Arena"):WaitForChild("Lavadrache")

-- UI
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0); frame.Position = UDim2.new(0.5, 0, 0, 56)
frame.Size = UDim2.new(0.5, 0, 0, 46); frame.BackgroundTransparency = 1; frame.Visible = false; frame.Parent = gui
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 20); title.BackgroundTransparency = 1; title.Font = Enum.Font.FredokaOne
title.TextScaled = true; title.TextColor3 = Color3.fromRGB(255, 220, 200); title.Text = "LAVADRACHE"
title.TextStrokeTransparency = 0.4; title.Parent = frame
local back = Instance.new("Frame")
back.Position = UDim2.new(0, 0, 0, 24); back.Size = UDim2.new(1, 0, 0, 18)
back.BackgroundColor3 = Color3.fromRGB(30, 15, 15); back.BorderSizePixel = 0; back.Parent = frame
Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
local stroke = Instance.new("UIStroke", back); stroke.Color = Color3.fromRGB(255, 140, 60); stroke.Thickness = 2
local trail = Instance.new("Frame")
trail.Size = UDim2.new(1, 0, 1, 0); trail.BackgroundColor3 = Color3.fromRGB(255, 230, 200); trail.BorderSizePixel = 0; trail.Parent = back
Instance.new("UICorner", trail).CornerRadius = UDim.new(0, 6)
local fill = Instance.new("Frame")
fill.Size = UDim2.new(1, 0, 1, 0); fill.BorderSizePixel = 0; fill.Parent = back
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
local grad = Instance.new("UIGradient", fill)
grad.Color = ColorSequence.new(Color3.fromRGB(255, 60, 30), Color3.fromRGB(255, 170, 40))
local hpText = Instance.new("TextLabel")
hpText.Size = UDim2.new(1, 0, 1, 0); hpText.BackgroundTransparency = 1; hpText.Font = Enum.Font.GothamBold
hpText.TextScaled = true; hpText.TextColor3 = Color3.new(1, 1, 1); hpText.TextStrokeTransparency = 0.5; hpText.ZIndex = 3; hpText.Parent = back

local msg = Instance.new("TextLabel")
msg.AnchorPoint = Vector2.new(0.5, 0.5); msg.Position = UDim2.new(0.5, 0, 0.3, 0); msg.Size = UDim2.new(0.7, 0, 0, 50)
msg.BackgroundTransparency = 1; msg.Font = Enum.Font.FredokaOne; msg.TextScaled = true
msg.TextColor3 = Color3.fromRGB(255, 180, 80); msg.TextStrokeTransparency = 0.2; msg.TextTransparency = 1; msg.Parent = gui

events:WaitForChild("Message").OnClientEvent:Connect(function(text)
	msg.Text = text; msg.TextTransparency = 0; msg.TextStrokeTransparency = 0.2
	task.delay(2.5, function()
		TweenService:Create(msg, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end)
end)

events:WaitForChild("Knockback").OnClientEvent:Connect(function(v)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.AssemblyLinearVelocity = v end
end)

local function inArena()
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local d = Vector3.new(hrp.Position.X - CENTER.X, 0, hrp.Position.Z - CENTER.Z).Magnitude
	return d < 110 and hrp.Position.Y > 250
end

local shown = 1
RunService.RenderStepped:Connect(function(dt)
	local state = boss:GetAttribute("State")
	frame.Visible = inArena() and state ~= nil and state ~= "Waiting"
	if not frame.Visible then return end
	local hp, maxHP = boss:GetAttribute("HP") or 0, boss:GetAttribute("MaxHP") or 1
	local frac = math.clamp(hp / maxHP, 0, 1)
	fill.Size = UDim2.new(frac, 0, 1, 0)
	shown = shown + (frac - shown) * math.min(dt * 3, 1)
	trail.Size = UDim2.new(math.max(shown, frac), 0, 1, 0)
	hpText.Text = string.format("%d / %d", math.ceil(hp), maxHP)
	title.Text = (state == "Dead") and "LAVADRACHE BESIEGT!" or ((boss:GetAttribute("Phase") == 2) and "LAVADRACHE  (WÜTEND)" or "LAVADRACHE")
end)
