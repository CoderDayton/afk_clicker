local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local _SoundHandler

local UIController = {}
UIController.__index = UIController

--[[
    Creates a new UI controller for managing a ScreenGui

    @param screenGui - The ScreenGui to control
    @param bindings - Table of button bindings {button = "path.to.button", handler = function}
    @param config - Optional configuration table
    @return UIController instance
]]
function UIController.new(screenGui, bindings, config)
	local self = setmetatable({}, UIController)

	-- Core properties
	self.screenGui = screenGui
	self.bindings = bindings or {}
	self.config = config
		or {
			defaultSound = "ButtonSound",
			scaleTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			selectedScale = 1.1,
			normalScale = 1,
			touchTolerance = 5, -- Pixels
			gamepadEnabled = true,
			playSoundWhenNoButton = false,
		}

	-- State tracking
	self.buttonRegistry = {} -- button instance → handler function
	self.buttonsList = {} -- Ordered list for navigation
	self.selectedIndex = 1
	self.connections = {} -- Store all event connections for cleanup
	self.isActive = false -- Whether input handling is active

	return self
end

-- Scale button for visual feedback
function UIController:setButtonScale(button, isSelected)
	local uiScale = button:FindFirstChild("UIScale") or Instance.new("UIScale")
	uiScale.Parent = button
	local targetScale = isSelected and (self.config.selectedScale or 1.1) or (self.config.normalScale or 1)
	local tweenInfo = self.config.scaleTweenInfo or TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(uiScale, tweenInfo, { Scale = targetScale }):Play()
end

-- Register a single button with handlers
function UIController:registerButton(buttonInfo)
	local button

	-- Get button by path or direct reference
	if typeof(buttonInfo.button) == "string" then
		local parts = string.split(buttonInfo.button, ".")
		if #parts == 1 then
			button = self.screenGui:WaitForChild(parts[1])
		else
			local container = self.screenGui:WaitForChild(parts[1])
			for i = 2, #parts do
				container = container:WaitForChild(parts[i])
			end
			button = container
		end
	else
		button = buttonInfo.button
	end

	if not button or not button:IsA("GuiObject") then
		warn("[UIController] Invalid button: ", buttonInfo.button)
		return
	end

	-- Store in ordered list and registry
	table.insert(self.buttonsList, button)
	self.buttonRegistry[button] = buttonInfo.handler

	-- Mouse click (PC)
	local mouseConn = button.MouseButton1Click:Connect(function()
		if self.config.defaultSound and not buttonInfo.silent then
            if not _SoundHandler then
                _SoundHandler = RR.get(game.ReplicatedStorage.Utils.SoundHandler)
            end
			_SoundHandler.PlaySound(self.config.defaultSound)
		end
		buttonInfo.handler(button)
	end)
	table.insert(self.connections, mouseConn)

	-- Touch handling (Mobile)
	local touchBeganConn = button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:setButtonScale(button, true)
		end
	end)
	table.insert(self.connections, touchBeganConn)

	local touchEndedConn = button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Check if all required values are available
			local tolerance = self.config.touchTolerance or 5
			local touchPos = input.Position

			-- Safe guard against nil values
			if not button or not button:IsA("GuiObject") or not touchPos then
				return
			end

			-- Ensure button has valid position and size before proceeding
			local buttonPos = button.AbsolutePosition
			local buttonSize = button.AbsoluteSize

			if not buttonPos or not buttonSize then
				return
			end

			-- Now perform bounds check safely
			if
				touchPos.X >= buttonPos.X - tolerance
				and touchPos.X <= buttonPos.X + buttonSize.X + tolerance
				and touchPos.Y >= buttonPos.Y - tolerance
				and touchPos.Y <= buttonPos.Y + buttonSize.Y + tolerance
			then
				if self.config.defaultSound and not buttonInfo.silent then
                    if not _SoundHandler then
                        _SoundHandler = RR.get(game.ReplicatedStorage.Utils.SoundHandler)
                    end
					_SoundHandler.PlaySound(self.config.defaultSound)
				end
				buttonInfo.handler(button)
			end

			self:setButtonScale(button, false)
		end
	end)
	table.insert(self.connections, touchEndedConn)

	-- Initialize scale
	self:setButtonScale(button, false)

	return button
end

-- Handle button press from any input source
function UIController:handleButtonPress(button, isGamepad)
	if not self.buttonRegistry[button] then
		return
	end

	-- Play sound if configured
	if self.config.defaultSound and not self.config.playSoundWhenNoButton then
        if not _SoundHandler then
            _SoundHandler = RR.get(game.ReplicatedStorage.Utils.SoundHandler)
        end
		_SoundHandler.PlaySound(self.config.defaultSound)
	end

	-- Call handler
	self.buttonRegistry[button](button)

	-- Update selection if from gamepad
	if isGamepad then
		self:setButtonScale(button, true)
	end
end

function UIController:registerAllButtons()
	-- Clear existing
	self.buttonRegistry = {}
	self.buttonsList = {}

	-- Register from bindings table
	for _, binding in ipairs(self.bindings) do
		self:registerButton(binding)
	end

	return self
end

function UIController:setupGamepadInput()
	if not self.config.gamepadEnabled then
		return
	end

	-- Handle gamepad navigation
	local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.isActive or #self.buttonsList == 0 then
			return
		end

		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.DPadDown then
				self:moveSelection(1)
			elseif input.KeyCode == Enum.KeyCode.DPadUp then
				self:moveSelection(-1)
			elseif input.KeyCode == Enum.KeyCode.ButtonA then
				local selectedButton = self.buttonsList[self.selectedIndex]
				if selectedButton then
					self:handleButtonPress(selectedButton, true)
				end
			end
		end
	end)

	table.insert(self.connections, inputConn)
	return self
end

-- Selection management
function UIController:selectButton(index)
	if index < 1 or index > #self.buttonsList then
		return self
	end

	if self.selectedIndex and self.selectedIndex <= #self.buttonsList then
		self:setButtonScale(self.buttonsList[self.selectedIndex], false)
	end

	self.selectedIndex = index
	self:setButtonScale(self.buttonsList[self.selectedIndex], true)

	return self
end

function UIController:moveSelection(direction)
	local newIndex = (self.selectedIndex + direction - 1) % #self.buttonsList + 1
	return self:selectButton(newIndex)
end

function UIController:enable()
	if self.isActive then
		return self
	end
	self.isActive = true

	-- Setup gamepad input
	self:setupGamepadInput()

	-- Select current button if any
	if #self.buttonsList > 0 and self.selectedIndex <= #self.buttonsList then
		self:selectButton(self.selectedIndex)
	end

	-- Call onEnable callback if provided
	if self.config.onEnable then
		self.config.onEnable(self)
	end

	return self
end

function UIController:disable()
	if not self.isActive then
		return self
	end
	self.isActive = false

	-- Clean up connections except for the enabled property watcher
	local enabledPropertyWatcher = self.connections[1]
	for i = 2, #self.connections do
		self.connections[i]:Disconnect()
		self.connections[i] = nil
	end
	self.connections = { enabledPropertyWatcher }

	-- Call onDisable callback if provided
	if self.config.onDisable then
		self.config.onDisable(self)
	end

	return self
end

function UIController:cleanup()
	-- Full cleanup, including all connections
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.buttonRegistry = {}
	self.buttonsList = {}
	self.isActive = false

	return self
end

function UIController:initialize()
	-- Register all buttons from bindings
	self:registerAllButtons()

	-- Connect screenGui enabled state change
	table.insert(
		self.connections,
		self.screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if self.screenGui.Enabled then
				self:enable()
			else
				self:disable()
			end
		end)
	)

	-- Initial state based on screenGui
	if self.screenGui.Enabled then
		self:enable()
	end

	return self
end

-- Additional utility functions for specific UI types

-- Registers product buttons in shop UI
function UIController:registerProductButtons(contentPath, productHandler)
	if not contentPath then
		warn("[UIController] Missing contentPath in registerProductButtons")
		return self
	end

	local contentArea

	-- Handle different ways to specify the content area
	if typeof(contentPath) == "string" then
		contentArea = self.screenGui:FindFirstChild(contentPath, true)
	else
		contentArea = contentPath
	end

	if not contentArea then
		warn("[UIController] Could not find content area: ", tostring(contentPath))
		return self
	end

	for _, card in ipairs(contentArea:GetChildren()) do
		if card:IsA("Frame") and card:FindFirstChild("PurchaseButton") then
			local purchaseButton = card:FindFirstChild("PurchaseButton")

			self:registerButton({
				button = purchaseButton,
				handler = function()
					if productHandler then
						productHandler(card, purchaseButton)
					else
						print(
							"[UIController] Purchasing " .. (card:FindFirstChild("Title") and card.Title.Text or "item")
						)
					end
				end,
			})
		end
	end

	return self
end

return UIController
