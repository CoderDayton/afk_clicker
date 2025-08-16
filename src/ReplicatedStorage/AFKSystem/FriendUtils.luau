local Players = game:GetService("Players")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local AFKPointEngine = RR.get("ServerScriptService.AFKSystem.AFKPointEngine")

local FriendUtils = {}

local friendCountCache = {} -- [userId] = count

-- Helper: Update ONLY the affected player's count
local function updatePlayerFriendCount(player)
	local userId = player.UserId
	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and player:IsFriendsWith(other.UserId) then
			count = count + 1
		end
	end
	AFKPointEngine.RefreshPlayerMultipliers(player)
	friendCountCache[userId] = count
end

-- Helper: For every mutual friend in server, increment THEIR count if the joiner is their friend
local function updateMutualFriendsOnJoin(newPlayer)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= newPlayer and other:IsFriendsWith(newPlayer.UserId) then
			friendCountCache[other.UserId] = (friendCountCache[other.UserId] or 0) + 1
		end
	end
end

-- When a player joins: update their count and any mutuals
Players.PlayerAdded:Connect(function(player)
	updatePlayerFriendCount(player)
	updateMutualFriendsOnJoin(player)
end)

-- When a player leaves: decrement friend counts of mutuals, remove self
Players.PlayerRemoving:Connect(function(leavingPlayer)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= leavingPlayer and other:IsFriendsWith(leavingPlayer.UserId) then
			friendCountCache[other.UserId] = math.max(0, (friendCountCache[other.UserId] or 1) - 1)
		end
	end
	friendCountCache[leavingPlayer.UserId] = nil
end)

-- Public: Get number of friends in server for a player (O(1))
function FriendUtils.GetFriendCountInServer(player)
	return friendCountCache[player.UserId] or 0
end

return FriendUtils
