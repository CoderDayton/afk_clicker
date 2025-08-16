local ShopUI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local blur = game.Lighting:FindFirstChildOfClass("BlurEffect")

-- If a BlurEffect doesn't exist, create one
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Size = 15
	blur.Parent = game.Lighting
end

local function updateBlur()
	blur.Enabled = ShopUI.Enabled
end

-- Initial state
updateBlur()

-- Listen for when Enabled changes
ShopUI:GetPropertyChangedSignal("Enabled"):Connect(updateBlur)