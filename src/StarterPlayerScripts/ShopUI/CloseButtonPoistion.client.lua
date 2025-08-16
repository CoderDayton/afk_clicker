-- LocalScript inside CloseButton
local ShopUI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local closeButton = ShopUI:FindFirstChild("CloseButton")
local parentContainer = closeButton.Parent -- shared parent with MainPanel (e.g., ShopUI)
local mainPanel = parentContainer:FindFirstChild("MainPanel")

-- Center the button on the corner points
closeButton.AnchorPoint = Vector2.new(0.5, 0.5)

-- optional nudge if you ever want to offset away from the exact corner (pixels)
local PAD_X = 0
local PAD_Y = 52

local function parentTopLeft(inst: Instance): Vector2
	if inst and inst:IsA("GuiObject") then
		return inst.AbsolutePosition
	end
	-- ScreenGui or nil -> screen origin
	return Vector2.new(0, 0)
end

local function snapToTopRightCorner()
	if not mainPanel or not mainPanel.Parent then
		return
	end

	-- Panel's top-right in screen pixels
	local panelTL = mainPanel.AbsolutePosition
	local panelSize = mainPanel.AbsoluteSize
	local corner = Vector2.new(panelTL.X + panelSize.X, panelTL.Y)

	-- Convert to offsets in CloseButton's parent space
	local parentTL = parentTopLeft(parentContainer)
	local offsetX = (corner.X - parentTL.X) + PAD_X
	local offsetY = (corner.Y - parentTL.Y) + PAD_Y

	-- AnchorPoint 0.5,0.5 -> the Position is the button's center; it will sit exactly on the corner
	closeButton.Position = UDim2.fromOffset(offsetX, offsetY)
end

-- Initial placement
snapToTopRightCorner()

-- Resnap on any relevant layout changes
mainPanel:GetPropertyChangedSignal("AbsolutePosition"):Connect(snapToTopRightCorner)
mainPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(snapToTopRightCorner)
mainPanel:GetPropertyChangedSignal("Position"):Connect(snapToTopRightCorner)
mainPanel:GetPropertyChangedSignal("Size"):Connect(snapToTopRightCorner)
mainPanel:GetPropertyChangedSignal("AnchorPoint"):Connect(snapToTopRightCorner)

-- If parent is a GuiObject (Frame), it can move/resize too
if parentContainer:IsA("GuiObject") then
	parentContainer:GetPropertyChangedSignal("AbsolutePosition"):Connect(snapToTopRightCorner)
	parentContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(snapToTopRightCorner)
end

-- Also handle viewport changes for ScreenGui parents
local cam = workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(snapToTopRightCorner)
end
