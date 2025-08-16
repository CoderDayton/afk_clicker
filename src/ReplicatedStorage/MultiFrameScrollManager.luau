--[[
	MultiFrameScrollManager.luau

	Manages the automatic scrolling of a ScrollingFrame that contains multiple frames with layouts.
	Automatically calculates the CanvasSize based on the content size of each frame.

    based on https://devforum.roblox.com/t/how-to-make-a-scrollingframe-automatically-scroll-to-the-bottom-of-the-content/1000000
]]


local RunService = game:GetService("RunService")

local MultiFrameScrollManager = {}

-- Function to calculate total content size across multiple layout frames
local function calculateTotalCanvasSize(scrollingFrame)
	local totalHeight = 0
	local maxWidth = 0
	local frameSpacing = 20 -- Space between each main frame section

	-- Get all direct children that are frames with layouts
	local layoutFrames = {}
	for _, child in pairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			local layout = child:FindFirstChildOfClass("UIGridLayout") or
				child:FindFirstChildOfClass("UIListLayout")
			if layout then
				table.insert(layoutFrames, {frame = child, layout = layout})
			end
		end
	end

	-- Calculate size for each frame
	for i, frameData in ipairs(layoutFrames) do
		local frame = frameData.frame
		local layout = frameData.layout

		-- Wait for layout to update
		RunService.Heartbeat:Wait()

		-- Get the content size from the layout
		local contentSize = layout.AbsoluteContentSize

		-- Account for frame's own padding/size constraints
		local frameHeight = math.max(contentSize.Y, frame.Size.Y.Offset)
		local frameWidth = math.max(contentSize.X, frame.Size.X.Offset)

		totalHeight = totalHeight + frameHeight
		maxWidth = math.max(maxWidth, frameWidth)

		-- Add spacing between frames (except for the last one)
		if i < #layoutFrames then
			totalHeight = totalHeight + frameSpacing
		end
	end

	-- Add bottom padding for comfortable scrolling
	local bottomPadding = 300
	totalHeight = totalHeight + bottomPadding

	return UDim2.fromOffset(maxWidth, totalHeight)
end

-- Function to set up automatic CanvasSize management
function MultiFrameScrollManager.setupScrollingFrame(scrollingFrame)
	local function updateCanvasSize()
		local newCanvasSize = calculateTotalCanvasSize(scrollingFrame)
		scrollingFrame.CanvasSize = newCanvasSize

		-- Enable/disable scrolling based on content
		local needsScrolling = newCanvasSize.Y.Offset > scrollingFrame.AbsoluteSize.Y
		scrollingFrame.ScrollingEnabled = needsScrolling
	end

	-- Initial canvas size update
	updateCanvasSize()

	-- Set up automatic updates when any layout changes
	local function connectToLayout(frame)
		local layout = frame:FindFirstChildOfClass("UIGridLayout") or
			frame:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
		end
	end

	-- Connect to existing frames
	for _, child in pairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			connectToLayout(child)
		end
	end

	-- Connect to new frames being added
	scrollingFrame.ChildAdded:Connect(function(child)
		if child:IsA("Frame") then
			task.wait() -- Wait for layout to be added to the frame
			connectToLayout(child)
			updateCanvasSize()
		end
	end)

	return updateCanvasSize -- Return function for manual updates
end

return MultiFrameScrollManager
