local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local MainHUD = game.Players.LocalPlayer.PlayerGui:WaitForChild("MainHUD"):WaitForChild("MainPanel")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local _SoundHandler
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local UIUtils = RR.get(game.ReplicatedStorage.Utils.UIUtils)

-- Request/response channels
local ShardSpendRequest = RemoteSignal.new("ShardSpendRequest")
local ShardSpendResult = RemoteSignal.new("ShardSpendResult")
local ShardBonusRequest = RemoteSignal.new("ShardBonusRequest")
local ShardBonusResult = RemoteSignal.new("ShardBonusResult")
local ShardMinigameRequest = RemoteSignal.new("ShardMinigameRequest")
local ShardMinigameResult = RemoteSignal.new("ShardMinigameResult")
local ShardUpdateSignal = RemoteSignal.new("ShardUpdate") -- Live sync
local PlaySoundRemote = RemoteSignal.new("PlaySoundRemote")

-- ========== Local Variables ==========
local currentShardBalance = 0 -- The 'real' balance from server
local displayedShards = 0 -- What the player sees on screen, for interpolation
local interpolationConnection = nil -- To hold the RenderStepped connection

-- ====== Request Functions ======

function RequestSpend(amount)
	ShardSpendRequest:Fire(amount)
end

function ClaimBonus(action)
	ShardBonusRequest:Fire(action)
end

function ClaimMinigameReward()
	ShardMinigameRequest:Fire()
end

-- ====== Response Handlers ======

ShardSpendResult:Connect(function(success, newBalance, err)
	if success then
		updateShards(newBalance, true) -- true indicates an immediate update is needed
	else
		warn("[SPEND] Failed:", err or "Unknown error")
	end
end)

ShardBonusResult:Connect(function(success, newBalance, message, gained)
	if success and gained and gained > 0 then
		showClickPopup(gained)
	end
end)

ShardMinigameResult:Connect(function(success, newBalance)
	if success then
		print("[MINIGAME] Reward received! New shards:", newBalance)
	else
		warn("[MINIGAME] Failed to award minigame reward.")
	end
end)

-- ====== Other Handlers ======

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if
		(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
		and not gameProcessed
	then
		ClaimBonus("Click")
	end
end)

MainHUD.MainClickButton.MouseButton1Click:Connect(function()
	ClaimBonus("Click")
end)

PlaySoundRemote:Connect(function(name, overrideVolume, overridePlaybackSpeed)
    if not _SoundHandler then
        _SoundHandler = RR.get(game.ReplicatedStorage.Utils.SoundHandler)
    end
	_SoundHandler.PlaySound(name, overrideVolume, overridePlaybackSpeed)
end)

-- ====== UI Update Function ======

-- Palette (edit to match your UI theme) -----------------------------
local BASE_COLOR = Color3.fromRGB(255, 255, 255)
local PULSE_COLOR = Color3.fromRGB(185, 245, 255)
local PULSE_SCALE_MAX = 1.08

-- Cached tweeninfo objects for reuse -------------------------------
local TI_SCALE = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TI_COLOR = TweenInfo.new(0.18, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

----------------------------------------------------------------------
-- updateShards
----------------------------------------------------------------------
function updateShards(newShardCount: number, isPurchase: boolean)
	local wasShardLoss = newShardCount < currentShardBalance
	currentShardBalance = newShardCount or 0

	-- Only pulse if the player GAINED a significant amount of shards
	local didGainSignificantly = (newShardCount - displayedShards) > 10 and not wasShardLoss
	if didGainSignificantly then
		pulseShardCounter()
	end

	-- If this is a purchase (a spend), snap the UI immediately. No interpolation needed.
	if isPurchase then
		if interpolationConnection then
			interpolationConnection:Disconnect()
			interpolationConnection = nil
		end
		displayedShards = currentShardBalance
		local label = MainHUD.Left.Shards.ShardAmount
		label.Text = UIUtils.FormatShardCount(displayedShards)
		return
	end

	-- If interpolation is not already running, start it
	if not interpolationConnection then
		interpolationConnection = RunService.RenderStepped:Connect(function(dt)
			local diff = currentShardBalance - displayedShards

			-- If we are close enough, just snap to the target and stop.
			if math.abs(diff) < 1 then
				displayedShards = currentShardBalance
				if interpolationConnection then
					interpolationConnection:Disconnect()
					interpolationConnection = nil
				end
			else
				-- Move towards the target by a fraction of the difference each frame.
				-- The '5 * dt' makes it so it takes roughly 1/5th of a second to catch up.
				displayedShards += diff * math.min(5 * dt, 1)
			end

			-- Update the UI with the interpolated value
			local label = MainHUD.Left.Shards.ShardAmount
			if label then
				label.Text = UIUtils.FormatShardCount(math.floor(displayedShards))
			end
		end)
	end
end

function pulseShardCounter()
	local label = MainHUD.Left.Shards.ShardAmount
	local uiScale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = label

	-- Color and Scale tweens for the pulse effect
	local colorUp = TweenService:Create(label, TI_COLOR, { TextColor3 = PULSE_COLOR })
	local colorDown = TweenService:Create(label, TI_COLOR, { TextColor3 = BASE_COLOR })
	local scaleUp = TweenService:Create(uiScale, TI_SCALE, { Scale = PULSE_SCALE_MAX })
	local scaleDown = TweenService:Create(uiScale, TI_SCALE, { Scale = 1 })

	colorUp.Completed:Connect(function()
		colorDown:Play()
	end)
	scaleUp.Completed:Connect(function()
		scaleDown:Play()
	end)

	colorUp:Play()
	scaleUp:Play()
end

function showClickPopup(amount)
	local popup = Instance.new("Frame")
	popup.BackgroundTransparency = 1
	popup.Size = UDim2.fromOffset(150, 44)

	local minPadX, minPadY = 140, 100
	local maxPadX, maxPadY = 140, 200
	local x = math.random(minPadX, MainHUD.AbsoluteSize.X - maxPadX)
	local y = math.random(minPadY, MainHUD.AbsoluteSize.Y - maxPadY)
	popup.Position = UDim2.fromOffset(x, y)
	popup.Parent = MainHUD

	local shardIcon = Instance.new("ImageLabel")
	shardIcon.BackgroundTransparency = 1
	shardIcon.Size = UDim2.fromOffset(40, 40)
	shardIcon.ScaleType = Enum.ScaleType.Fit
	shardIcon.Position = UDim2.fromOffset(0, 4)
	shardIcon.Image = "rbxassetid://138071024126324"
	shardIcon.Parent = popup

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(20, 0)
	text.Size = UDim2.fromOffset(108, 44)
	text.Text = "+" .. UIUtils.FormatShardCount(amount)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 42
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0.2
	text.Parent = popup

	local UIStroke = Instance.new("UIStroke")
	UIStroke.Parent = text
	UIStroke.Color = Color3.fromRGB(0, 0, 0)
	UIStroke.Thickness = 5
	UIStroke.Transparency = 0.2

	TweenService:Create(
		popup,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad),
		{ Position = popup.Position - UDim2.fromOffset(0, 40), BackgroundTransparency = 1 }
	):Play()
	TweenService
		:Create(text, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { TextTransparency = 1, TextStrokeTransparency = 1 })
		:Play()
	TweenService:Create(shardIcon, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { ImageTransparency = 1 }):Play()
	TweenService:Create(UIStroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	task.wait(1.2)
	popup:Destroy()
end

-- ====== Live Balance Sync ======
ShardUpdateSignal:Connect(function(newBalance)
	if displayedShards == 0 and newBalance > 0 then
		-- On first load, snap to the value immediately
		displayedShards = newBalance
	end
	currentShardBalance = newBalance or currentShardBalance
	updateShards(currentShardBalance, false)
end)

return {
	currentShardBalance = function()
		return currentShardBalance
	end,
}
