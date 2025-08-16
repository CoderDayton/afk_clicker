local Players = game:GetService("Players")
local MarketplaceSvc = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local AFKPointConfig = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointConfig)
local AFKPointUtils = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointUtils)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)

-- remotes
local AutoClickerToggle = RemoteSignal.new("AutoClickerToggle")
local ShardBonusSignal = RemoteSignal.new("ShardBonusRequest")

local MainHUD = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainHUD")
local autoBtn = MainHUD.MainPanel.Right.AutoClickerButton
local btnText = autoBtn:FindFirstChildWhichIsA("TextLabel")
local btnRect = autoBtn:FindFirstChild("Rect")
local uiGradient = btnRect:FindFirstChild("UIGradient")
local uiStroke = btnRect:FindFirstChild("UIStroke")

local colorSeq = {
	Disabled = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#7b112b")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#f31818")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#7b112b")),
	}),
	Enabled = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#127017")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#20c929")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#127017")),
	}),
}
local strokeCol = { Disabled = Color3.fromRGB(63, 18, 18), Enabled = Color3.fromRGB(16, 52, 18) }

local autoEnabled = false
local clickTimer = 0
local minInterval = math.huge -- cache interval

local function recalcRate()
	local rate = AFKPointConfig.Gamepasses["Auto Clicker"].Features.ClickRate or 0
	if AFKPointUtils.CheckGamepass(LocalPlayer, "VIP") then
		rate = rate * (AFKPointConfig.Gamepasses["VIP"].Features.AutoClickerMultiplier or 1)
	end
	minInterval = rate > 0 and (1 / rate) or math.huge
end

local function updateUI()
	btnText.Text = autoEnabled and "Auto Clicker: ON" or "Auto Clicker: OFF"
	uiGradient.Color = autoEnabled and colorSeq.Enabled or colorSeq.Disabled
	uiStroke.Color = autoEnabled and strokeCol.Enabled or strokeCol.Disabled
end

AutoClickerToggle:LocalConnect(function()
	if not AFKPointUtils.CheckGamepass(LocalPlayer, "Auto Clicker") then
		MarketplaceSvc:PromptGamePassPurchase(LocalPlayer, AFKPointConfig.Gamepasses["Auto Clicker"].GamepassId)
		return
	end
	autoEnabled = not autoEnabled
	if autoEnabled then
		recalcRate()
	end
	updateUI()
end)

RunService.Heartbeat:Connect(function(dt)
	if not autoEnabled then
		return
	end

	clickTimer = clickTimer + dt

	while clickTimer >= minInterval do
		clickTimer = clickTimer - minInterval
		ShardBonusSignal:Fire("Click")
	end
end)

MarketplaceSvc.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
	if player == LocalPlayer and gamePassId == AFKPointConfig.Gamepasses["Auto Clicker"].GamepassId and purchased then
		autoEnabled = true
		recalcRate()
		updateUI()
	end
end)
