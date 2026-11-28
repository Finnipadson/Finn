-- Bubble Safari: alle Skripte aus den Dateien nach Studio spielen.
-- Voraussetzung: python -m http.server 8765 --bind 127.0.0.1 im Ordner Scripts/, Domain 127.0.0.1:8765 in der MCP-HTTP-Allowlist.
-- Aufruf per execute_luau: return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8765/Bauen/Deploy.lua?t="..os.clock()))()
local H = game:GetService("HttpService")
local BASIS = "http://127.0.0.1:8765/"
local liste = {
	{ "ReplicatedStorage/Daten.lua", "ModuleScript", game.ReplicatedStorage, "Daten" },
	{ "ReplicatedStorage/TierModelle.lua", "ModuleScript", game.ReplicatedStorage, "TierModelle" },
	{ "ServerScriptService/Spieldaten.lua", "ModuleScript", game.ServerScriptService, "Spieldaten" },
	{ "ServerScriptService/Server.server.lua", "Script", game.ServerScriptService, "Server" },
	{ "StarterPlayerScripts/Client.client.lua", "LocalScript", game.StarterPlayer.StarterPlayerScripts, "Client" },
	{ "StarterPlayerScripts/LadenAnimation.client.lua", "LocalScript", game.StarterPlayer.StarterPlayerScripts, "LadenAnimation" },
}
local out = {}
for _, e in liste do
	local ok, src = pcall(H.GetAsync, H, BASIS .. e[1] .. "?t=" .. os.clock())
	if not ok then
		table.insert(out, e[1] .. ": LADEFEHLER " .. tostring(src))
		continue
	end
	local f, err = loadstring(src)
	if not f then
		table.insert(out, e[1] .. ": SYNTAX " .. tostring(err))
		continue
	end
	local s = e[3]:FindFirstChild(e[4])
	if s and s.ClassName ~= e[2] then
		s:Destroy()
		s = nil
	end
	if not s then
		s = Instance.new(e[2])
		s.Name = e[4]
		s.Parent = e[3]
	end
	s.Source = src
	table.insert(out, e[1] .. ": ok")
end
return table.concat(out, "\n")
