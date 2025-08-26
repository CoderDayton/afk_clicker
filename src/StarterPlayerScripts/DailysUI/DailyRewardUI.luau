--[[
    DailyRewardUI.luau
    Glassmorphism UI components for the Daily Reward system.
    Integrates with DailyRewardClient for state management and interactions.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

-- Utilities
local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local StyleGuide = RR.get("ReplicatedStorage.StyleGuide")
local UIUtils = RR.get("ReplicatedStorage.Utils.UIUtils")
local SoftShadow = RR.get("ReplicatedStorage.Utils.SoftShadow")
local GradientUtil = RR.get("ReplicatedStorage.Utils.GradientUtil")
local Maid = RR.get("ReplicatedStorage.Utils.Maid")
local DailyRewardClient = RR.get(script.Parent.DailyRewardClient)
local DailyRewardAnimations = RR.get(script.Parent.DailyRewardAnimations)

-- ========= CONSTANTS =========
local SLATE_GRAY = Color3.fromRGB(71, 85, 105)
local GLASS_TRANSPARENCY = 0.25
local BLUR_TEXTURE = "rbxassetid://11999950713" -- Default blur texture

-- ========= MAIN SCREEN GUI =========
local DailyRewardUI = {}
DailyRewardUI.__index = DailyRewardUI

function DailyRewardUI.new()
	local self = setmetatable({}, DailyRewardUI)

	-- Initialize DailyRewardClient
	self._client = DailyRewardClient.new()
	self._maid = Maid.new()
	self._isVisible = false

	-- Create the main ScreenGui
	self:_createScreenGui()

	return self
end

function DailyRewardUI:_createScreenGui()
	-- Main ScreenGui
	self._screenGui = Instance.new("ScreenGui")
	self._screenGui.Name = "DailyRewardGui"
	self._screenGui.ResetOnSpawn = false
	self._screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self._screenGui.DisplayOrder = 10
	self._screenGui.Enabled = false

	-- UIScale for responsive design
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = self._screenGui

	-- Main container frame with glassmorphism
	self:_createMainContainer()

	-- Add to player's GUI
	self._screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function DailyRewardUI:_createMainContainer()
	-- Main container frame
	self._mainFrame = Instance.new("Frame")
	self._mainFrame.Name = "MainContainer"
	self._mainFrame.Size = UDim2.fromScale(0.8, 0.7)
	self._mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	self._mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self._mainFrame.BackgroundColor3 = SLATE_GRAY
	self._mainFrame.BackgroundTransparency = GLASS_TRANSPARENCY
	self._mainFrame.BorderSizePixel = 0
	self._mainFrame.ZIndex = 1

	-- Enhanced glassmorphism with dynamic blur
	local blurLayer = Instance.new("ImageLabel")
	blurLayer.Name = "BlurLayer"
	blurLayer.Size = UDim2.fromScale(1, 1)
	blurLayer.Position = UDim2.fromScale(0, 0)
	blurLayer.BackgroundTransparency = 1
	blurLayer.Image = "rbxassetid://11999950713" -- High-quality blur texture
	blurLayer.ImageColor3 = SLATE_GRAY
	blurLayer.ImageTransparency = 0.6
	blurLayer.ScaleType = Enum.ScaleType.Slice
	blurLayer.SliceScale = 0.01
	blurLayer.ZIndex = 2
	blurLayer.Parent = self._mainFrame

	-- Multi-layer gradient for premium glass effect
	local gradientOverlay = Instance.new("UIGradient")
	gradientOverlay.Name = "GlassGradient"
	gradientOverlay.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SLATE_GRAY:Lerp(Color3.new(1, 1, 1), 0.1)),
		ColorSequenceKeypoint.new(0.5, SLATE_GRAY),
		ColorSequenceKeypoint.new(1, SLATE_GRAY:Lerp(Color3.new(0, 0, 0), 0.2)),
	})
	gradientOverlay.Rotation = 90
	gradientOverlay.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	gradientOverlay.Parent = self._mainFrame

	-- Edge glow effect
	local edgeGlow = Instance.new("Frame")
	edgeGlow.Name = "EdgeGlow"
	edgeGlow.Size = UDim2.fromScale(1, 1)
	edgeGlow.Position = UDim2.fromScale(0, 0)
	edgeGlow.BackgroundTransparency = 1
	edgeGlow.BorderSizePixel = 0
	edgeGlow.ZIndex = 3

	local edgeGradient = Instance.new("UIGradient")
	edgeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 150, 255)),
	})
	edgeGradient.Transparency = NumberSequence.new(0.9)
	edgeGradient.Rotation = 0
	edgeGradient.Parent = edgeGlow

	edgeGlow.Parent = self._mainFrame

	-- Animate edge glow with subtle pulse
	task.spawn(function()
		while self._mainFrame and self._mainFrame.Parent do
			local tween = TweenService:Create(edgeGradient, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Rotation = 360
			})
			tween:Play()
			tween.Completed:Wait()
		end
	end)

	-- Soft shadow effect
	SoftShadow.apply(self._mainFrame, {
		SizeScale = 1.2,
		Opacity = 0.3,
		Color = SLATE_GRAY,
		Location = "Outside",
	})

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.L)
	corner.Parent = self._mainFrame

	-- Padding for content
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, StyleGuide.Spacing.Padding.XL)
	padding.PaddingRight = UDim.new(0, StyleGuide.Spacing.Padding.XL)
	padding.PaddingTop = UDim.new(0, StyleGuide.Spacing.Padding.XL)
	padding.PaddingBottom = UDim.new(0, StyleGuide.Spacing.Padding.XL)
	padding.Parent = self._mainFrame

	-- Layout for content organization
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, StyleGuide.Spacing.Gaps.L)
	layout.Parent = self._mainFrame

	-- Create UI components
	self:_createHeader()
	self:_createStreakDisplay()
	self:_createRewardsGrid()
	self:_createClaimButton()
	self:_createCountdownTimer()

	-- Add ambient floating particles
	self:_createAmbientParticles()

	self._mainFrame.Parent = self._screenGui

	-- Setup parallax effect for depth perception
	self:_setupParallaxEffect()
end

function DailyRewardUI:_createHeader()
	-- Header container
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.LayoutOrder = 1
	header.ZIndex = 3

	-- Title text
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "DAILY REWARDS"
	title.TextColor3 = StyleGuide.Colors.TEXT_Primary
	title.TextTransparency = 0
	title.Font = StyleGuide.Typography.Header
	title.TextSize = StyleGuide.Typography.Sizes.XL
	title.TextScaled = false
	title.TextWrapped = true
	title.ZIndex = 4

	-- Subtle glow effect
	local glow = Instance.new("UIGradient")
	glow.Color = StyleGuide.Gradients.CTA.Colors
	glow.Rotation = 0
	glow.Transparency = NumberSequence.new(0.5)
	glow.Parent = title

	title.Parent = header
	header.Parent = self._mainFrame
end

function DailyRewardUI:_createStreakDisplay()
	-- Streak container
	self._streakContainer = Instance.new("Frame")
	self._streakContainer.Name = "StreakContainer"
	self._streakContainer.Size = UDim2.new(1, 0, 0, 80)
	self._streakContainer.BackgroundTransparency = 1
	self._streakContainer.LayoutOrder = 2
	self._streakContainer.ZIndex = 3

	-- Streak label
	local streakLabel = Instance.new("TextLabel")
	streakLabel.Name = "StreakLabel"
	streakLabel.Size = UDim2.new(1, 0, 0.5, 0)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = "CURRENT STREAK"
	streakLabel.TextColor3 = StyleGuide.Colors.TEXT_Secondary
	streakLabel.TextTransparency = 0
	streakLabel.Font = StyleGuide.Typography.Body
	streakLabel.TextSize = StyleGuide.Typography.Sizes.M
	streakLabel.TextScaled = false
	streakLabel.ZIndex = 4
	streakLabel.Parent = self._streakContainer

	-- Streak value
	self._streakValue = Instance.new("TextLabel")
	self._streakValue.Name = "StreakValue"
	self._streakValue.Size = UDim2.new(1, 0, 0.5, 0)
	self._streakValue.Position = UDim2.new(0, 0, 0.5, 0)
	self._streakValue.BackgroundTransparency = 1
	self._streakValue.Text = "0"
	self._streakValue.TextColor3 = StyleGuide.Colors.TEXT_Primary
	self._streakValue.TextTransparency = 0
	self._streakValue.Font = StyleGuide.Typography.Header
	self._streakValue.TextSize = StyleGuide.Typography.Sizes.XXL
	self._streakValue.TextScaled = false
	self._streakValue.ZIndex = 4
	self._streakValue.Parent = self._streakContainer

	self._streakContainer.Parent = self._mainFrame
end

function DailyRewardUI:_createRewardsGrid()
	-- Rewards grid container
	self._rewardsGrid = Instance.new("Frame")
	self._rewardsGrid.Name = "RewardsGrid"
	self._rewardsGrid.Size = UDim2.new(1, 0, 0, 200)
	self._rewardsGrid.BackgroundTransparency = 1
	self._rewardsGrid.LayoutOrder = 3
	self._rewardsGrid.ZIndex = 3

	-- Grid layout
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.18, 0, 1, 0)
	gridLayout.CellPadding = UDim2.new(0, StyleGuide.Spacing.Gaps.M, 0, 0)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.Parent = self._rewardsGrid

	-- Create placeholder reward cards (will be populated dynamically)
	for i = 1, 7 do
		self:_createRewardCard(i)
	end

	self._rewardsGrid.Parent = self._mainFrame
end

function DailyRewardUI:_createRewardCard(dayIndex)
	-- Reward card container
	local card = Instance.new("Frame")
	card.Name = "RewardCard_" .. dayIndex
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = SLATE_GRAY
	card.BackgroundTransparency = 0.3
	card.BorderSizePixel = 0
	card.ZIndex = 4
	card.LayoutOrder = dayIndex

	-- Enhanced card glassmorphism
	local cardBlur = Instance.new("ImageLabel")
	cardBlur.Name = "CardBlur"
	cardBlur.Size = UDim2.fromScale(1, 1)
	cardBlur.BackgroundTransparency = 1
	cardBlur.Image = "rbxassetid://11999950713"
	cardBlur.ImageColor3 = SLATE_GRAY
	cardBlur.ImageTransparency = 0.5
	cardBlur.ScaleType = Enum.ScaleType.Slice
	cardBlur.SliceScale = 0.005
	cardBlur.ZIndex = 5
	cardBlur.Parent = card

	-- Card gradient overlay
	local cardGradient = Instance.new("UIGradient")
	cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SLATE_GRAY:Lerp(Color3.new(1, 1, 1), 0.15)),
		ColorSequenceKeypoint.new(1, SLATE_GRAY:Lerp(Color3.new(0, 0, 0), 0.1)),
	})
	cardGradient.Rotation = 90
	cardGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	cardGradient.Parent = card

	-- Subtle ambient pulse animation for cards
	task.spawn(function()
		while card and card.Parent do
			local pulseTween = TweenService:Create(cardBlur, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				ImageTransparency = 0.7
			})
			pulseTween:Play()
			pulseTween.Completed:Wait()
			
			if not card or not card.Parent then break end
			
			pulseTween = TweenService:Create(cardBlur, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				ImageTransparency = 0.5
			})
			pulseTween:Play()
			pulseTween.Completed:Wait()
		end
	end)

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.M)
	corner.Parent = card

	-- Day number
	local dayLabel = Instance.new("TextLabel")
	dayLabel.Name = "DayLabel"
	dayLabel.Size = UDim2.new(1, 0, 0.2, 0)
	dayLabel.BackgroundTransparency = 1
	dayLabel.Text = "DAY " .. dayIndex
	dayLabel.TextColor3 = StyleGuide.Colors.TEXT_Secondary
	dayLabel.TextTransparency = 0
	dayLabel.Font = StyleGuide.Typography.Body
	dayLabel.TextSize = StyleGuide.Typography.Sizes.S
	dayLabel.TextScaled = false
	dayLabel.ZIndex = 6
	dayLabel.Parent = card

	-- Reward icon placeholder
	local icon = Instance.new("Frame")
	icon.Name = "IconPlaceholder"
	icon.Size = UDim2.new(0.6, 0, 0.5, 0)
	icon.Position = UDim2.new(0.2, 0, 0.25, 0)
	icon.BackgroundColor3 = StyleGuide.Colors.ACCENT_Primary
	icon.BackgroundTransparency = 0.5
	icon.BorderSizePixel = 0
	icon.ZIndex = 6

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.S)
	iconCorner.Parent = icon

	icon.Parent = card

	-- Reward amount placeholder
	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "AmountLabel"
	amountLabel.Size = UDim2.new(1, 0, 0.3, 0)
	amountLabel.Position = UDim2.new(0, 0, 0.7, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = "100"
	amountLabel.TextColor3 = StyleGuide.Colors.TEXT_Primary
	amountLabel.TextTransparency = 0
	amountLabel.Font = StyleGuide.Typography.Regular
	amountLabel.TextSize = StyleGuide.Typography.Sizes.M
	amountLabel.TextScaled = false
	amountLabel.ZIndex = 6
	amountLabel.Parent = card

	-- Soft shadow
	SoftShadow.apply(card, {
		SizeScale = 1.1,
		Opacity = 0.2,
		Color = SLATE_GRAY,
		Location = "Outside",
	})

	-- Store reference for later updates
	if not self._rewardCards then
		self._rewardCards = {}
	end
	self._rewardCards[dayIndex] = card

	card.Parent = self._rewardsGrid
end

function DailyRewardUI:_createClaimButton()
	-- Claim button container
	self._claimButton = Instance.new("TextButton")
	self._claimButton.Name = "ClaimButton"
	self._claimButton.Size = UDim2.new(0.6, 0, 0, 56)
	self._claimButton.Position = UDim2.new(0.2, 0, 0, 0)
	self._claimButton.BackgroundColor3 = StyleGuide.Colors.ACCENT_Primary
	self._claimButton.BackgroundTransparency = 0
	self._claimButton.BorderSizePixel = 0
	self._claimButton.LayoutOrder = 4
	self._claimButton.ZIndex = 3
	self._claimButton.Text = "CLAIM REWARD"
	self._claimButton.TextColor3 = StyleGuide.Colors.TEXT_Inverse
	self._claimButton.TextTransparency = 0
	self._claimButton.Font = StyleGuide.Typography.Header
	self._claimButton.TextSize = StyleGuide.Typography.Sizes.L
	self._claimButton.TextScaled = false

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.Pill)
	corner.Parent = self._claimButton

	-- Gradient effect
	GradientUtil.applyCTA(self._claimButton, 1.5)

	-- Soft shadow
	SoftShadow.apply(self._claimButton, {
		SizeScale = 1.3,
		Opacity = 0.4,
		Color = StyleGuide.Glow.CTA,
		Location = "Outside",
	})

	-- Click handler
	self._claimButton.MouseButton1Click:Connect(function()
		self:_onClaimButtonClicked()
	end)

	-- Hover effects
	self:_setupButtonHoverEffects(self._claimButton)

	self._claimButton.Parent = self._mainFrame
end

function DailyRewardUI:_createCountdownTimer()
	-- Countdown container
	self._countdownContainer = Instance.new("Frame")
	self._countdownContainer.Name = "CountdownContainer"
	self._countdownContainer.Size = UDim2.new(1, 0, 0, 40)
	self._countdownContainer.BackgroundTransparency = 1
	self._countdownContainer.LayoutOrder = 5
	self._countdownContainer.ZIndex = 3

	-- Countdown text
	self._countdownText = Instance.new("TextLabel")
	self._countdownText.Name = "CountdownText"
	self._countdownText.Size = UDim2.new(1, 0, 1, 0)
	self._countdownText.BackgroundTransparency = 1
	self._countdownText.Text = "Next reward in: 24:00:00"
	self._countdownText.TextColor3 = StyleGuide.Colors.TEXT_Secondary
	self._countdownText.TextTransparency = 0
	self._countdownText.Font = StyleGuide.Typography.Body
	self._countdownText.TextSize = StyleGuide.Typography.Sizes.M
	self._countdownText.TextScaled = false
	self._countdownText.ZIndex = 4

	self._countdownText.Parent = self._countdownContainer
	self._countdownContainer.Parent = self._mainFrame
end

function DailyRewardUI:_setupButtonHoverEffects(button)
	-- Use the enhanced hover effects from DailyRewardAnimations
	DailyRewardAnimations.animateHoverEffect(button, self._maid)
	DailyRewardAnimations.animatePressEffect(button, self._maid)
end

function DailyRewardUI:_onClaimButtonClicked()
	if self._client then
		self._client:claimReward()
	end
end

function DailyRewardUI:show()
	if self._isVisible then
		return
	end

	self._screenGui.Enabled = true
	self._isVisible = true

	-- Initialize client if not already
	if not self._client._isInitialized then
		self._client:init()
		self._client:start()
	end

	-- Set up event listeners
	self:_setupEventListeners()

	-- Update UI with current state
	self:_updateUI(self._client:getState())
end

function DailyRewardUI:hide()
	if not self._isVisible then
		return
	end

	self._screenGui.Enabled = false
	self._isVisible = false

	-- Clean up event listeners
	self._maid:DoCleaning()
end

function DailyRewardUI:_setupEventListeners()
    -- State changed listener
    self._maid:GiveTask(self._client.StateChanged:Connect(function(state)
        self:_updateUI(state)
    end))

    -- Claim result listener
    self._maid:GiveTask(self._client.ClaimResult:Connect(function(result)
        self:_handleClaimResult(result)
    end))

    -- Error occurred listener
    self._maid:GiveTask(self._client.ErrorOccurred:Connect(function(errorData)
        self:_handleError(errorData)
    end))
end

function DailyRewardUI:_updateUI(state)
	-- Update streak display
	self._streakValue.Text = tostring(state.streak)

	-- Update reward cards based on current day index
	self:_updateRewardCards(state.dayIndex, state.streak)

	-- Update claim button state
	self:_updateClaimButton(state.canClaim, state._isClaiming)

	-- Update countdown timer
	self:_updateCountdownTimer(state.nextClaimTime)
end

function DailyRewardUI:_updateRewardCards(currentDay, streak)
	for dayIndex, card in pairs(self._rewardCards) do
		local isClaimed = dayIndex < currentDay
		local isCurrent = dayIndex == currentDay
		local isFuture = dayIndex > currentDay

		-- Update visual state based on day status
		if isClaimed then
			card.BackgroundTransparency = 0.5
			card:FindFirstChild("CardBlur").ImageTransparency = 0.8
		elseif isCurrent then
			card.BackgroundTransparency = 0.3
			card:FindFirstChild("CardBlur").ImageTransparency = 0.6
			-- Highlight current day
			GradientUtil.applyPulse(card, "CTA", 0.8)
		else
			card.BackgroundTransparency = 0.7
			card:FindFirstChild("CardBlur").ImageTransparency = 0.9
		end
	end
end

function DailyRewardUI:_updateClaimButton(canClaim, isClaiming)
	if isClaiming then
		self._claimButton.Text = "CLAIMING..."
		self._claimButton.BackgroundTransparency = 0.5
		self._claimButton.AutoButtonColor = false
		-- Show loading animation
		if not self._loadingIndicator then
			self._loadingIndicator = DailyRewardAnimations.animateLoadingState(self._claimButton, self._maid)
		end
	elseif canClaim then
		self._claimButton.Text = "CLAIM REWARD"
		self._claimButton.BackgroundTransparency = 0
		self._claimButton.AutoButtonColor = true
		-- Remove loading animation if it exists
		if self._loadingIndicator then
			self._loadingIndicator:Destroy()
			self._loadingIndicator = nil
		end
	else
		self._claimButton.Text = "COME BACK LATER"
		self._claimButton.BackgroundTransparency = 0.7
		self._claimButton.AutoButtonColor = false
		-- Remove loading animation if it exists
		if self._loadingIndicator then
			self._loadingIndicator:Destroy()
			self._loadingIndicator = nil
		end
	end
end

function DailyRewardUI:_updateCountdownTimer(nextClaimTime)
	if nextClaimTime <= 0 then
		self._countdownText.Text = "Reward available!"
		return
	end

	-- Start countdown update loop
	if self._countdownConnection then
		self._countdownConnection:Disconnect()
	end

	self._countdownConnection = RunService.Heartbeat:Connect(function()
		local now = os.time()
		local timeRemaining = math.max(0, nextClaimTime - now)

		if timeRemaining <= 0 then
			self._countdownText.Text = "Reward available!"
			self._countdownConnection:Disconnect()
			self._countdownConnection = nil
			return
		end

		-- Format time as HH:MM:SS
		local hours = math.floor(timeRemaining / 3600)
		local minutes = math.floor((timeRemaining % 3600) / 60)
		local seconds = math.floor(timeRemaining % 60)

		self._countdownText.Text = string.format("Next reward in: %02d:%02d:%02d", hours, minutes, seconds)
	end)
end

function DailyRewardUI:_handleClaimResult(result)
    if result.success then
        -- Show success feedback with enhanced animation
        DailyRewardAnimations.animateSuccessFeedback(self._claimButton, "Reward claimed successfully!", self._maid)
        UIUtils.ShowFeedback(Players.LocalPlayer, "Reward claimed successfully!", {
            Type = "Success",
            Duration = 2,
        })

        -- Play celebration animation
        self:_playClaimAnimation()
    else
        -- Show error feedback with enhanced animation
        DailyRewardAnimations.animateFailureFeedback(self._claimButton, result.message or "Failed to claim reward", self._maid)
        UIUtils.ShowFeedback(Players.LocalPlayer, result.message or "Failed to claim reward", {
            Type = "Error",
            Duration = 2,
        })
    end
end

--[[
    Handles error events from the DailyRewardClient.
    @param errorData: The error data containing severity, message, and context
]]
function DailyRewardUI:_handleError(errorData)
    -- Handle different error severities appropriately
    local severity = errorData.severity or "error"
    local message = errorData.message or "An unknown error occurred"
    local context = errorData.context or {}
    
    -- Log the error for debugging
    warn(string.format("[DailyRewardUI][%s] %s", severity:upper(), message))
    if next(context) ~= nil then
        warn("Error context:", context)
    end

    -- Show appropriate UI feedback based on severity
    if severity == "critical" or severity == "error" then
        -- Show persistent error message with retry option
        self:_showErrorPopup(message, severity, context)
    elseif severity == "warning" then
        -- Show temporary warning message
        UIUtils.ShowFeedback(Players.LocalPlayer, message, {
            Type = "Warning",
            Duration = 3,
        })
    else
        -- Info messages can be logged but don't need UI feedback
        print(string.format("[DailyRewardUI][INFO] %s", message))
    end

    -- Update claim button state if error is related to claiming
    if context and (context.operation == "claim" or context.wasClaiming) then
        self:_updateClaimButton(self._client:getState().canClaim, false)
    end
end

--[[
    Shows an error popup with retry option for critical errors.
    @param message: The error message to display
    @param severity: The error severity level
    @param context: Additional context data
]]
function DailyRewardUI:_showErrorPopup(message, severity, context)
    -- Create or reuse error popup
    if not self._errorPopup then
        self:_createErrorPopup()
    end

    -- Update popup content
    self._errorPopup.Title.Text = string.format("%s ERROR", severity:upper())
    self._errorPopup.Message.Text = message
    
    -- Set appropriate color based on severity
    local color = StyleGuide.Colors.ERROR_Primary
    if severity == "warning" then
        color = StyleGuide.Colors.WARNING_Primary
    elseif severity == "info" then
        color = StyleGuide.Colors.INFO_Primary
    end
    
    self._errorPopup.Container.BackgroundColor3 = color
    self._errorPopup.RetryButton.BackgroundColor3 = color

    -- Show retry button only for recoverable errors
    local isRecoverable = not (context and context.unrecoverable)
    self._errorPopup.RetryButton.Visible = isRecoverable

    -- Show the popup
    self._errorPopup.Visible = true

    -- Animate in
    DailyRewardAnimations.animatePopupIn(self._errorPopup.Container)
end

--[[
    Creates the error popup UI component.
]]
function DailyRewardUI:_createErrorPopup()
    local popup = Instance.new("Frame")
    popup.Name = "ErrorPopup"
    popup.Size = UDim2.fromScale(1, 1)
    popup.Position = UDim2.fromScale(0, 0)
    popup.BackgroundTransparency = 0.5
    popup.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    popup.ZIndex = 100
    popup.Visible = false

    local container = Instance.new("Frame")
    container.Name = "ErrorContainer"
    container.Size = UDim2.fromScale(0.6, 0.4)
    container.Position = UDim2.fromScale(0.5, 0.5)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = StyleGuide.Colors.ERROR_Primary
    container.BackgroundTransparency = 0.1
    container.ZIndex = 101

    -- Glassmorphism effect
    local blur = Instance.new("ImageLabel")
    blur.Name = "ErrorBlur"
    blur.Size = UDim2.fromScale(1, 1)
    blur.BackgroundTransparency = 1
    blur.Image = "rbxassetid://11999950713"
    blur.ImageColor3 = StyleGuide.Colors.ERROR_Primary
    blur.ImageTransparency = 0.6
    blur.ZIndex = 102
    blur.Parent = container

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.L)
    corner.Parent = container

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.fromScale(1, 0.2)
    title.BackgroundTransparency = 1
    title.Text = "ERROR"
    title.TextColor3 = StyleGuide.Colors.TEXT_Inverse
    title.Font = StyleGuide.Typography.Header
    title.TextSize = StyleGuide.Typography.Sizes.XL
    title.ZIndex = 103
    title.Parent = container

    -- Message
    local message = Instance.new("TextLabel")
    message.Name = "Message"
    message.Size = UDim2.fromScale(0.9, 0.5)
    message.Position = UDim2.fromScale(0.05, 0.25)
    message.BackgroundTransparency = 1
    message.Text = "An error occurred"
    message.TextColor3 = StyleGuide.Colors.TEXT_Inverse
    message.Font = StyleGuide.Typography.Body
    message.TextSize = StyleGuide.Typography.Sizes.M
    message.TextWrapped = true
    message.ZIndex = 103
    message.Parent = container

    -- Retry button
    local retryButton = Instance.new("TextButton")
    retryButton.Name = "RetryButton"
    retryButton.Size = UDim2.fromScale(0.4, 0.2)
    retryButton.Position = UDim2.fromScale(0.3, 0.8)
    retryButton.BackgroundColor3 = StyleGuide.Colors.ERROR_Primary
    retryButton.Text = "RETRY"
    retryButton.TextColor3 = StyleGuide.Colors.TEXT_Inverse
    retryButton.Font = StyleGuide.Typography.Body
    retryButton.TextSize = StyleGuide.Typography.Sizes.M
    retryButton.ZIndex = 103

    retryButton.MouseButton1Click:Connect(function()
        self:_onRetryClicked()
        self._errorPopup.Visible = false
    end)

    local retryCorner = Instance.new("UICorner")
    retryCorner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.M)
    retryCorner.Parent = retryButton

    retryButton.Parent = container
    container.Parent = popup
    popup.Parent = self._screenGui

    self._errorPopup = {
        Container = container,
        Title = title,
        Message = message,
        RetryButton = retryButton,
        Visible = false
    }

    -- Add hover effects to retry button
    self:_setupButtonHoverEffects(retryButton)
end

--[[
    Handles retry button click for error recovery.
]]
function DailyRewardUI:_onRetryClicked()
    -- Attempt to recover from error state
    if self._client then
        self._client:recover()
    end
    
    -- Show loading state
    self:_updateClaimButton(false, true)
    
    -- Haptic feedback
    self:_triggerHapticFeedback("Selection")
end

function DailyRewardUI:_playClaimAnimation()
	local currentDay = self._client:getState().dayIndex
	local card = self._rewardCards[currentDay]
	local rewardData = self._client:getState().rewards[currentDay]

	if card then
		DailyRewardAnimations.animateRewardClaim(card, rewardData, self._maid)
	end
end

function DailyRewardUI:_setupParallaxEffect()
	local parallaxContainer = Instance.new("Frame")
	parallaxContainer.Name = "ParallaxContainer"
	parallaxContainer.Size = UDim2.fromScale(1, 1)
	parallaxContainer.Position = UDim2.fromScale(0, 0)
	parallaxContainer.BackgroundTransparency = 1
	parallaxContainer.ZIndex = 0
	parallaxContainer.Parent = self._mainFrame

	-- Create multiple layers for parallax effect
	local layers = {
		{ Depth = 0.2, SizeScale = 1.1, Transparency = 0.9 },
		{ Depth = 0.1, SizeScale = 1.05, Transparency = 0.95 },
		{ Depth = 0.05, SizeScale = 1.02, Transparency = 0.98 }
	}

	for i, layerConfig in ipairs(layers) do
		local layer = Instance.new("Frame")
		layer.Name = "ParallaxLayer_" .. i
		layer.Size = UDim2.fromScale(layerConfig.SizeScale, layerConfig.SizeScale)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.BackgroundTransparency = layerConfig.Transparency
		layer.BorderSizePixel = 0
		layer.ZIndex = -i
		layer.Parent = parallaxContainer

		-- Subtle gradient for depth
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, SLATE_GRAY:Lerp(Color3.new(1, 1, 1), 0.1)),
			ColorSequenceKeypoint.new(1, SLATE_GRAY:Lerp(Color3.new(0, 0, 0), 0.1)),
		})
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new(layerConfig.Transparency)
		gradient.Parent = layer
	end

	-- Mouse movement handler for parallax
	local function onMouseMoved(input)
		if not self._isVisible or not self._mainFrame then return end

		local mousePos = input.Position
		local screenSize = self._screenGui.AbsoluteSize
		local center = screenSize / 2
		local offset = (mousePos - center) / center

		for i, layer in ipairs(parallaxContainer:GetChildren()) do
			if layer:IsA("Frame") and layer.Name:find("ParallaxLayer") then
				local depth = layers[tonumber(layer.Name:match("%d+$"))].Depth
				local moveOffset = offset * depth * 20
				layer.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(moveOffset.X, moveOffset.Y)
			end
		end
	end

	local mouseMoveConnection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			onMouseMoved(input)
		end
	end)

	self._maid:GiveTask(mouseMoveConnection)
	self._maid:GiveTask(parallaxContainer)
end

function DailyRewardUI:_triggerHapticFeedback(intensity)
	-- Check if running on a touch device
	if UserInputService.TouchEnabled then
		local success, result = pcall(function()
			-- Use ContextActionService for haptic feedback
			ContextActionService:CallFunction("HapticService", "SetMotor", Enum.VibrationMotor.Small, intensity == "Selection" and 0.5 or 0.3)
			task.delay(0.1, function()
				ContextActionService:CallFunction("HapticService", "SetMotor", Enum.VibrationMotor.Small, 0)
			end)
		end)
		if not success then
			warn("Haptic feedback not supported on this device")
		end
	end
end

function DailyRewardUI:_createAmbientParticles()
	local quality = DailyRewardAnimations.QualitySettings[DailyRewardAnimations.CurrentQuality]
	if not quality.ParticleEnabled then
		return
	end

	-- Create a particle container
	local particleContainer = Instance.new("Frame")
	particleContainer.Name = "AmbientParticles"
	particleContainer.Size = UDim2.fromScale(1, 1)
	particleContainer.Position = UDim2.fromScale(0, 0)
	particleContainer.BackgroundTransparency = 1
	particleContainer.ZIndex = 0
	particleContainer.Parent = self._mainFrame

	-- Create multiple floating particles
	for i = 1, 5 do
		task.spawn(function()
			local particle = Instance.new("Frame")
			particle.Name = "AmbientParticle"
			particle.Size = UDim2.new(0, 4, 0, 4)
			particle.BackgroundColor3 = Color3.fromRGB(200, 220, 255)
			particle.BackgroundTransparency = 0.7
			particle.BorderSizePixel = 0
			particle.ZIndex = 1

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = particle

			particle.Parent = particleContainer

			-- Random initial position
			local startX = math.random(10, 90) / 100
			local startY = math.random(10, 90) / 100
			particle.Position = UDim2.fromScale(startX, startY)

			-- Animate particle floating
			while particle and particle.Parent do
				local targetX = math.random(10, 90) / 100
				local targetY = math.random(10, 90) / 100
				local duration = math.random(3, 6)

				local tween = TweenService:Create(particle, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = UDim2.fromScale(targetX, targetY),
					BackgroundTransparency = math.random(5, 8) / 10
				})
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end

	self._maid:GiveTask(particleContainer)
end

function DailyRewardUI:destroy()
	self:hide()

	if self._countdownConnection then
		self._countdownConnection:Disconnect()
		self._countdownConnection = nil
	end

	if self._client then
		self._client:cleanup()
		self._client = nil
	end

	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end

	-- Clean up particles
	DailyRewardAnimations.cleanupParticles()

	self._maid:DoCleaning()
end

local dailyRewardUI = DailyRewardUI.new()
dailyRewardUI:show()

return DailyRewardUI
