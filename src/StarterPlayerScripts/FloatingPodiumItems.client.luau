local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local camera = workspace.CurrentCamera

local courtyard = workspace:WaitForChild("Courtyard")
local PodiumFolder = courtyard:WaitForChild("Podiums")

-- Performance optimizations
local animatedParts = {}
local lastScanTime = 0
local SCAN_INTERVAL = 5 -- Reduced frequency: scan every 5 seconds instead of 1
local ANIMATION_DISTANCE = 100 -- Only animate within this distance from players
local frameCount = 0
local SKIP_FRAMES = 2 -- Skip every 2 frames for non-critical animations (30 FPS instead of 60)

-- Additional optimizations
local VISIBILITY_CHECK_INTERVAL = 0.5 -- Check visibility every 0.5 seconds
local lastVisibilityCheck = 0
local CAMERA_FOV_MARGIN = 75 -- Increased margin for more forgiving visibility culling

-- Performance configuration
local USE_TWEENS = true -- Set to false to use direct property manipulation instead
local USE_VISIBILITY_CULLING = false -- Set to false if visibility culling is causing issues

-- Object pooling for performance
local tweenPool = {}
local visibilityCache = {}

-- TweenInfo cache for reuse
local floatTweenInfo = TweenInfo.new(
	1.5, -- Base duration (will be scaled by speed)
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1, -- Infinite repeats
	true -- Reverse
)

local ITEMS_TO_ANIMATE = {
	["GoldFloatingCrown"] = {
		spin = true,
		spinAxis = "Y", -- "X", "Y", or "Z"
		spinSpeed = 20, -- degrees per second
		float = true,
		floatAmplitude = 0.6,
		floatSpeed = 1.2,
	},
	["Fedora of the Darkest Night"] = {
		spin = true,
		spinAxis = "Y", -- "X", "Y", or "Z"
		spinSpeed = 20, -- degrees per second
		float = true,
		floatAmplitude = 0.6,
		floatSpeed = 1.2,
	},
	["Accessory (Bloodvein Horns)"] = {
		spin = true,
		spinAxis = "Y", -- "X", "Y", or "Z"
		spinSpeed = 20, -- degrees per second
		float = true,
		floatAmplitude = 0.6,
		floatSpeed = 1.2,
	},
}

-- Object pooling for tweens (defined early for use in tryInsertPart)
local function getTweenFromPool(part, tweenInfo, propertyTable)
	local poolKey = tostring(part) .. "_" .. tostring(propertyTable)

	if tweenPool[poolKey] then
		return tweenPool[poolKey]
	end

	local tween = TweenService:Create(part, tweenInfo, propertyTable)
	tweenPool[poolKey] = tween
	return tween
end

local function addParticles(part)
	if part:FindFirstChild("PodiumParticles") then
		return
	end
	local config = ITEMS_TO_ANIMATE[part.Name]
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PodiumParticles"
	emitter.Texture = "rbxassetid://258128463"
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Size = NumberSequence.new(0.3)
	emitter.Speed = NumberRange.new(0.7, 1.1)
	emitter.LightEmission = 0.7
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = config and config.particleColor
		or ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 255, 255))
	emitter.Parent = part
end

local function tryInsertPart(obj)
	local itemOptions = ITEMS_TO_ANIMATE[obj.Name]
	if itemOptions then
		local part = nil
		if obj:IsA("Accessory") then
			part = obj:FindFirstChild("Handle")
		elseif obj:IsA("Model") and obj.PrimaryPart then
			part = obj.PrimaryPart
		elseif obj:IsA("MeshPart") or obj:IsA("Part") or obj:IsA("UnionOperation") then
			part = obj
		end
		if part and not animatedParts[part] then
			-- Apply initial settings
			if itemOptions.glow then
				part.Material = Enum.Material.Neon
				part.Reflectance = 0.15
			end
			if itemOptions.particles then
				addParticles(part)
			end
			-- Pre-calculate static values for better performance
			local spinAxisEnum = 1 -- Default Y
			if itemOptions.spinAxis then
				local axis = string.upper(itemOptions.spinAxis)
				if axis == "X" then
					spinAxisEnum = 0
				elseif axis == "Z" then
					spinAxisEnum = 2
				end
			end

			-- Create TweenService animation for floating if needed
			local floatTween = nil
			if USE_TWEENS and itemOptions.float then
				local floatAmplitude = itemOptions.floatAmplitude or 0.6

				-- Use the cached TweenInfo but adjust its speed if needed
				local adjustedFloatTweenInfo = floatTweenInfo
				local floatSpeed = itemOptions.floatSpeed or 1.2
				if floatSpeed ~= 1.2 then -- Only create a new one if speed differs from default
					adjustedFloatTweenInfo = TweenInfo.new(
						1.5 * (1.2 / floatSpeed), -- Scale duration inversely with speed
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut,
						-1, -- Infinite repeats
						true -- Reverse
					)
				end

				-- Create tween for floating effect
				floatTween = getTweenFromPool(part, adjustedFloatTweenInfo, {
					Position = part.Position + Vector3.new(0, floatAmplitude, 0),
				})
			end

			animatedParts[part] = {
				part = part,
				basePosition = part.Position,
				baseOrientation = part.Orientation,
				options = itemOptions,
				baseColor = part.Color,
				-- Cached values for performance
				spinAxisEnum = spinAxisEnum,
				floatSpeed = itemOptions.floatSpeed or 1.2,
				floatAmplitude = itemOptions.floatAmplitude or 0.6,
				spinSpeed = itemOptions.spinSpeed or 36,
				colorCycleSpeed = itemOptions.colorCycleSpeed or 0.2,
				-- TweenService optimization
				floatTween = floatTween,
				isVisible = true, -- Cache visibility state
			}
			return
		end
	end
	for _, child in ipairs(obj:GetChildren()) do
		tryInsertPart(child)
	end
end

-- Optimized scanning: only scan when needed and less frequently
local function scanForNewParts()
	local currentTime = tick()
	if currentTime - lastScanTime >= SCAN_INTERVAL then
		lastScanTime = currentTime
		for _, podium in ipairs(PodiumFolder:GetChildren()) do
			tryInsertPart(podium)
		end
	end
end

-- Also scan when new children are added to podium folder
PodiumFolder.ChildAdded:Connect(function(child)
	task.wait(0.1) -- Small delay to ensure the child is fully loaded
	tryInsertPart(child)
end)

-- Performance helper functions
local function isPlayerNearby(position)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
			if distance <= ANIMATION_DISTANCE then
				return true
			end
		end
	end
	return false
end

-- Visibility culling optimization
local function isPartVisible(part)
	-- If visibility culling is disabled, always return true
	if not USE_VISIBILITY_CULLING then
		return true
	end

	if not camera or not camera.Parent then
		return true -- Fallback if camera not available
	end

	-- Check cache first
	local cacheKey = tostring(part)
	local cached = visibilityCache[cacheKey]
	if cached and tick() - cached.time < VISIBILITY_CHECK_INTERVAL then
		return cached.visible
	end

	-- Get part bounds to check visibility more accurately
	local partSize = part.Size
	local partCFrame = part.CFrame
	local cameraPosition = camera.CFrame.Position
	local cameraLookVector = camera.CFrame.LookVector

	-- Consider the part visible if any of its corners are in view
	-- This makes visibility culling much more forgiving
	for _, corner in pairs({
		Vector3.new(-1, -1, -1),
		Vector3.new(1, -1, -1),
		Vector3.new(-1, 1, -1),
		Vector3.new(1, 1, -1),
		Vector3.new(-1, -1, 1),
		Vector3.new(1, -1, 1),
		Vector3.new(-1, 1, 1),
		Vector3.new(1, 1, 1),
		Vector3.new(0, 0, 0), -- Center point
	}) do
		-- Transform corner to world space
		local cornerPoint = partCFrame * (corner * (partSize / 2))
		local directionToCorner = (cornerPoint - cameraPosition).Unit

		-- Calculate angle between camera look vector and direction to corner
		local dotProduct = cameraLookVector:Dot(directionToCorner)
		local angle = math.acos(math.clamp(dotProduct, -1, 1))
		local angleDegrees = math.deg(angle)

		-- Check if within camera FOV + margin
		if angleDegrees <= (camera.FieldOfView / 2) + CAMERA_FOV_MARGIN then
			-- Update cache and return visible
			visibilityCache[cacheKey] = {
				visible = true,
				time = tick(),
			}
			return true
		end
	end

	-- If no corners are visible, update cache and return not visible
	visibilityCache[cacheKey] = {
		visible = false,
		time = tick(),
	}
	return false
end

-- Clean up old cache entries to prevent memory leaks
local function cleanupCaches()
	local currentTime = tick()

	-- Clean visibility cache
	for key, data in pairs(visibilityCache) do
		if currentTime - data.time > VISIBILITY_CHECK_INTERVAL * 5 then
			visibilityCache[key] = nil
		end
	end
end

-- Optimized animation loop with performance improvements
RunService.Heartbeat:Connect(function(dt)
	frameCount = frameCount + 1
	local currentTime = tick()

	-- Scan for new parts occasionally
	scanForNewParts()

	-- Clean up caches periodically (every 5 seconds)
	if frameCount % 300 == 0 then -- 300 frames ≈ 5 seconds at 60 FPS
		cleanupCaches()
	end

	-- Skip frames for non-critical animations to reduce CPU load
	local shouldAnimate = frameCount % (SKIP_FRAMES + 1) == 0
	local shouldCheckVisibility = currentTime - lastVisibilityCheck >= VISIBILITY_CHECK_INTERVAL

	-- Update visibility check timer
	if shouldCheckVisibility then
		lastVisibilityCheck = currentTime
	end

	for part, data in pairs(animatedParts) do
		-- Clean up invalid parts
		if not data.part or not data.part.Parent then
			-- Clean up tween if it exists
			if data.floatTween then
				data.floatTween:Cancel()
			end
			animatedParts[part] = nil
			continue
		end

		-- Distance culling: only animate if players are nearby
		local isNearby = isPlayerNearby(data.part.Position)
		if not isNearby then
			-- Pause tween if active
			if data.floatTween and data.floatTween.PlaybackState == Enum.PlaybackState.Playing then
				data.floatTween:Pause()
			end
			continue
		end

		-- Visibility culling: only animate visible objects
		if shouldCheckVisibility then
			data.isVisible = isPartVisible(data.part)
		end

		-- If not visible and visibility culling is enabled, pause animation
		if not data.isVisible and USE_VISIBILITY_CULLING then
			-- Pause tween if not visible
			if data.floatTween and data.floatTween.PlaybackState == Enum.PlaybackState.Playing then
				data.floatTween:Pause()
			end
			continue
		end

		-- Debug visualization - uncomment this to see which items are considered visible
		-- if shouldCheckVisibility then
		--    data.part.Color = data.isVisible and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
		-- end

		local opts = data.options

		-- FLOAT animation logic
		if opts.float then
			if USE_TWEENS and data.floatTween then
				-- Use TweenService for smoother animation
				if data.floatTween.PlaybackState ~= Enum.PlaybackState.Playing then
					data.floatTween:Play()
				end
			else
				-- Use direct property manipulation (may be more performant in some cases)
				local floatY = math.sin(currentTime * data.floatSpeed) * data.floatAmplitude
				data.part.Position = data.basePosition + Vector3.new(0, floatY, 0)
			end
		end

		-- SPIN - Use cached axis enum for better performance
		if opts.spin and shouldAnimate then
			local ori = data.part.Orientation
			local spinInc = data.spinSpeed * dt

			if data.spinAxisEnum == 0 then -- X
				data.part.Orientation = Vector3.new((ori.X + spinInc) % 360, ori.Y, ori.Z)
			elseif data.spinAxisEnum == 2 then -- Z
				data.part.Orientation = Vector3.new(ori.X, ori.Y, (ori.Z + spinInc) % 360)
			else -- Y (default)
				data.part.Orientation = Vector3.new(ori.X, (ori.Y + spinInc) % 360, ori.Z)
			end
		end

		-- COLOR CYCLE - Only update when needed
		if opts.colorCycle and shouldAnimate then
			local hue = (currentTime * data.colorCycleSpeed) % 1
			data.part.Color = Color3.fromHSV(hue, 0.7, 1)
		elseif not opts.colorCycle then
			data.part.Color = data.baseColor
		end
	end
end)
