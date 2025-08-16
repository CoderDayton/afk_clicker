local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local _SoundHandler
local UIController = RR.get(game.ReplicatedStorage.UIController)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local ShopUIPopulator = RR.get(game.ReplicatedStorage.AFKSystem.ShopUIPopulator)
local SoftShadow = RR.get(game.ReplicatedStorage.Utils.SoftShadow)
local StyleGuide = RR.get(game.ReplicatedStorage.StyleGuide)
local UIAnimator = RR.get(game.ReplicatedStorage.UIAnimator)

local ShopUI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local MainPanel: GuiObject = ShopUI:FindFirstChild("MainPanel")

local SetupButtonsLocal = RemoteSignal.new("SetupButtonsLocal")

-- Shadow management ----------------------------------------------------------
local hasShadows = false
local DROP_ID = "Drop"
local GLOW_ID = "BottomGlow"

local function getOutsideShadow(): ImageLabel?
	-- Expect a sibling named "SoftShadow_<id>"
	return MainPanel.Parent and MainPanel.Parent:FindFirstChild("SoftShadow_" .. DROP_ID) :: ImageLabel
end

local function getInsideShadow(): ImageLabel?
	return MainPanel:FindFirstChild("SoftShadow_" .. GLOW_ID) :: ImageLabel
end

local function setShadowsVisible(visible: boolean)
	-- Outside
	local drop = getOutsideShadow()
	if drop then
		drop.Visible = visible
	end
	-- Inside
	local glow = getInsideShadow()
	if glow then
		glow.Visible = visible
	end
end

local function ensureShadows()
	if hasShadows then
		return
	end
	hasShadows = true

	-- Outside drop shadow (sibling, behind panel)
	SoftShadow.apply(MainPanel, {
		Id = DROP_ID,
		Location = "Outside",
		Color = Color3.fromRGB(0, 0, 0),
		Opacity = 0.45,
		SizeScale = 1.6,
		ZIndex = MainPanel.ZIndex - 1,
	})

	-- Inside bottom glow (child; respects ClipsDescendants)
	SoftShadow.apply(MainPanel, {
		Id = GLOW_ID,
		Location = "Inside",
		AnchorPoint = Vector2.new(0.5, 0.5), -- centered texture
		Position = UDim2.fromScale(0.5, 1.25), -- extends below; clipped by panel
		Color = StyleGuide.Colors.Glow,
		Opacity = 0.15,
		SizeScale = 1.75,
		ZIndex = MainPanel.ZIndex, -- above panel background
	})
end

local function playSound(name: string, overrideVolume: number?, overridePlaybackSpeed: number?)
	if not _SoundHandler then
		_SoundHandler = RR.get(game.ReplicatedStorage.Utils.SoundHandler)
	end
	_SoundHandler.PlaySound(name, overrideVolume, overridePlaybackSpeed)
end

-- Animation setup ----------------------------------------------------------

-- Store initial MainPanel properties for animation reference
local originalPosition = MainPanel.Position
local originalBackgroundTransparency = MainPanel.BackgroundTransparency

local OPEN_ANIMATION = {
	Duration = 0.35,
	EasingStyle = Enum.EasingStyle.Quint,
	EasingDirection = Enum.EasingDirection.Out,
	ScaleFrom = 0.85,
	FadeFrom = 0.85,
	MoveFrom = UDim2.fromScale(0.5, 1.2),
	TargetPosition = UDim2.fromScale(0.5, 0.5),
	CameraDelta = 10,
	onBeforeOpen = function()
		MainPanel.BackgroundTransparency = 1
		MainPanel.Position = UDim2.fromScale(0.5, 1.2)

		ensureShadows()
		setShadowsVisible(true)
		SetupButtonsLocal:FireLocal(ShopUI)

		playSound("MenuOpen")
	end,
}

local CLOSE_ANIMATION = {
	Duration = 0.25,
	EasingStyle = Enum.EasingStyle.Quint,
	EasingDirection = Enum.EasingDirection.In,
	ScaleTo = 0.85,
	FadeTo = 1,
	TargetPosition = UDim2.fromScale(0.5, 1.2),
	CameraDelta = 10,
	onAfterClose = function()
		setShadowsVisible(false)
		ShopUI.Enabled = false

		MainPanel.BackgroundTransparency = originalBackgroundTransparency
		MainPanel.Position = originalPosition
	end,
	onBeforeClose = function()

		playSound("MenuClose")
	end,
}

-- ---------------------------------------------------------------------------

-- Close via animation (don�t remove shadows; just hide in onDisable)
local shopBindings = {
	{
		button = "CloseButton",
		silent = true,
		handler = function()
			local mainPanel = ShopUI:FindFirstChild("MainPanel")
			if not mainPanel then
				warn("[ShopUIController] MainPanel not found on disable!")
				return
			end

			UIAnimator.close(mainPanel, CLOSE_ANIMATION)
		end,
	},
}

-- Controller
local shopController = UIController.new(ShopUI, shopBindings, {
	defaultSound = "ButtonSound",
	gamepadEnabled = true,

	onEnable = function()
		local mainPanel = ShopUI:FindFirstChild("MainPanel")
		if not mainPanel then
			warn("[ShopUIController] MainPanel or ContentArea not found!")
			return
		end

		UIAnimator.open(mainPanel, OPEN_ANIMATION)
	end,

	onDisable = function() end,
})

-- Register product buttons dynamically
local function registerProductButtons()
	local contentArea = MainPanel:FindFirstChild("ContentArea")
	if not contentArea then
		return
	end

	-- Gamepasses
	do
		local group = contentArea:FindFirstChild("Gamepasses")
		local content = group and group:FindFirstChild("Content")
		if content then
			shopController:registerProductButtons(content, function(card, _button)
				print("[ShopUI] Purchasing " .. card.Title.Text)
				playSound("ButtonSound")
			end)
		end
	end

	-- Shards
	do
		local group = contentArea:FindFirstChild("Shards")
		local content = group and group:FindFirstChild("Content")
		if content then
			shopController:registerProductButtons(content, function(card, _button)
				print("[ShopUI] Purchasing " .. card.Title.Text)
				playSound("ButtonSound")
			end)
		end
	end

	-- Consumables
	do
		local group = contentArea:FindFirstChild("Consumables")
		local content = group and group:FindFirstChild("Content")
		if content then
			shopController:registerProductButtons(content, function(card, _button)
				print("[ShopUI] Purchasing " .. card.Title.Text)
				playSound("ButtonSound")
			end)
		end
	end

	print("[ShopUIController] Registered " .. tostring(#shopController.buttonsList - 1) .. " product buttons")
end

-- Populate + bind on enable (single source of truth)
ShopUI:GetPropertyChangedSignal("Enabled"):Connect(function()
	if ShopUI.Enabled then
		local ok = ShopUIPopulator.PopulateShopUI()
		if not ok then
			warn("[ShopUIController] Failed to populate shop UI.")
			return
		end
		shopController:initialize()
		registerProductButtons()
	end
end)

-- Optional: initial init if ShopUI starts enabled in Studio
if ShopUI.Enabled then
	local ok = ShopUIPopulator.PopulateShopUI()
	if ok then
		shopController:initialize()
		registerProductButtons()
	end
end

game.Players.PlayerRemoving:Connect(function(player)
	if player == game.Players.LocalPlayer then
		UIAnimator.cleanupAll()
	end
end)

return shopController
