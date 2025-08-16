local UtilsFolder = script.Parent
local RR = require(UtilsFolder:WaitForChild("RobustRequire"))
local StyleGuide = RR.get(game.ReplicatedStorage.StyleGuide)

local SoftShadow = {}

-- Optimized connection management
local shadowConnections = setmetatable({}, { __mode = "k" })
local pendingUpdates = {} -- Batch position updates
local updateScheduled = false

-- Single position update scheduler to reduce RenderStepped connections
local function schedulePositionUpdate()
	if updateScheduled then return end
	updateScheduled = true

	task.defer(function()
		for shadowImage, targetGui in pairs(pendingUpdates) do
			if shadowImage.Parent and targetGui.Parent then
				shadowImage.AnchorPoint = targetGui.AnchorPoint
				shadowImage.Position = targetGui.Position
			end
		end
		table.clear(pendingUpdates)
		updateScheduled = false
	end)
end

function SoftShadow.apply(targetGui: GuiObject, options: {
	SizeScale: number?, Opacity: number?, Color: Color3?,
	Location: ("Inside" | "Outside")?, Position: UDim2?, ZIndex: number?,
	Id: string?, AnchorPoint: Vector2?
})
	options = options or {}
	local style = StyleGuide.Shadow.SoftShadow

	local shadowId = options.Id or tostring(math.random(100000, 999999))
	local shadowName = "SoftShadow_" .. shadowId

	-- Remove existing
	SoftShadow.remove(targetGui, shadowId)

	-- Create shadow
	local shadowImage = Instance.new("ImageLabel")
	shadowImage.Name = shadowName
	shadowImage.BackgroundTransparency = 1
	shadowImage.Image = "rbxassetid://11999950713"
	shadowImage.ImageColor3 = options.Color or StyleGuide.Glow.CTA
	shadowImage.ImageTransparency = 1 - (options.Opacity or style.Opacity)
	shadowImage.ScaleType = Enum.ScaleType.Fit

	-- Placement logic
	local placement = options.Location or "Outside"
	local anchorPoint, position

	if placement == "Outside" then
		shadowImage.Parent = targetGui.Parent
		shadowImage.ZIndex = (options.ZIndex ~= nil) and options.ZIndex or (targetGui.ZIndex - 1)
		anchorPoint = options.AnchorPoint or targetGui.AnchorPoint
		position = options.Position or targetGui.Position
	else -- Inside or default
		shadowImage.Parent = targetGui
		shadowImage.ZIndex = (options.ZIndex ~= nil) and options.ZIndex or (targetGui.ZIndex + 1)
		anchorPoint = options.AnchorPoint or Vector2.new(0.5, 0.5)
		position = options.Position or UDim2.fromScale(0.5, 0.5)
	end

	shadowImage.AnchorPoint = anchorPoint
	shadowImage.Position = position

	-- Size update
	local function updateSize()
		if not shadowImage.Parent then return end
		local sizeScale = options.SizeScale or (1 + (style.Size / 100))
		if style.Blur and style.Blur > 0 then
			sizeScale += style.Blur / 100
		end
		shadowImage.Size = UDim2.fromScale(sizeScale, sizeScale)
	end
	updateSize()

	-- Connection management
	local connections = {}

	-- Size tracking
	table.insert(connections, targetGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize))

	-- Visibility tracking
	local function updateVisibility()
		shadowImage.Visible = targetGui.Visible
	end
	updateVisibility()
	table.insert(connections, targetGui:GetPropertyChangedSignal("Visible"):Connect(updateVisibility))

	-- OPTIMIZED: Position tracking for outside shadows
	if placement == "Outside" and options.Position == nil then
		local function queuePositionUpdate()
			pendingUpdates[shadowImage] = targetGui
			schedulePositionUpdate()
		end

		-- Reduced connection count - batch updates
		table.insert(connections, targetGui:GetPropertyChangedSignal("AnchorPoint"):Connect(queuePositionUpdate))
		table.insert(connections, targetGui:GetPropertyChangedSignal("Position"):Connect(queuePositionUpdate))

		-- Only add expensive AbsolutePosition tracking if gradients are present
		if targetGui:FindFirstChildOfClass("UIGradient") then
			table.insert(connections, targetGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(queuePositionUpdate))
		end
	end

	-- Store connections
	shadowConnections[targetGui] = shadowConnections[targetGui] or {}
	shadowConnections[targetGui][shadowId] = connections

	-- Owner tag
	local ownerTag = Instance.new("ObjectValue")
	ownerTag.Name = "_ParentGui"
	ownerTag.Value = targetGui
	ownerTag.Parent = shadowImage

	return shadowImage
end

function SoftShadow.remove(targetGui: GuiObject, shadowId: string?)
	local function cleanupShadow(shadow: Instance)
		pendingUpdates[shadow] = nil -- Remove from batch queue
		shadow:Destroy()
	end

	local function disconnectConnections(target: Instance, id: string?)
		local byId = shadowConnections[target]
		if not byId then return end

		if id then
			local connections = byId[id]
			if connections then
				for _, conn in ipairs(connections) do
					if conn then conn:Disconnect() end
				end
				byId[id] = nil
			end
		else
			for _, connections in pairs(byId) do
				for _, conn in ipairs(connections) do
					if conn then conn:Disconnect() end
				end
			end
			shadowConnections[target] = nil
		end
	end

	if shadowId then
		local shadowName = "SoftShadow_" .. shadowId

		-- Clean up child shadows
		local childShadow = targetGui:FindFirstChild(shadowName)
		if childShadow then cleanupShadow(childShadow) end

		-- Clean up sibling shadows
		if targetGui.Parent then
			for _, child in ipairs(targetGui.Parent:GetChildren()) do
				if child.Name == shadowName then
					local tag = child:FindFirstChild("_ParentGui")
					if tag and tag.Value == targetGui then
						cleanupShadow(child)
						break
					end
				end
			end
		end

		disconnectConnections(targetGui, shadowId)
	else
		-- Remove all shadows for this target
		for _, child in ipairs(targetGui:GetChildren()) do
			if child.Name:match("^SoftShadow_") then
				cleanupShadow(child)
			end
		end

		if targetGui.Parent then
			for _, child in ipairs(targetGui.Parent:GetChildren()) do
				if child.Name:match("^SoftShadow_") then
					local tag = child:FindFirstChild("_ParentGui")
					if tag and tag.Value == targetGui then
						cleanupShadow(child)
					end
				end
			end
		end

		disconnectConnections(targetGui)
	end
end

return SoftShadow
