--[[
    SetupTryOnRigs.server.luau
    This script sets up the try-on rigs and their associated accessories.
]]

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local TryOnUtils = RR.get(game.ReplicatedStorage.TryOnUtils)

local config = {
	Rigs = {
		{
			RigName = "Display1",
			AccessoryName = "Accessory (Bloodvein Horns)",
		},
		{
			RigName = "Display2",
			AccessoryName = "Gold Floating Crown",
		},
		{
			RigName = "Display3",
			AccessoryName = "Fedora of the Darkest Night",
		},
	},
}

for _, rigData in ipairs(config.Rigs) do
	local rig = workspace:FindFirstChild(rigData.RigName)
	assert(rig, "Rig not found: " .. rigData.RigName)

	-- Prefer UpperTorso, fallback to Head
	local promptPart = rig:FindFirstChild("UpperTorso") or rig:FindFirstChild("Head")
	assert(promptPart, "No UpperTorso or Head found for " .. rigData.RigName)

	local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
	assert(prompt, "No ProximityPrompt found for " .. rigData.RigName)

	local accessoryTemplate = game.ReplicatedStorage:FindFirstChild(rigData.AccessoryName)
	assert(accessoryTemplate, "Accessory not found: " .. rigData.AccessoryName)
	assert(accessoryTemplate:IsA("Accessory"), "Expected Accessory, got: " .. accessoryTemplate.ClassName)

	-- Clone the accessory template
	local accessoryClone = accessoryTemplate:Clone()
	accessoryClone.Parent = rig

	prompt.Triggered:Connect(function(player)
		TryOnUtils.OnPromptTriggered(player, rigData.RigName, accessoryClone, prompt)
	end)
end
