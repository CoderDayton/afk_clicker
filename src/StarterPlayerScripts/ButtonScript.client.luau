--[[
    ButtonScript.luau
    Handles button animations and click sounds for UI buttons.
    Provides hover, press, and release animations with sound effects.
    Requires RemoteSignal for sound playback.
]]--

local TweenService = game:GetService("TweenService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)

local SetupButtonsLocal = RemoteSignal.new("SetupButtonsLocal")


local function setupButtonAnimation(btn)
	local scale = btn:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
	scale.Parent = btn
	scale.Scale = 1
	local hoverTween, pressTween

	btn.MouseEnter:Connect(function()
		if hoverTween then hoverTween:Cancel() end
		hoverTween = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.05})
		hoverTween:Play()
	end)

	btn.MouseLeave:Connect(function()
		if hoverTween then hoverTween:Cancel() end
		hoverTween = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
		hoverTween:Play()
	end)

	btn.MouseButton1Down:Connect(function()
		if pressTween then pressTween:Cancel() end
		pressTween = TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.93})
		pressTween:Play()
	end)

	btn.MouseButton1Up:Connect(function()
		if pressTween then pressTween:Cancel() end
		-- On release, return to hover (1.05) if still hovering, else 1
		local mouse = game:GetService("Players").LocalPlayer:GetMouse()
		local abs = btn.AbsolutePosition
		local sz = btn.AbsoluteSize
		local inside = mouse.X >= abs.X and mouse.X <= abs.X+sz.X and mouse.Y >= abs.Y and mouse.Y <= abs.Y+sz.Y
		local target = inside and 1.05 or 1
		pressTween = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = target})
		pressTween:Play()
	end)
end

local function setupButtons(parent)
	for _, btn in ipairs(parent:GetDescendants()) do
		if btn:IsA("TextButton") or btn:IsA("ImageButton") then
			setupButtonAnimation(btn)
		end
	end
end

SetupButtonsLocal:LocalConnect(function(parent)
    if parent and parent:IsA("Instance") then
        setupButtons(parent)
    else
        warn("Invalid parent provided to SetupButtonsLocal")
    end
end)