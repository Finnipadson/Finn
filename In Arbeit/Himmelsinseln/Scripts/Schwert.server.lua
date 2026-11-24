-- Schwert (Script im Tool "Schwert" in StarterPack): Klick = Hieb, trifft den Lavadrachen in Reichweite.
local Players = game:GetService("Players")
local tool = script.Parent
local api = game:GetService("ServerStorage"):WaitForChild("BossAPI")
local COOLDOWN, REACH, DAMAGE = 0.45, 18, 25
local last = 0

tool.Activated:Connect(function()
	if os.clock() - last < COOLDOWN then return end
	last = os.clock()
	local char = tool.Parent
	local player = Players:GetPlayerFromCharacter(char)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not player or not hrp then return end
	-- Hieb-Animation des Standard-Animate-Skripts
	local anim = Instance.new("StringValue"); anim.Name = "toolanim"; anim.Value = "Slash"; anim.Parent = tool
	game:GetService("Debris"):AddItem(anim, 1)
	api:Invoke(player, hrp.Position + hrp.CFrame.LookVector * 6, REACH, DAMAGE)
end)
