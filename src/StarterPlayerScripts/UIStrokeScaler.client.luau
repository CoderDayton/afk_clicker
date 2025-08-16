--[[--------------------------------------------------------------
    Global UIStroke Scaler � Never Increase Thickness
    � Drop this LocalScript in StarterPlayerScripts.
    � Change BASE_WIDTH to the resolution you designed your UI for.
----------------------------------------------------------------]]

local BASE_WIDTH  = 1280           -- reference width used in Studio
local Players     = game:GetService("Players")
local camera      = workspace.CurrentCamera
local playerGui   = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Cache each stroke's starting thickness so we can scale from it
local originalThickness = {}       -- [UIStroke] = number

local function scaleStroke(stroke: UIStroke)
	-- Store the original thickness once
	if not originalThickness[stroke] then
		originalThickness[stroke] = stroke.Thickness
		stroke.Destroying:Once(function()
			originalThickness[stroke] = nil      -- clean up on destroy
		end)
	end

	-- Scale factor based on current width; cap at 1 so it never increases
	local scaleFactor = math.min(camera.ViewportSize.X / BASE_WIDTH, 1)

	stroke.Thickness = originalThickness[stroke] * scaleFactor
end

-- Apply scaling to every UIStroke that exists right now
local function rescaleAllStrokes()
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("UIStroke") then
			scaleStroke(obj)
		end
	end
end

-- Re-apply when:
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleAllStrokes)  -- window/device size changes
playerGui.DescendantAdded:Connect(function(inst)                            -- new UIStroke appears
	if inst:IsA("UIStroke") then
		scaleStroke(inst)
	end
end)

-- Initial pass
rescaleAllStrokes()
