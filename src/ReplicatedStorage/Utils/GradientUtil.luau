--!strict
-- GradientUtil v3 – overlay-based wrapper around GradientAnimator v2

---------------------------------------------------------------- Services / Deps
local RunService = game:GetService("RunService")

local UtilsFolder = script.Parent
local RR = require(UtilsFolder:WaitForChild("RobustRequire"))
local StyleGuide = RR.get(game.ReplicatedStorage.StyleGuide)
local SoftShadow = RR.get(game.ReplicatedStorage.Utils.SoftShadow)
local GradientAnimator = RR.get(game.ReplicatedStorage.Utils.GradientAnimator)

---------------------------------------------------------------- Defaults
local DEFAULT_FAMILY = "CTA"
local DEFAULT_ANIMATION = "pulse"
local DEFAULT_SPEED = 1.0

---------------------------------------------------------------- Public types
export type GradientConfig = {
	family: string?,
	color: ColorSequence?,
	transparency: NumberSequence?,
	rotation: number?,
	animation: string?,
	speed: number?,
	duration: number?,
	easing: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	loops: number?,
	shadow: boolean?, -- default true
	shadowSize: number?,
	shadowOpacity: number?,
    shadowFamily: string?,
	stroke: boolean?, -- default true
}

export type GradientControls = {
	stop: () -> (),
	play: () -> (),
	setSpeed: (number) -> (),
	update: (GradientConfig) -> (),
	destroy: () -> (),
	playAnimation: (string, GradientConfig?) -> (),
}

---------------------------------------------------------------- Helpers
local _active = setmetatable({}, { __mode = "k" })

local function applyStroke(target: GuiObject, family: string)
	local p = StyleGuide.Stroke.Presets[family] or StyleGuide.Stroke.Presets[DEFAULT_FAMILY]
	for _, child in ipairs(target:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			local s = child:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			s.Thickness, s.Color, s.Transparency = p.Thickness, p.Color, p.Transparency
			s.Parent = child
		end
	end
end

-- Mirrors Size/Position/Visibility of the target onto the overlay
local function bindOverlay(target: GuiObject, overlay: GuiObject): () -> ()
	local conns = {}

	local function sync(prop: string)
		if prop == "Size" or prop == "Position" or prop == "AnchorPoint" then
			overlay.Size = target.Size
			overlay.Position = target.Position
			overlay.AnchorPoint = target.AnchorPoint
		elseif prop == "Visible" then
			overlay.Visible = target.Visible
		elseif prop == "ZIndex" then
			overlay.ZIndex = target.ZIndex + 1
		end
	end
	sync("Size")
	sync("Position")
	sync("AnchorPoint")
	sync("Visible")
	sync("ZIndex")

	table.insert(conns, target.Changed:Connect(sync))
	table.insert(
		conns,
		target.AncestryChanged:Connect(function(_, parent)
			if not parent then
				overlay:Destroy()
			end
		end)
	)

	return function() -- cleanup
		for _, c in ipairs(conns) do
			if c.Connected then
				c:Disconnect()
			end
		end
	end
end

---------------------------------------------------------------- Factory
local GradientUtil = {}

function GradientUtil.apply(target: GuiObject, cfg: GradientConfig?): GradientControls
	assert(target:IsA("GuiObject"), "Target must be a GuiObject")
	cfg = cfg or {}

	--------------------- Determine preset / params
	local family = cfg.family or DEFAULT_FAMILY
	local preset = StyleGuide.Gradients[family] or StyleGuide.Gradients[DEFAULT_FAMILY]
	local colorSeq = cfg.color or preset.Colors
	local transSeq = cfg.transparency or StyleGuide.Gradients.SheenBand
	local rotation = (cfg.rotation ~= nil) and cfg.rotation or preset.Rotation
	local speed = cfg.speed or DEFAULT_SPEED
	local animType = (cfg.animation or DEFAULT_ANIMATION):lower()

	--------------------- Shadow & stroke on the REAL button
	local shadowId: string? = nil
	if cfg.shadow ~= false then
		local sp = StyleGuide.Shadow.SoftShadowPresets[family] or StyleGuide.Shadow.SoftShadowPresets.CTA
        local sc = StyleGuide.Shadow.SoftShadowPresets[cfg.shadowFamily] or StyleGuide.Shadow.SoftShadowPresets.CTA
		shadowId = ("GU_SH_%s_%d"):format(family, tick() * 1000 % 1e6)
		SoftShadow.apply(target, {
			Id = shadowId,
			Location = sp.Location,
			SizeScale = cfg.shadowSize or sp.SizeScale,
			Opacity = cfg.shadowOpacity or sp.Opacity,
			Color = sc.Color,
		})
	end
	if cfg.stroke ~= false then
		applyStroke(target, family)
	end

	--------------------- Build overlay frame (gradient lives here)
	local overlay = Instance.new("Frame")
	overlay.Name = "GradientOverlay"
	overlay.BackgroundTransparency = 0.4
	overlay.Active = false
	overlay.LayoutOrder = target.LayoutOrder
	overlay.Parent = target
    overlay.ZIndex = target.ZIndex + 1

    local corner = Instance.new("UICorner")
    local r = target:FindFirstChildWhichIsA("UICorner") and target:FindFirstChildWhichIsA("UICorner").CornerRadius or UDim.new(0, 0)
	corner.CornerRadius = r
	corner.Parent = overlay

	bindOverlay(target, overlay)

	--------------------- Animator on overlay
	local animator = GradientAnimator.new(overlay, {
		color = colorSeq,
		rotation = rotation,
		speed = speed,
	})
	if transSeq then
		animator._gradient.Transparency = transSeq
	end
	animator:play(animType, {
		duration = cfg.duration,
		easing = cfg.easing,
		direction = cfg.direction,
		loops = cfg.loops,
	})

	--------------------- Controls object
	local controls
	controls = {
		stop = function()
			animator:stop()
		end,
		play = function()
			animator:play(animType)
		end,
		setSpeed = function(s: number)
			animator:setSpeed(s)
		end,
		playAnimation = function(t: string, cfg2: any?)
			animator:play(t, cfg2)
		end,

		update = function(newCfg: GradientConfig)
			controls.destroy()
			controls = GradientUtil.apply(target, newCfg)
			return controls
		end,

		destroy = function()
			animator:destroy()
			overlay:Destroy()
			if shadowId then
				SoftShadow.remove(target, shadowId)
			end
			_active[target] = nil
		end,
	}
	_active[target] = controls
	return controls
end

-- Convenience wrappers remain unchanged
function GradientUtil.applyCTA(t, s)
	return GradientUtil.apply(t, { family = "CTA", animation = "sheen", speed = s })
end
function GradientUtil.applyPulse(t, f, s)
	return GradientUtil.apply(t, { family = f or "CTA", animation = "pulse", speed = s or 0.8 })
end
function GradientUtil.applyRainbow(t, s)
	return GradientUtil.apply(t, { animation = "rainbow", speed = s or 1.0 })
end

---------------------------------------------------------------- Auto-cleanup
RunService.Heartbeat:Connect(function()
	for target, ctrl in pairs(_active) do
		if not target.Parent then
			ctrl.destroy()
		end
	end
end)

return GradientUtil
