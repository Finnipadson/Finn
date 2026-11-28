-- Bubble Safari: Animationen der Laeden (nur Optik, laeuft auf dem Client).
-- Seifenladen: Seifenstueck am Pfosten dreht sich, Pumpe auf der Flasche drueckt alle paar Sekunden
-- und pustet dabei einen Schwall Seifenblasen aus der Duese.
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("Map", 30)
local hub = map and map:WaitForChild("Hub", 30)
local laden = hub and hub:WaitForChild("Seifenladen", 30)
if not laden then return end
local seife = laden:FindFirstChild("Laden_Seife")
local pumpe = laden:FindFirstChild("Laden_Pumpe")
if not (seife and pumpe) then return end

local seifeBasis = seife.CFrame
local pumpeBasis = pumpe.CFrame
local duese = pumpe:FindFirstChild("Duese")
local blasen = duese and duese:FindFirstChild("Blasen")

local PERIODE = 3.2 -- Sekunden je Pumpstoss
local letzterStoss = 0
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	-- Seife: dreht sich langsam und wippt leicht
	seife.CFrame = seifeBasis * CFrame.new(0, math.sin(t * 2) * 0.15, 0) * CFrame.Angles(0, t * 1.6, 0)
	-- Pumpe: kurzer Druck nach unten, dann langsam wieder hoch
	local p = (t % PERIODE) / PERIODE
	local tief = if p < 0.12 then p / 0.12 elseif p < 0.4 then 1 - (p - 0.12) / 0.28 else 0
	tief = tief * tief * (3 - 2 * tief)
	pumpe.CFrame = pumpeBasis * CFrame.new(0, -0.9 * tief, 0)
	local stoss = math.floor(t / PERIODE)
	if stoss ~= letzterStoss and p >= 0.1 then
		letzterStoss = stoss
		if blasen then blasen:Emit(math.random(6, 10)) end
	end
end)
