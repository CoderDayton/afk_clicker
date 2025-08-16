local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local AFKPointConfig = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointConfig)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local _FriendUtils
local _AFKPointEngine

local AFKPointUtils = {}

-- ========= Remote Signals =========

local ConsumableUpdateSignal = RemoteSignal.new("ConsumableUpdate")

-- ========= Cache =========

local gamepassCache = {} -- [userId][gamepassId] = true
local activeBoosts = {} -- [userId][consumableName] = { expiration, value, minigameMultiplier }

local function refreshPlayerMultipliers(player)
	_AFKPointEngine = _AFKPointEngine or require(ServerScriptService.AFKSystem.AFKPointEngine)
	_AFKPointEngine.RefreshPlayerMultipliers(player)
end

function AFKPointUtils.CheckGamepass(player, gamepassName)
	local userId = player.UserId
	local gamepassId = AFKPointConfig.Gamepasses[gamepassName] and AFKPointConfig.Gamepasses[gamepassName].GamepassId
	if not gamepassId then
		warn("Unknown gamepass: " .. tostring(gamepassName))
		return false
	end
	gamepassCache[userId] = gamepassCache[userId] or {}
	if gamepassCache[userId][gamepassId] ~= nil then
		return gamepassCache[userId][gamepassId]
	end

	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
	end)
	gamepassCache[userId][gamepassId] = success and hasGamepass
	return hasGamepass
end

-- Activate (or extend) a consumable boost for a player
function AFKPointUtils.AddConsumable(player, consumableName)
	local info = AFKPointConfig.Consumables[consumableName]
	if not info then
		warn("Unknown consumable boost: " .. tostring(consumableName))
		return false
	end

	local userId = player.UserId
	activeBoosts[userId] = activeBoosts[userId] or {}
	local now = os.time()
	local duration = info.Duration or 0
	local expireTime = now + duration

	local fields = {
		ShardMultiplier = info.Features and info.Features.ShardMultiplier or nil,
		MinigameMultiplier = info.Features and info.Features.MinigameMultiplier or nil,
	}

	local existing = activeBoosts[userId][consumableName]
	if existing and existing.expiration and now < existing.expiration then
		-- Extend expiration only, but always update all fields!
		existing.expiration = existing.expiration + duration
		for k, v in pairs(fields) do
			existing[k] = v
		end
		ConsumableUpdateSignal:FireTo(player, AFKPointUtils.GetActiveConsumables(player))
	else
		activeBoosts[userId][consumableName] = {
			expiration = expireTime,
			ShardMultiplier = fields.ShardMultiplier,
			MinigameMultiplier = fields.MinigameMultiplier,
		}
		ConsumableUpdateSignal:FireTo(player, AFKPointUtils.GetActiveConsumables(player))
	end

	refreshPlayerMultipliers(player)

	return activeBoosts[userId][consumableName]
end

function AFKPointUtils.HasConsumable(player, consumableName)
	local userId = player.UserId
	return activeBoosts[userId] and activeBoosts[userId][consumableName] ~= nil
end

function AFKPointUtils.RemoveConsumable(player, consumableName)
	local userId = player.UserId
	if activeBoosts[userId] and activeBoosts[userId][consumableName] then
		activeBoosts[userId][consumableName] = nil
		refreshPlayerMultipliers(player)
		return true
	end
	return false
end

function AFKPointUtils.GetActiveConsumables(player)
	local userId = player.UserId
	if not activeBoosts[userId] then
		return {}
	end

	local now = os.time()
	local list = {}
	for consumableName, data in pairs(activeBoosts[userId]) do
		if data.expiration and now < data.expiration then
			table.insert(list, {
				Name = consumableName,
				Icon = AFKPointConfig.Consumables[consumableName] and AFKPointConfig.Consumables[consumableName].Icon,
				EndsAt = data.expiration,
				Duration = data.expiration - now,
			})
		end
	end
	return list
end

function AFKPointUtils.GetGamepassMultiplier(player)
	local mult = 1

	-- 1. Find all exclusive groups
	local exclusiveGroups = {}
	for passName, passData in pairs(AFKPointConfig.Gamepasses) do
		if passData.BoundTo then
			exclusiveGroups[passData.BoundTo] = exclusiveGroups[passData.BoundTo] or {}
			table.insert(exclusiveGroups[passData.BoundTo], {
				Name = passName,
				Data = passData,
			})
		end
	end

	-- 2. Check each group for the highest multiplier
	for _, groupData in pairs(exclusiveGroups) do
		local highestMultiplier = 1
		for _, passInfo in ipairs(groupData) do
			if AFKPointUtils.CheckGamepass(player, passInfo.Name) then
				if passInfo.Data.Features and passInfo.Data.Features.ShardMultiplier then
					highestMultiplier = math.max(highestMultiplier, passInfo.Data.Features.ShardMultiplier)
				end
			end
		end
		mult = mult * highestMultiplier
	end

	-- 3. Check for non-exclusive gamepasses
	for gamepassName, passData in pairs(AFKPointConfig.Gamepasses) do
		if not passData.BoundTo and AFKPointUtils.CheckGamepass(player, gamepassName) then
			if passData.Features and passData.Features.ShardMultiplier then
				mult = mult * passData.Features.ShardMultiplier
			end
		end
	end
	return mult
end

function AFKPointUtils.GetConsumableMultiplier(player)
	local mult = 1
	local userId = player.UserId
	if activeBoosts[userId] then
		local now = os.time()
		for consumableName, data in pairs(activeBoosts[userId]) do
			if data.expiration and now >= data.expiration then
				AFKPointUtils.RemoveConsumable(player, consumableName)
			elseif data.ShardMultiplier and (not data.expiration or data.expiration > now) then
				mult = mult * data.ShardMultiplier
			end
		end
	end
	return mult
end

function AFKPointUtils.GetFriendBonus(player)
	_FriendUtils = _FriendUtils or RR.get(game.ReplicatedStorage.AFKSystem.FriendUtils)
	local count = _FriendUtils.GetFriendCountInServer(player)
	local bonus = math.min(1 + (count * 0.1), AFKPointConfig.FriendBonusCap or 1.5)
	return bonus
end

-- Total multiplier for passive/click shards: gamepasses * boosts * capped friend bonus
function AFKPointUtils.GetShardMultiplier(player)
	local mult = 1
	mult = mult * AFKPointUtils.GetGamepassMultiplier(player)
	mult = mult * AFKPointUtils.GetConsumableMultiplier(player)
	if AFKPointUtils.HasPremium(player) then
		local boost = AFKPointConfig.Boosts["Premium"]
		local premiumMult = boost and boost.Features and boost.Features.ShardMultiplier or 1
		mult = mult * premiumMult
	end

	local friendMult = AFKPointUtils.GetFriendBonus(player)
	local cap = AFKPointConfig.FriendBonusCap or 1.5
	if friendMult > cap then
		friendMult = cap
	end

	mult = mult * friendMult

	return mult
end

-- Multiplier for minigame rewards: VIP + all active minigame boosts (uses Features.MinigameMultiplier)
function AFKPointUtils.GetMinigameMultiplier(player)
	local mult = 1

	-- VIP bonus
	local vipPass = AFKPointConfig.Gamepasses["VIP"]
	if vipPass and AFKPointUtils.CheckGamepass(player, "VIP") then
		if vipPass.Features and vipPass.Features.MinigameBonus then
			mult = mult * vipPass.Features.MinigameBonus
		end
	end

	-- Active minigame consumables
	local userId = player.UserId
	if activeBoosts[userId] then
		local now = os.time()
		for consumableName, data in pairs(activeBoosts[userId]) do
			if now >= data.expiration then
				activeBoosts[userId][consumableName] = nil
				AFKPointUtils.RemoveConsumable(player, consumableName)
			elseif data.MinigameMultiplier then
				mult = mult * data.MinigameMultiplier
			end
		end
	end

	return mult
end

-- Multiplier for how much faster a player receives AFK ticks (lower = faster)
function AFKPointUtils.GetIntervalMultiplier(player)
	local mult = 1
	for gamepassName, info in pairs(AFKPointConfig.Gamepasses) do
		if info.Features and info.Features.IntervalMultiplier then
			if AFKPointUtils.CheckGamepass(player, gamepassName) then
				mult = mult * info.Features.IntervalMultiplier
			end
		end
	end
	return mult
end

-- Returns true if player is VIP (owns the VIP gamepass)
function AFKPointUtils.IsVIP(player)
	local vipPass = AFKPointConfig.Gamepasses["VIP"]
	if not vipPass then
		return false
	end
	return AFKPointUtils.CheckGamepass(player, "VIP")
end

-- Returns true if player has Premium
function AFKPointUtils.HasPremium(player)
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Returns VIP chat tag if VIP, otherwise nil
function AFKPointUtils.GetChatTag(player)
	local vipPass = AFKPointConfig.Gamepasses["VIP"]
	if not vipPass then
		return nil
	end
	if AFKPointUtils.CheckGamepass(player, "VIP") then
		return vipPass.Features and vipPass.Features.ChatTag or nil
	end
	return nil
end

-- Returns VIP shop discount percent (int), or 0 if not VIP
function AFKPointUtils.GetDiscount(player)
	local vipPass = AFKPointConfig.Gamepasses["VIP"]
	if not vipPass then
		return 0
	end
	if AFKPointUtils.CheckGamepass(player, "VIP") then
		return vipPass.Features and vipPass.Features.DiscountPercent or 0
	end
	return 0
end

function AFKPointUtils.CleanupPlayer(player)
	local userId = player and player.UserId
	if not userId then
		return
	end
	activeBoosts[userId] = nil -- Clear active boosts
	gamepassCache[userId] = nil -- Clear gamepass cache
end

function AFKPointUtils.GetPlayerClickRate(player)
	-- Base click rate is from config (manual clicking)
	local rate = AFKPointConfig.MaxClicksPerSecond or 5

	-- Auto-Clicker Gamepass check
	if AFKPointUtils.CheckGamepass(player, "Auto Clicker") then
		rate = AFKPointConfig.Gamepasses["Auto Clicker"].Features.ClickRate or rate
		-- VIP stacking
		if AFKPointUtils.CheckGamepass(player, "VIP") then
			rate = rate * (AFKPointConfig.Gamepasses["VIP"].Features.AutoClickerMultiplier or 1)
		end
		-- Use math.floor for robustness
		rate = math.floor(rate)
	end

	-- Safety: Cap at reasonable maximum (anti-exploit)
	rate = math.clamp(rate, 1, 100)
	return rate
end

return AFKPointUtils
