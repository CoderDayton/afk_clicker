--!strict
-- GradientAnimator v2 – full-feature colour / transparency / rotation animation
-- Works under strict mode; supports StyleGuide presets

--------------------------------------------------------------------- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
---------------------------------------------------------------- Style-Guide
local UtilsFolder = script.Parent
local RR = require(UtilsFolder:WaitForChild("RobustRequire"))
local StyleGuide = RR.get(game.ReplicatedStorage.StyleGuide)
---------------------------------------------------------------- Type aliases
export type AnimationConfig = {
	duration: number?, -- total cycle time (sec)
	easing: Enum.EasingStyle?,
	direction: Enum.EasingDirection?, -- for numeric tweens
	loops: number?, -- <=0 or nil = infinite
}

export type AnimationState = {
	isRunning: boolean,
	currentTweens: { Tween },
	connections: { RBXScriptConnection },
	cleanupTasks: { () -> () },
}

---------------------------------------------------------------- util helpers
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Color3 helpers ------------------------------------------------------------
local function lerpColor3(a: Color3, b: Color3, t: number): Color3
	return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end

local function sampleColorSeq(seq: ColorSequence, x: number): Color3
	local ks = seq.Keypoints
	if x <= ks[1].Time then
		return ks[1].Value
	end
	for i = 1, #ks - 1 do
		local k0, k1 = ks[i], ks[i + 1]
		if x >= k0.Time and x <= k1.Time then
			local u = (x - k0.Time) / math.max(1e-6, (k1.Time - k0.Time))
			return lerpColor3(k0.Value, k1.Value, u)
		end
	end
	return ks[#ks].Value
end

local function lerpColorSeq(a: ColorSequence, b: ColorSequence, t: number): ColorSequence
	local times, seen = {}, {}
	for _, k in ipairs(a.Keypoints) do
		seen[k.Time] = true
	end
	for _, k in ipairs(b.Keypoints) do
		seen[k.Time] = true
	end
	for tm in pairs(seen) do
		table.insert(times, tm)
	end
	table.sort(times)

	local keys = {}
	for _, tm in ipairs(times) do
		table.insert(keys, ColorSequenceKeypoint.new(tm, lerpColor3(sampleColorSeq(a, tm), sampleColorSeq(b, tm), t)))
	end
	return ColorSequence.new(keys)
end

-- NumberSequence helpers ----------------------------------------------------
local function sampleNumSeq(seq: NumberSequence, x: number): number
	local ks = seq.Keypoints
	if x <= ks[1].Time then
		return ks[1].Value
	end
	for i = 1, #ks - 1 do
		local k0, k1 = ks[i], ks[i + 1]
		if x >= k0.Time and x <= k1.Time then
			local u = (x - k0.Time) / math.max(1e-6, (k1.Time - k0.Time))
			return lerp(k0.Value, k1.Value, u)
		end
	end
	return ks[#ks].Value
end

local function lerpNumSeq(a: NumberSequence, b: NumberSequence, t: number): NumberSequence
	local times, seen = {}, {}
	for _, k in ipairs(a.Keypoints) do
		seen[k.Time] = true
	end
	for _, k in ipairs(b.Keypoints) do
		seen[k.Time] = true
	end
	for tm in pairs(seen) do
		table.insert(times, tm)
	end
	table.sort(times)

	local keys = {}
	for _, tm in ipairs(times) do
		table.insert(keys, NumberSequenceKeypoint.new(tm, lerp(sampleNumSeq(a, tm), sampleNumSeq(b, tm), t)))
	end
	return NumberSequence.new(keys)
end

------------------------------------------------------------------------
local AnimationStrategies = {}

----------------------------------------------------------------- Sheen
function AnimationStrategies.sheen(g: UIGradient, cfg: AnimationConfig): AnimationState
	local state: AnimationState = { isRunning = true, currentTweens = {}, connections = {}, cleanupTasks = {} }

	g.Color = ColorSequence.new(Color3.new(1, 1, 1))
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(0.50, 0),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	})

	local sweepTime = cfg.duration or 1.8
	local pauseTime = 0.8
	local rotPerCycle = 30

	task.spawn(function()
		while state.isRunning do
			g.Offset = Vector2.new(-1.5, 0)
			local tw = TweenService:Create(
				g,
				TweenInfo.new(sweepTime, cfg.easing or Enum.EasingStyle.Quad, cfg.direction or Enum.EasingDirection.Out),
				{ Offset = Vector2.new(1.5, 0), Rotation = g.Rotation + rotPerCycle }
			)
			table.insert(state.currentTweens, tw)
			tw:Play()
			tw.Completed:Wait()
			if not state.isRunning then
				break
			end
			task.wait(pauseTime)
		end
	end)

	return state
end

----------------------------------------------------------------- Pan
function AnimationStrategies.pan(g: UIGradient, cfg: AnimationConfig): AnimationState
	local state: AnimationState = { isRunning = true, currentTweens = {}, connections = {}, cleanupTasks = {} }
	local half = (cfg.duration or 2.4) * 0.5
	task.spawn(function()
		while state.isRunning do
			for _, goal in ipairs({
				{ Offset = Vector2.new(1, 0), Rotation = g.Rotation + 15 },
				{ Offset = Vector2.new(0, 0), Rotation = g.Rotation - 15 },
			}) do
				local tw =
					TweenService:Create(g, TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
				table.insert(state.currentTweens, tw)
				tw:Play()
				tw.Completed:Wait()
				if not state.isRunning then
					break
				end
			end
			task.wait(0.3)
		end
	end)
	return state
end

----------------------------------------------------------------- Pulse (updated)
-- Breathing: tween between lighter & darker variants of base sequence
function AnimationStrategies.pulse(g: UIGradient, cfg: AnimationConfig): AnimationState
	local state: AnimationState = { isRunning = true, currentTweens = {}, connections = {}, cleanupTasks = {} }

	local baseSeq: ColorSequence = g.Color
	local lightSeq = StyleGuide and baseSeq -- placeholder (real funcs below)
	local darkSeq = baseSeq

	-- Use public helpers from GradientAnimator once defined
	if g:IsDescendantOf(game) then
        local GA = require(ReplicatedStorage.Utils.GradientAnimator)
		lightSeq = GA.lightenColorSeq(baseSeq, 0.25)
		darkSeq = GA.darkenColorSeq(baseSeq, 0.25)
	end

	local minAlpha = NumberSequence.new(0.15)
	local maxAlpha = NumberSequence.new(0.65)

	-- driver
	local driver = Instance.new("NumberValue")
	driver.Parent = g
	table.insert(state.cleanupTasks, function()
		driver:Destroy()
	end)

	local function refresh()
		local t = driver.Value
		g.Transparency = lerpNumSeq(minAlpha, maxAlpha, t)
		g.Color = lerpColorSeq(lightSeq, darkSeq, t)
	end
	refresh()
	table.insert(state.connections, driver:GetPropertyChangedSignal("Value"):Connect(refresh))

	local half = (cfg.duration or 1.6) * 0.5
	task.spawn(function()
		while state.isRunning do
			for _, v in ipairs({ 1, 0 }) do
				local tw = TweenService:Create(
					driver,
					TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Value = v }
				)
				table.insert(state.currentTweens, tw)
				tw:Play()
				tw.Completed:Wait()
				if not state.isRunning then
					break
				end
			end
		end
	end)
	return state
end

----------------------------------------------------------------- Rainbow
function AnimationStrategies.rainbow(g: UIGradient, cfg: AnimationConfig): AnimationState
	local state: AnimationState = { isRunning = true, currentTweens = {}, connections = {}, cleanupTasks = {} }

	local rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 127)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 100, 0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 127)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 127, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(127, 0, 255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 127)),
	})
	g.Color = rainbow
	g.Transparency = NumberSequence.new(0.1)

	local start = tick()
	local rotSpeed, hueSpeed = 60, 0.08

	table.insert(
		state.connections,
		RunService.Heartbeat:Connect(function()
			if not state.isRunning then
				return
			end
			local t = tick() - start
			g.Rotation = (t * rotSpeed) % 360

			local shift = (t * hueSpeed) % 1
			local keys = {}
			for _, k in ipairs(rainbow.Keypoints) do
				table.insert(keys, ColorSequenceKeypoint.new((k.Time + shift) % 1, k.Value))
			end
			table.sort(keys, function(a, b)
				return a.Time < b.Time
			end)
			g.Color = ColorSequence.new(keys)
		end)
	)
	return state
end

--------------------------------------------------------- Animator class
local GradientAnimator = {}
GradientAnimator.__index = GradientAnimator

function GradientAnimator.new(
	target: GuiObject,
	opts: {
		preset: string?,
		gradient: UIGradient?,
		speed: number?,
		rotation: number?,
		color: ColorSequence?,
	}?
)
	assert(target:IsA("GuiObject"), "Target must be a GuiObject")
	target.BackgroundColor3 = Color3.new(1, 1, 1)

	local g = (opts and opts.gradient) or target:FindFirstChildOfClass("UIGradient")
	if not g then
		g = Instance.new("UIGradient")
		g.Parent = target
	end

	local self = setmetatable({
		_target = target,
		_gradient = g,
		_animationState = nil,
		_baseRotation = (opts and opts.rotation) or 0,
		_speed = (opts and opts.speed) or 1,
	}, GradientAnimator)

	if opts and opts.preset then
		local p = StyleGuide.Gradients[opts.preset]
		if p then
			g.Color = p.Colors
			g.Rotation = p.Rotation
			self._baseRotation = p.Rotation
		else
			warn("[GradientAnimator] Unknown preset:", opts.preset)
		end
	end
	if opts and opts.color then
		g.Color = opts.color
	end
	return self
end

---------------------------------------------------------------- play / stop
function GradientAnimator:play(anim: string?, cfg: AnimationConfig?)
	self:stop()
	anim = (anim or "sheen"):lower()
	local strat = AnimationStrategies[anim] or AnimationStrategies.sheen
	cfg = cfg or {}
	if cfg.duration and self._speed ~= 1 then
		cfg.duration = cfg.duration / self._speed
	end
	self._gradient.Rotation = self._baseRotation
	self._animationState = strat(self._gradient, cfg)
	return self
end

function GradientAnimator:stop()
	local st = self._animationState
	if not st then
		return
	end
	st.isRunning = false
	for _, tw in ipairs(st.currentTweens) do
		tw:Cancel()
	end
	for _, c in ipairs(st.connections) do
		if c.Connected then
			c:Disconnect()
		end
	end
	for _, f in ipairs(st.cleanupTasks) do
		f()
	end
	self._animationState = nil
	self._gradient.Offset = Vector2.zero
	self._gradient.Rotation = self._baseRotation
end

function GradientAnimator:setSpeed(s: number)
	self._speed = math.max(0.05, s)
end

function GradientAnimator:destroy()
	self:stop()
	if self._gradient.Parent then
		self._gradient:Destroy()
	end
	self._gradient = nil :: any
	self._target = nil :: any
end
---------------------------------------------------------------- ColorSequence utilities
local function _map(seq: ColorSequence, f: (Color3) -> Color3): ColorSequence
	local ks = {}
	for _, k in ipairs(seq.Keypoints) do
		table.insert(ks, ColorSequenceKeypoint.new(k.Time, f(k.Value)))
	end
	return ColorSequence.new(ks)
end
local function _lighten(c: Color3, amt: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), math.clamp(amt, 0, 1))
end
local function _darken(c: Color3, amt: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), math.clamp(amt, 0, 1))
end

function GradientAnimator.lightenColorSeq(seq: ColorSequence, amt: number): ColorSequence
	return _map(seq, function(col)
		return _lighten(col, amt)
	end)
end
function GradientAnimator.darkenColorSeq(seq: ColorSequence, amt: number): ColorSequence
	return _map(seq, function(col)
		return _darken(col, amt)
	end)
end

-- Generate tri-stop gradient (light → base → dark)
function GradientAnimator.generateColorSequence(base: Color3, lighter: number?, darker: number?): ColorSequence
	lighter = lighter or 0.4
	darker = darker or 0.4
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, _lighten(base, lighter)),
		ColorSequenceKeypoint.new(0.5, base),
		ColorSequenceKeypoint.new(1.0, _darken(base, darker)),
	})
end

return GradientAnimator
