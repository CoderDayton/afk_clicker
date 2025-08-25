local ContextActionService = game:GetService("ContextActionService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local UIController = RR.get(game.ReplicatedStorage.UIController)

local MainHUD = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainHUD")
local AutoClickerToggle = RemoteSignal.new("AutoClickerToggle")
local SetupButtonsLocal = RemoteSignal.new("SetupButtonsLocal")

-- Define bindings for all buttons in the MainHUD
local mainHUDBindings = {
	{
		button = "MainPanel.Left.ShopButton",
		silent = true,
		handler = function()
			local ShopUI = MainHUD.Parent:WaitForChild("ShopUI")
			ShopUI.Enabled = true
		end,
	},
	{
		button = "MainPanel.Left.DailysButton",
		handler = function()
			-- TODO: Implement DailysButton functionality
			print("Clicked DailysButton")
		end,
	},
	{
		button = "MainPanel.Left.InventoryButton",
		handler = function()
			-- TODO: Implement InventoryButton functionality
			print("Clicked InventoryButton")
		end,
	},
	{
		button = "MainPanel.Left.RebirthButton",
		handler = function()
			-- TODO: Implement RebirthButton functionality
			print("Clicked RebirthButton")
		end,
	},
	{
		button = "MainPanel.Left.CodesButton",
		handler = function()
			-- TODO: Implement CodesButton functionality
			print("Clicked CodesButton")
		end,
	},
	{
		button = "MainPanel.Left.VIPButton",
		handler = function()
			-- TODO: Implement VIPButton functionality
			print("Clicked VIPButton")
		end,
	},
	{
		button = "MainPanel.Right.AutoClickerButton",
		handler = function()
			AutoClickerToggle:FireLocal()
		end,
	},
	{
		button = "MainPanel.Right.SettingsButton",
		handler = function()
			-- TODO: Implement SettingsButton functionality
			print("Clicked SettingsButton")
		end,
	},
	{
		button = "MainPanel.MainClickButton",
		handler = function()
			return
		end,
	},
}

-- Create and initialize controller with configuration
local mainController = UIController.new(MainHUD, mainHUDBindings, {
	gamepadEnabled = true,
	defaultSound = "ButtonSound",
	onEnable = function()
		-- Any additional setup when the HUD is enabled
		SetupButtonsLocal:FireLocal(MainHUD)

		MainHUD.Enabled = false
	end,
})

-- Initialize the controller
mainController:initialize()

-- Bind global gamepad shortcuts
ContextActionService:BindAction("ToggleShop", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		-- Find the shop button and simulate pressing it
		for i, button in ipairs(mainController.buttonsList) do
			if button.Name == "ShopButton" then
				mainController:handleButtonPress(button, true)
				break
			end
		end
	end
end, false, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("ToggleAutoClicker", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		-- Find the auto-clicker button
		for i, button in ipairs(mainController.buttonsList) do
			if button.Name == "AutoClickerButton" then
				mainController:handleButtonPress(button, true)
				break
			end
		end
	end
end, false, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.DPadDown)

-- Make controller accessible to other scripts if needed
return mainController
