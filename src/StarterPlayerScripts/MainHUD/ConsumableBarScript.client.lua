local TweenService = game:GetService("TweenService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local StyleGuide = RR.get(game.ReplicatedStorage.StyleGuide)

local ConsumableUpdateSignal = RemoteSignal.new("ConsumableUpdate")

local MainHUD = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainHUD")
local consumableBar = MainHUD:FindFirstChild("ConsumableBar")

local appearTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local consumableSlots = {}

local function formatTime(secs)
	if secs <= 0 then
		return "0s"
	end
	local mins = math.floor(secs / 60)
	local s = math.floor(secs % 60)
	return mins > 0 and string.format("%d:%02d", mins, s) or string.format("%ds", s)
end

local function animateAppear(slot: Frame, delayIndex: number?)
	local scale = slot:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.8
	end
	slot.BackgroundTransparency = 1

	local delayTime = (delayIndex or 0) * 0.05
	task.delay(delayTime, function()
		TweenService:Create(slot, appearTweenInfo, { BackgroundTransparency = 0 }):Play()
		if scale then
			TweenService:Create(scale, appearTweenInfo, { Scale = 1.2 }):Play()
		end
	end)
end

local function createSlot(name: string, iconId: string, delayIndex: number?): Frame
	local slot = Instance.new("Frame")
	slot.Name = name
	slot.Size = UDim2.fromOffset(60, 64)
	slot.BackgroundTransparency = 0
	slot.BackgroundColor3 = StyleGuide.Colors.SURFACE_Elevation1
	slot.ZIndex = 20
	slot.Parent = consumableBar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, StyleGuide.Spacing.Radius.M)
	corner.Parent = slot

	local UIScale = Instance.new("UIScale")
	UIScale.Scale = 1.2
	UIScale.Parent = slot

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Image = iconId
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(38, 38)
	icon.Position = UDim2.fromOffset(11, 6)
	icon.ZIndex = 22
	icon.Parent = slot

	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.Text = "..."
	timer.FontFace = StyleGuide.Typography.Body
	timer.TextColor3 = StyleGuide.Glow.CTA
	timer.BackgroundTransparency = 1
	timer.TextSize = 20
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.fromScale(0.5, 1) + UDim2.fromOffset(0, -24)
	timer.Size = UDim2.fromScale(1, 0) + UDim2.fromOffset(-6, 20)
	timer.TextStrokeColor3 = Color3.new(0, 0, 0)
	timer.TextStrokeTransparency = 0.42
	timer.ZIndex = 28
	timer.Parent = slot

	local shadow = timer:Clone()
	shadow.Name = "Shadow"
	shadow.TextColor3 = StyleGuide.Colors.TEXT_Inverse
	shadow.TextStrokeTransparency = 1
	shadow.Position = timer.Position + UDim2.fromOffset(1, 2)
	shadow.ZIndex = timer.ZIndex - 1
	shadow.Parent = slot

	timer:GetPropertyChangedSignal("Text"):Connect(function()
		shadow.Text = timer.Text
	end)

	animateAppear(slot, delayIndex)
	return slot
end

local function AddOrUpdateConsumableSlot(name: string, iconId: string, endsAt: number, delayIndex: number?)
	local slotData = consumableSlots[name]
	if not slotData then
		local slot = createSlot(name, iconId, delayIndex)
		consumableSlots[name] = { Instance = slot, EndsAt = endsAt, Icon = iconId }
	else
		slotData.EndsAt = endsAt
		slotData.Icon = iconId
		local icon = slotData.Instance:FindFirstChild("Icon")
		if icon then
			icon.Image = iconId
		end
	end
end

task.spawn(function()
	while true do
		local now = os.time()
		for name, data in pairs(consumableSlots) do
			local slot = data.Instance
			local timer = slot:FindFirstChild("Timer")
			local timeLeft = math.max(0, data.EndsAt - now)
			if timer then
				timer.Text = formatTime(timeLeft)
			end
			if timeLeft <= 0 then
				slot:Destroy()
				consumableSlots[name] = nil
			end
		end
		task.wait(0.5)
	end
end)

ConsumableUpdateSignal:Connect(function(list)
	local keep = {}
	for _, item in ipairs(list) do
		keep[item.Name] = true
	end
	for name, data in pairs(consumableSlots) do
		if not keep[name] then
			data.Instance:Destroy()
			consumableSlots[name] = nil
		end
	end

	for i, item in ipairs(list) do
		AddOrUpdateConsumableSlot(item.Name, item.Icon, item.EndsAt, i - 1)
	end
end)
