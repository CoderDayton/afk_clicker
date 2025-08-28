--!strict
--------------------------------------------------------------------
--  UIAnimator Module
--  Provides animated opening/closing of GUI elements tons of options
--  and camera effects.
--  Made for FREE UGC: Xowaru Clicker | https://www.roblox.com/games/73435591473239/FREE-UGC-Xowaru-Clicker#!/game-instances
--------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
--------------------------------------------------------------------
--  Type definitions
--------------------------------------------------------------------
type GuiProps = {
	Size: UDim2,
	Position: UDim2,
	Transparency: number,
}

type TweenBundle = {
	tweens: { Tween },
	camTween: Tween?,
	completed: number,
	total: number,
	isActive: boolean,
}

type AnimationOptions = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	FadeFrom: number?,
	FadeTo: number?,
	ScaleFrom: number?,
	ScaleTo: number?,
	MoveFrom: UDim2?,
	MoveTo: UDim2?,
	TargetPosition: UDim2?,
	CameraDelta: number?,
	CameraDuration: number?,
	CameraEasingStyle: Enum.EasingStyle?,
	CameraEasingDirection: Enum.EasingDirection?,
	onBeforeOpen: ((GuiObject) -> ())?,
	onOpen: ((GuiObject) -> ())?,
	onAfterOpen: ((GuiObject) -> ())?,
	onBeforeClose: ((GuiObject) -> ())?,
	onClose: ((GuiObject) -> ())?,
	onAfterClose: ((GuiObject) -> ())?,
}

type ChainStep = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	Properties: { [string]: any },
	Delay: number?,
}
--------------------------------------------------------------------
--  Internal state
--------------------------------------------------------------------
local UIAnimator = {}
local guiOrigin = {} :: { [GuiObject]: GuiProps }
local activeTween = {} :: { [GuiObject]: TweenBundle }
local camOrigin = {} :: { [Player]: number }
--------------------------------------------------------------------
--  Utility helpers
--------------------------------------------------------------------
local function rememberGuiProps(gui: GuiObject)
	if guiOrigin[gui] then
		return
	end
	guiOrigin[gui] = {
		Size = gui.Size,
		Position = gui.Position,
		Transparency = (gui :: any).BackgroundTransparency or 0,
	}
end

local function tween(obj: Instance, info: TweenInfo, props: { [string]: any }): Tween
	return TweenService:Create(obj, info, props)
end

local function cancelTweens(gui: GuiObject)
	local bundle = activeTween[gui]
	if not bundle then
		return
	end

	-- Mark as inactive to prevent completion handlers from firing
	bundle.isActive = false

	for _, t in ipairs(bundle.tweens) do
		if t.PlaybackState ~= Enum.PlaybackState.Completed then
			t:Cancel()
		end
	end

	if bundle.camTween and bundle.camTween.PlaybackState ~= Enum.PlaybackState.Completed then
		bundle.camTween:Cancel()
	end

	activeTween[gui] = nil
end
--------------------------------------------------------------------
--  Chain: sequential tween helper
--------------------------------------------------------------------
function UIAnimator.chain(gui: GuiObject, steps: { ChainStep }, onComplete: (() -> ())?)
	cancelTweens(gui)

	local idx = 1
	local function run()
		if idx > #steps then
			if onComplete then
				onComplete()
			end
			return
		end

		local step = steps[idx]
		idx += 1

		local info = TweenInfo.new(
			step.Duration or 0.3,
			step.EasingStyle or Enum.EasingStyle.Quad,
			step.EasingDirection or Enum.EasingDirection.Out
		)

		local tw = tween(gui, info, step.Properties)
		tw:Play()

		tw.Completed:Connect(function()
			if step.Delay then
				task.delay(step.Delay, run)
			else
				run()
			end
		end)
	end
	run()
end
--------------------------------------------------------------------
--  Private: camera management
--------------------------------------------------------------------
local function storeCameraFOV()
	local player = Players.LocalPlayer
	if not player then
		return false
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return false
	end

	if not camOrigin[player] then
		camOrigin[player] = cam.FieldOfView
	end

	return true
end

local function buildCameraTween(
	delta: number,
	duration: number,
	ease: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween?
	if not storeCameraFOV() then
		return nil
	end

	local cam = workspace.CurrentCamera
	local targetFOV = math.clamp(cam.FieldOfView - delta, 10, 120)
	local info = TweenInfo.new(duration, ease or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.Out)

	return TweenService:Create(cam, info, { FieldOfView = targetFOV })
end

local function restoreCamera(): boolean
	local player = Players.LocalPlayer
	if not player then
		return false
	end

	local base = camOrigin[player]
	if not base then
		return false
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return false
	end

	cam.FieldOfView = base
	camOrigin[player] = nil
	return true
end
--------------------------------------------------------------------
--  Synchronized completion handler
--------------------------------------------------------------------
local function createCompletionHandler(gui: GuiObject, bundle: TweenBundle, onComplete: (() -> ())?): () -> ()
	return function()
		-- Only proceed if this bundle is still active
		if not bundle.isActive then
			return
		end

		bundle.completed += 1

		if bundle.completed >= bundle.total then
			bundle.isActive = false -- Prevent double-firing
			if onComplete then
				task.spawn(onComplete)
			end
		end
	end
end
--------------------------------------------------------------------
--  OPEN
--------------------------------------------------------------------
function UIAnimator.open(gui: GuiObject, opts: AnimationOptions?)
	opts = opts or {}
	rememberGuiProps(gui)
	local props = guiOrigin[gui]
	if not props then
		warn("[UIAnimator] Failed to remember GUI properties")
		return
	end

	cancelTweens(gui)

	if opts.onBeforeOpen then
		local success, err = pcall(opts.onBeforeOpen, gui)
		if not success then
			warn("[UIAnimator] onBeforeOpen error:", err)
		end
	end

	gui.Visible = true

	-- Apply starting states
	if opts.FadeFrom then
		(gui :: any).BackgroundTransparency = opts.FadeFrom
	end
	if opts.ScaleFrom then
		local scale = opts.ScaleFrom
		gui.Size = UDim2.fromScale(
			props.Size.X.Scale * scale,
			props.Size.Y.Scale * scale
		) + UDim2.fromOffset(
			props.Size.X.Offset * scale,
			props.Size.Y.Offset * scale
		)
	end
	if opts.MoveFrom then
		gui.Position = opts.MoveFrom
	end

	if opts.onOpen then
		local success, err = pcall(opts.onOpen, gui)
		if not success then
			warn("[UIAnimator] onOpen error:", err)
		end
	end

	----------------------------------------
	-- Build fresh bundle with reset state
	----------------------------------------
	local duration = opts.Duration or 0.3
	local guiTweenInfo = TweenInfo.new(
		duration,
		opts.EasingStyle or Enum.EasingStyle.Quad,
		opts.EasingDirection or Enum.EasingDirection.Out
	)

	local guiTween = tween(gui, guiTweenInfo, {
		Size = props.Size,
		Position = opts.TargetPosition or props.Position,
		BackgroundTransparency = props.Transparency,
	})

	-- Create fresh bundle with reset counters
	local bundle: TweenBundle = {
		tweens = { guiTween },
		camTween = nil,
		completed = 0,
		total = 1,
		isActive = true,
	}

	-- Optional camera tween
	if opts.CameraDelta then
		local camTw = buildCameraTween(
			opts.CameraDelta,
			opts.CameraDuration or duration,
			opts.CameraEasingStyle,
			opts.CameraEasingDirection
		)
		if camTw then
			bundle.camTween = camTw
			bundle.total += 1
		end
	end

	activeTween[gui] = bundle

	-- Setup completion handler
	local completionHandler = createCompletionHandler(gui, bundle, function()
		if opts.onAfterOpen then
			local success, err = pcall(opts.onAfterOpen, gui)
			if not success then
				warn("[UIAnimator] onAfterOpen error:", err)
			end
		end
	end)

	-- Connect completion events
	guiTween.Completed:Connect(completionHandler)
	if bundle.camTween then
		bundle.camTween.Completed:Connect(completionHandler)
	end

	-- Start both tweens simultaneously
	guiTween:Play()
	if bundle.camTween then
		bundle.camTween:Play()
	end
end
--------------------------------------------------------------------
--  CLOSE (fixed state management)
--------------------------------------------------------------------
function UIAnimator.close(gui: GuiObject, opts: AnimationOptions?)
	opts = opts or {}
	rememberGuiProps(gui)
	local props = guiOrigin[gui]
	if not props then
		return
	end

	cancelTweens(gui)

	if opts.onBeforeClose then
		local success, err = pcall(opts.onBeforeClose, gui)
		if not success then
			warn("[UIAnimator] onBeforeClose error:", err)
		end
	end
	if opts.onClose then
		local success, err = pcall(opts.onClose, gui)
		if not success then
			warn("[UIAnimator] onClose error:", err)
		end
	end

	-- Calculate target properties
	local targetSize = props.Size
	if opts.ScaleTo then
		local scale = opts.ScaleTo
		targetSize = UDim2.fromScale(
			props.Size.X.Scale * scale,
			props.Size.Y.Scale * scale
		) + UDim2.fromOffset(
			props.Size.X.Offset * scale,
			props.Size.Y.Offset * scale
		)
	end

	local targetPos = opts.MoveTo or opts.TargetPosition or props.Position
	local targetFade = opts.FadeTo or 1

	local duration = opts.Duration or 0.3
	local guiTweenInfo = TweenInfo.new(
		duration,
		opts.EasingStyle or Enum.EasingStyle.Quad,
		opts.EasingDirection or Enum.EasingDirection.In
	)

	local guiTween = tween(gui, guiTweenInfo, {
		Size = targetSize,
		Position = targetPos,
		BackgroundTransparency = targetFade,
	})

	-- Create fresh bundle with reset state
	local bundle: TweenBundle = {
		tweens = { guiTween },
		camTween = nil,
		completed = 0,
		total = 1,
		isActive = true,
	}

	-- Camera tween back to original (if delta was specified in open)
	if opts.CameraDelta then
		local player = Players.LocalPlayer
		local cam = workspace.CurrentCamera
		if player and cam and camOrigin[player] then
			local camTw = TweenService:Create(
				cam,
				TweenInfo.new(
					opts.CameraDuration or duration,
					opts.CameraEasingStyle or Enum.EasingStyle.Sine,
					opts.CameraEasingDirection or Enum.EasingDirection.In
				),
				{ FieldOfView = camOrigin[player] }
			)
			bundle.camTween = camTw
			bundle.total += 1
		end
	end

	activeTween[gui] = bundle

	-- Completion handler with proper restoration order
	local completionHandler = createCompletionHandler(gui, bundle, function()
		-- Restore GUI properties first
		gui.Visible = false
		gui.Size = props.Size
		gui.Position = props.Position
		local success = pcall(function()
			(gui :: any).BackgroundTransparency = props.Transparency
		end)

		if not success then
			warn("[UIAnimator] Failed to restore BackgroundTransparency")
		end

		-- Then restore camera (this will clear camOrigin)
		if opts.CameraDelta then
			restoreCamera()
		end

		if opts.onAfterClose then
			local ok, err = pcall(opts.onAfterClose, gui)
			if not ok then
				warn("[UIAnimator] onAfterClose error:", err)
			end
		end
	end)

	-- Connect and start
	guiTween.Completed:Connect(completionHandler)
	if bundle.camTween then
		bundle.camTween.Completed:Connect(completionHandler)
	end

	guiTween:Play()
	if bundle.camTween then
		bundle.camTween:Play()
	end
end
--------------------------------------------------------------------
--  CLEANUP
--------------------------------------------------------------------
function UIAnimator.cleanup(gui: GuiObject)
	cancelTweens(gui)

	local props = guiOrigin[gui]
	if props and gui.Parent then
		gui.Size = props.Size
		gui.Position = props.Position
		local success = pcall(function()
			(gui :: any).BackgroundTransparency = props.Transparency
		end)
		if not success then
			warn("[UIAnimator] Failed to restore BackgroundTransparency")
		end
	end

	guiOrigin[gui] = nil
	restoreCamera()
end

function UIAnimator.cleanupAll()
	for gui, _ in pairs(guiOrigin) do
		UIAnimator.cleanup(gui)
	end

	table.clear(guiOrigin)
	table.clear(activeTween)
	table.clear(camOrigin)
end

return UIAnimator
