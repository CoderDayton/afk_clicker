local MainHUD = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainHUD")
local uiScale = MainHUD:FindFirstChildOfClass("UIScale")

if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = MainHUD
end

local function updateScaleAndPosition()
	local screenSize = workspace.CurrentCamera.ViewportSize
	local baseWidth = 1920 -- your design width
	local scaleFactor = screenSize.X / baseWidth
	scaleFactor = math.clamp(scaleFactor, 0.5, 1)
	uiScale.Scale = scaleFactor
end

-- Initial adjust
updateScaleAndPosition()

MainHUD.Enabled = true

-- Update on viewport size change
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScaleAndPosition)
