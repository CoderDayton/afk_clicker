--[[
    DailyRewardPopup.luau
    Glassmorphism reward popup component for the Daily Reward system.
    Displays claimed rewards with animations and visual feedback.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utilities
local RR = require(ReplicatedStorage.Utils.RobustRequire)
local StyleGuide = RR.get("ReplicatedStorage.StyleGuide")
local SoftShadow = RR.get("ReplicatedStorage.Utils.SoftShadow")
-- local DailyRewardAnimations = RR.get("StarterPlayerScripts.DailysUI.DailyRewardAnimations")

-- Constants
local SLATE_GRAY = Color3.fromRGB(71, 85, 105)
local BLUR_TEXTURE = "rbxassetid://11999950713"

local DailyRewardPopup = {}
DailyRewardPopup.__index = DailyRewardPopup

function DailyRewardPopup.new(parentGui)
	local self = setmetatable({}, DailyRewardPopup)

	self._parentGui = parentGui
	self._isVisible = false

	self:_createPopup()

	return self
end

function DailyRewardPopup:_createPopup()
	-- Reward popup container (initially hidden)
	self._popup = Instance.new("Frame")
	self._popup.Name = "RewardPopup"
	self._popup.Size = UDim2.fromScale(0.6, 0.5)
	self._popup.Position = UDim2.fromScale(0.5, 0.5)
	self._popup.AnchorPoint = Vector2.new(0.5, 0.5)
	self._popup.BackgroundColor3 = SLATE_GRAY
	self._popup.BackgroundTransparency = 0.2
	self._popup.BorderSizePixel = 0
	self._popup.ZIndex = 20
	self._popup.Visible = false

	-- Glassmorphism effect
	local popupBlur = Instance.new("ImageLabel")
	popupBlur.Name = "PopupBlur"
	popupBlur.Size = UDim2.fromScale(1, 1)
	popupBlur.BackgroundTransparency = 1
	popupBlur.Image = BLUR_TEXTURE
	popupBlur.ImageColor3 = SLATE_GRAY
	popupBlur.ImageTransparency = 0.5
	popupBlur.ScaleType = Enum.ScaleType.Slice
	popupBlur.SliceScale = 0.02
	popupBlur.ZIndex = 21
	popupBlur.Parent = self._popup

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.L)
	corner.Parent = self._popup

	-- Soft shadow
	SoftShadow.apply(self._popup, {
		SizeScale = 1.3,
		Opacity = 0.4,
		Color = SLATE_GRAY,
		Location = "Outside",
	})

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "PopupTitle"
	title.Size = UDim2.new(1, 0, 0.2, 0)
	title.BackgroundTransparency = 1
	title.Text = "REWARD CLAIMED!"
	title.TextColor3 = StyleGuide.Colors.TEXT_Primary
	title.TextTransparency = 0
	title.Font = StyleGuide.Typography.Header
	title.TextSize = StyleGuide.Typography.Sizes.XL
	title.TextScaled = false
	title.ZIndex = 22
	title.Parent = self._popup

	-- Reward icon
	self._icon = Instance.new("Frame")
	self._icon.Name = "PopupIcon"
	self._icon.Size = UDim2.new(0.4, 0, 0.4, 0)
	self._icon.Position = UDim2.new(0.3, 0, 0.25, 0)
	self._icon.BackgroundColor3 = StyleGuide.Colors.ACCENT_Primary
	self._icon.BackgroundTransparency = 0.3
	self._icon.BorderSizePixel = 0
	self._icon.ZIndex = 22

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.M)
	iconCorner.Parent = self._icon

	self._icon.Parent = self._popup

	-- Reward amount
	self._amountLabel = Instance.new("TextLabel")
	self._amountLabel.Name = "PopupAmount"
	self._amountLabel.Size = UDim2.fromScale(1, 0.2)
	self._amountLabel.Position = UDim2.new(0, 0, 0.65, 0)
	self._amountLabel.BackgroundTransparency = 1
	self._amountLabel.Text = "+100"
	self._amountLabel.TextColor3 = StyleGuide.Colors.TEXT_Primary
	self._amountLabel.TextTransparency = 0
	self._amountLabel.Font = StyleGuide.Typography.Header
	self._amountLabel.TextSize = StyleGuide.Typography.Sizes.XXL
	self._amountLabel.TextScaled = false
	self._amountLabel.ZIndex = 22
	self._amountLabel.Parent = self._popup

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0.4, 0, 0.15, 0)
	closeButton.Position = UDim2.new(0.3, 0, 0.85, 0)
	closeButton.BackgroundColor3 = StyleGuide.Colors.ACCENT_Primary
	closeButton.BackgroundTransparency = 0
	closeButton.BorderSizePixel = 0
	closeButton.Text = "CLOSE"
	closeButton.TextColor3 = StyleGuide.Colors.TEXT_Inverse
	closeButton.TextTransparency = 0
	closeButton.Font = StyleGuide.Typography.Body
	closeButton.TextSize = StyleGuide.Typography.Sizes.M
	closeButton.TextScaled = false
	closeButton.ZIndex = 22

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.S)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:hide()
		-- Haptic feedback on close
		self:_triggerHapticFeedback("Selection")
	end)

	-- Add hover effects with haptic feedback
	self:_setupButtonHoverEffects(closeButton)

	closeButton.Parent = self._popup

	self._popup.Parent = self._parentGui
end

function DailyRewardPopup:_setupButtonHoverEffects(button)
	local originalSize = button.Size
	local hoverSize = UDim2.new(originalSize.X.Scale * 1.05, 0, originalSize.Y.Scale * 1.05, 0)

	button.MouseEnter:Connect(function()
		local tween = TweenService:Create(button, TweenInfo.new(0.2), {
			Size = hoverSize,
			BackgroundTransparency = 0.1,
		})
		tween:Play()
	end)

	button.MouseLeave:Connect(function()
		local tween = TweenService:Create(button, TweenInfo.new(0.2), {
			Size = originalSize,
			BackgroundTransparency = 0,
		})
		tween:Play()
	end)
end

function DailyRewardPopup:_triggerHapticFeedback(intensity)
	-- Check if running on a touch device
	if UserInputService.TouchEnabled then
		local success, result = pcall(function()
			-- Use ContextActionService for haptic feedback
			ContextActionService:CallFunction(
				"HapticService",
				"SetMotor",
				Enum.VibrationMotor.Small,
				intensity == "Selection" and 0.5 or 0.3
			)
			task.delay(0.1, function()
				ContextActionService:CallFunction("HapticService", "SetMotor", Enum.VibrationMotor.Small, 0)
			end)
		end)
		if not success then
			warn("Haptic feedback not supported on this device")
		end
	end
end

function DailyRewardPopup:show(rewardData)
	-- Update popup content based on reward data
	if rewardData and rewardData.rewards and #rewardData.rewards > 0 then
		local reward = rewardData.rewards[1]
		self._amountLabel.Text = "+" .. tostring(reward.amount or 100)

		-- Set icon color based on reward type
		if reward.type == "coins" then
			self._icon.BackgroundColor3 = StyleGuide.Colors.ACCENT_Primary
		elseif reward.type == "gems" then
			self._icon.BackgroundColor3 = StyleGuide.Colors.ACCENT_Secondary
		end
	end

	-- Show and animate popup
	self._popup.Visible = true
	self._popup.Size = UDim2.fromScale(0.4, 0.3)

	local scaleUp =
		TweenService:Create(self._popup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.6, 0.5),
		})

	scaleUp:Play()

	-- Haptic feedback on show
	self:_triggerHapticFeedback("Selection")
end

function DailyRewardPopup:hide()
	local scaleDown =
		TweenService:Create(self._popup, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.4, 0.3),
		})

	scaleDown:Play()
	scaleDown.Completed:Wait()
	self._popup.Visible = false
end

function DailyRewardPopup:destroy()
	if self._popup then
		self._popup:Destroy()
		self._popup = nil
	end
end

return DailyRewardPopup
