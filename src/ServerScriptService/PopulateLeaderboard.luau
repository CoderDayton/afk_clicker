local TweenService = game:GetService("TweenService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local LeaderboardUtils = RR.get(game.ReplicatedStorage.Utils.LeaderboardUtils)
local LeaderboardData = RR.get("ServerScriptService.LeaderboardData")

local recentFrame = workspace.LeaderboardBoard.LeaderboardGui.MainPanel.RecentScrollingFrame
local topFrame = workspace.LeaderboardBoard.LeaderboardGui.MainPanel.TopScrollingFrame

local PopulateLeaderboard = {}

-- ========== Caching Usernames ==========
local userNameCache = {}

local function getCachedName(userId)
    if userNameCache[userId] then
        return userNameCache[userId]
    end
    local success, name = pcall(function()
        return game.Players:GetNameFromUserIdAsync(userId)
    end)
    if success and name then
        userNameCache[userId] = name
        return name
    else
        return "Unknown"
    end
end

local function clear(frame)
	for _,child in pairs(frame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function animateEntry(entry)
	entry.BackgroundTransparency = 1
	entry.Position += UDim2.fromOffset(0,15)
	TweenService:Create(entry, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15,
		Position = entry.Position - UDim2.fromOffset(0,15)
	}):Play()
end

function PopulateLeaderboard.Populate()
    clear(recentFrame)
    clear(topFrame)

    local allRecent = LeaderboardData.GetAllRecentPurchases()
    local top = LeaderboardData.GetTopSpenders()

    for _, data in ipairs(allRecent) do
        if typeof(data) ~= "table" or not data.userId or not data.name or not data.item or typeof(data.item) ~= "string" or not data.price then
            warn("Invalid recent purchase data:", data)
            continue
        end
        local entry = LeaderboardUtils.CreateRecentEntry(recentFrame, data.userId, data.name, data.item, data.price)
        entry.RobuxRow.RobuxAmount.Text = tostring(data.price)
        animateEntry(entry)
    end

    for rank, data in ipairs(top) do
        if typeof(data) ~= "table" or not data.userId or not data.amount then
            warn("Invalid top spender data:", data)
            continue
        end
        if data.amount <= 0 then continue end
        local name = getCachedName(data.userId)
        local entry = LeaderboardUtils.CreateTopSpenderEntry(topFrame, data.userId, name, data.amount, rank)
        animateEntry(entry)
    end
end

PopulateLeaderboard.Populate()

return PopulateLeaderboard
