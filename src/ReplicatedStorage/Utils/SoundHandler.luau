--[[
    SoundHandler.luau
    This module provides functionality to preload sounds, play sounds with specific configurations,
    and manage sound channels for efficient playback.
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local SoundHandler = {}

-- Configure logical sounds
local soundConfigs = {
	ButtonSound = { id = "rbxassetid://107852734860621", volume = 0.2, playbackSpeed = 0.5 },
	ClickSound = { id = "rbxassetid://1673280232", volume = 0.03, playbackSpeed = 1.0 },
	MenuOpen = { id = "rbxassetid://110059957735733", volume = 0.2, playbackSpeed = 1.0 },
	MenuClose = { id = "rbxassetid://97861038165143", volume = 0.2, playbackSpeed = 1.0 },
	PositiveFeedback = { id = "rbxassetid://77117485112690", volume = 0.1, playbackSpeed = 1.0 },
}

-- Map sounds to logical channels for polyphony control
local soundChannels = {
	ButtonSound = "ui_clicks",
	ClickSound = "ui_clicks",
	MenuOpen = "ui_menu",
	MenuClose = "ui_menu",
	PositiveFeedback = "ui_feedback",
}

-- Max overlapping instances per channel
local channelLimits = {
	ui_clicks = 4, -- allow rapid click overlaps
	ui_menu = 1, -- single-voice; new replaces old
	ui_feedback = 2,
}

local preloadedSounds: { [string]: Sound } = {}
local activeByChannel: { [string]: { Sound } } = {}

local FADE_TIME = 0.08 -- short linear fade to prevent pops

-- Fade to near-zero and destroy
local function fadeAndDestroy(s: Sound)
	if not s or not s.Parent then
		return
	end
	if s:GetAttribute("FadingOut") then
		return
	end
	s:SetAttribute("FadingOut", true)
	local tween = TweenService:Create(s, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear), { Volume = 0.0001 })
	tween:Play()
	tween.Completed:Once(function()
		if s.IsPlaying then
			pcall(function()
				s:Stop()
			end)
		end
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Remove a sound from channel tracking
local function removeActive(channel: string, snd: Sound)
	local list = activeByChannel[channel]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i] == snd then
			table.remove(list, i)
			break
		end
	end
end

-- Push a sound to a channel with limit enforcement
local function pushActive(channel: string, snd: Sound)
	local list = activeByChannel[channel]
	if not list then
		list = {}
		activeByChannel[channel] = list
	end
	table.insert(list, snd)
	local limit = channelLimits[channel] or 1
	while #list > limit do
		local victim = table.remove(list, 1)
		fadeAndDestroy(victim)
	end
end

-- Begin replacement for an existing instance (used for single-voice channels)
local function beginReplacement(oldSound: Sound?)
	if not oldSound then
		return
	end
	-- Remove from whichever channel it resides in
	for ch, arr in pairs(activeByChannel) do
		for i = #arr, 1, -1 do
			if arr[i] == oldSound then
				table.remove(arr, i)
				break
			end
		end
	end
	if oldSound.IsPlaying then
		fadeAndDestroy(oldSound)
	else
		if oldSound.Parent then
			oldSound:Destroy()
		end
	end
end

-- Public: Preload all configured sounds to eliminate first-play hitch
function SoundHandler.Preload()
	if next(preloadedSounds) ~= nil then
		return
	end
	local cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "SoundHandlerCache"
	cacheFolder.Parent = SoundService

	local assets = {}
	for name, cfg in pairs(soundConfigs) do
		local s = Instance.new("Sound")
		s.Name = name .. "_Base"
		s.SoundId = cfg.id
		s.Volume = cfg.volume
		s.PlaybackSpeed = cfg.playbackSpeed
		s.RollOffMode = Enum.RollOffMode.Linear
		s.Parent = cacheFolder
		preloadedSounds[name] = s
		table.insert(assets, s)
	end

	-- Best-effort preload; ignore errors
	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end

-- Optional: stop all sounds in a channel (e.g., closing menus)
function SoundHandler.StopChannel(channel: string, fade: number?)
	local list = activeByChannel[channel]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		local snd = list[i]
		if snd then
			if fade and fade > 0 then
				local tween =
					TweenService:Create(snd, TweenInfo.new(fade, Enum.EasingStyle.Linear), { Volume = 0.0001 })
				tween:Play()
				tween.Completed:Once(function()
					if snd.Parent then
						snd:Destroy()
					end
				end)
			else
				if snd.Parent then
					snd:Destroy()
				end
			end
		end
		table.remove(list, i)
	end
end

-- Public: play by logical name with optional overrides
function SoundHandler.PlaySound(name: string, overrideVolume: number?, overridePlaybackSpeed: number?)
	local cfg = soundConfigs[name]
	if not cfg then
		warn("[SoundHandler] Unknown sound:", name)
		return
	end

	-- Resolve channel and enforce single-voice behavior if needed
	local channel = soundChannels[name] or name
	if (channelLimits[channel] or 1) == 1 then
		local list = activeByChannel[channel]
		if list then
			for i = #list, 1, -1 do
				beginReplacement(list[i])
				table.remove(list, i)
			end
		end
	end

	local base = preloadedSounds[name]
	local sound: Sound
	if base then
		sound = base:Clone()
	else
		-- Fallback if Preload not called
		sound = Instance.new("Sound")
		sound.SoundId = cfg.id
		sound.Volume = cfg.volume
		sound.PlaybackSpeed = cfg.playbackSpeed
		sound.RollOffMode = Enum.RollOffMode.Linear
	end

	sound.Name = name .. "_Play"
	if overrideVolume ~= nil then
		sound.Volume = overrideVolume
	end
	if overridePlaybackSpeed ~= nil then
		sound.PlaybackSpeed = overridePlaybackSpeed
	end

	-- Centralize under SoundService for consistency
	sound.Parent = SoundService

	-- Track active and finalize cleanly
	pushActive(channel, sound)

	local finalized = false
	local function finalize()
		if finalized then
			return
		end
		finalized = true
		removeActive(channel, sound)
		if sound.Parent then
			sound:Destroy()
		end
	end

	sound.Ended:Once(finalize)
	sound.Stopped:Once(finalize)

	sound:Play()

	-- Safety timeout in case Ended doesn't fire (e.g., abrupt Parent removal)
	local tl = sound.TimeLength
	if tl <= 0 then
		tl = 3
	end
	local lifetime = (tl / math.max(0.01, sound.PlaybackSpeed)) + 0.25
	task.delay(lifetime, function()
		if sound and sound.Parent then
			finalize()
		end
	end)
end

SoundHandler.Preload()

return SoundHandler
