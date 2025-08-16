
local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local PodiumConfig = RR.get(game.ReplicatedStorage.Podiums.PodiumConfig)

-- for _, podium in ipairs(workspace.Courtyard.Podiums:GetChildren()) do
-- 	if not PodiumConfig[podium.Name] then
-- 		warn("Missing config for podium: " .. podium.Name)
-- 	end
-- end

for name, _ in pairs(PodiumConfig) do
	if not workspace.Courtyard.Podiums:FindFirstChild(name) then
		warn("Config for podium exists but not found in Workspace: " .. name)
	end
end
