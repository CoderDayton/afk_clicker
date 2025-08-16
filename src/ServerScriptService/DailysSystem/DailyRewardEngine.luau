--[[
    DailyRewardEngine.luau
    Handles daily reward claims, streak management, and player data persistence.
    This module provides the core logic for tracking daily streaks, awarding rewards,
    and saving player data to a DataStore.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local AFKPointConfig = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointConfig)
local AFKPointEngine = RR.get(game.ServerScriptService.AFKSystem.AFKPointEngine)
local AFKPointUtils = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointUtils)

local UtilsFolder = RR.get(game.ReplicatedStorage.Utils)
local Maid = RR.get(UtilsFolder.Maid)
local Resilience = RR.get(UtilsFolder.Resilience)
local Ticker = RR.get(UtilsFolder.Ticker)
local BadgeWorker = RR.get(UtilsFolder.BadgeWorker)
local TimeGuard = RR.get(UtilsFolder.TimeGuard)
local RequestGate = RR.get(UtilsFolder.RequestGate)
local Metrics = RR.get(UtilsFolder.Metrics)

local DailyRewardEngine = {}

-- ========= CONSTANTS =========
local ONE_DAY_IN_SECONDS = 86400
local GRACE_PERIOD = 60 * 60 * 2 -- 2h grace: allows late claim without streak reset.
local MAX_SAVES_PER_CYCLE = 3 -- Adjust this number as needed for your server's capacity
local TIME_BETWEEN_SAVES = 3 -- Time in seconds between each save operation

-- ========= REMOTE SIGNALS =========
-- Remote discipline: client requests claim; server validates; status pushes are server->client only.
local DailyRewardStatusSignal = RemoteSignal.new("DailyRewardStatus")
local DailyRewardClaimSignal = RemoteSignal.new("DailyRewardClaim")
local DailyRewardResultSignal = RemoteSignal.new("DailyRewardResult")

-- ========= CACHE =========
-- playerStreakData[userId] = { lastClaim: number (unix), streak: number }
local playerStreakData: { [number]: { lastClaim: number, streak: number } } = {}
local dirtySaves: { [number]: true } = {} -- Write queue flags (markDirty sets; autosave drains).
local playerMaids: { [number]: any } = {}
local savingNow: { [number]: boolean } = {} -- Reentrancy guard.
local lastStatusSig: { [number]: string } = {}
local claimGates: { [number]: any } = {} -- RequestGate instances per player

-- ========= DATASTORE =========
local StreakStore = DataStoreService:GetDataStore(AFKPointConfig.DailyStreakKey)

-- ========= HELPERS =========
local function keyFor(userId: number): string
	return tostring(userId)
end

local function getPlayerMaid(userId: number)
	if not playerMaids[userId] then
		playerMaids[userId] = Maid.new()
	end
	return playerMaids[userId]
end

local function markDirty(userId: number)
	dirtySaves[userId] = true
end

local function getDayIndex(streak: number, rewardCount: number): number
	if rewardCount <= 0 then
		return 1
	end
	local day = streak
	if day > rewardCount then
		day = day % rewardCount
		if day == 0 then
			day = rewardCount
		end
	end
	if day < 1 then
		day = 1
	end
	return day
end

-- shape: { lastClaim: number (unix), streak: number }
local function asStreak(v: any)
	local t = (type(v) == "table" and v) or {}
	local last = (type(t.lastClaim) == "number" and t.lastClaim) or 0
	local streak = (type(t.streak) == "number" and t.streak) or 0
	if last < 0 then
		last = 0
	end
	if streak < 0 then
		streak = 0
	end
	return { lastClaim = last, streak = streak }
end

local function mergeStreak(localRec: any, remoteRec: any)
	local localStreak = asStreak(localRec)
	local remoteStreak = asStreak(remoteRec)

	-- Prefer remote lastClaim if it's more recent.
	if remoteStreak.lastClaim > localStreak.lastClaim then
		localStreak.lastClaim = remoteStreak.lastClaim
	end

	-- Use max streak from both.
	localStreak.streak = math.max(localStreak.streak, remoteStreak.streak)

	return localStreak
end

-- ========= CORE LOAD =========
function DailyRewardEngine.LoadPlayerStreak(player: Player)
	local userId = player.UserId
	if playerStreakData[userId] then
		return -- Already loaded (avoid double GetAsync).
	end

	local success, data = pcall(function()
		return StreakStore:GetAsync(keyFor(userId))
	end)

	-- Initialize baseline if none.
	if success and data then
		playerStreakData[userId] = data
	else
		playerStreakData[userId] = {
			lastClaim = 0,
			streak = 0,
		}
	end

	DailyRewardEngine.UpdateClientStatus(player)
end

-- ========= STATUS PUSH =========
function DailyRewardEngine.UpdateClientStatus(player: Player, force: boolean?)
	local data = playerStreakData[player.UserId]
	if not data then
		return
	end

	local now = TimeGuard.now() -- Use TimeGuard for consistent time handling.
	local timeSinceClaim = math.max(0, now - data.lastClaim)

	-- Can claim exactly every 24h (strict gate).
	local canClaim = timeSinceClaim >= ONE_DAY_IN_SECONDS

	-- Streak broken if missed full day + grace window.
	local streakBroken = data.streak > 0 and timeSinceClaim >= (ONE_DAY_IN_SECONDS + GRACE_PERIOD)

	local effectiveStreak = streakBroken and 0 or data.streak
	local day = getDayIndex(effectiveStreak, #AFKPointConfig.DailyStreakRewards)
	local rewards = AFKPointConfig.DailyStreakRewards[day] or {}

	local payload = {
		canClaim = canClaim,
		streak = data.streak,
		streakBroken = streakBroken,
		rewards = rewards,
		dayIndex = day,
		nextClaimTime = data.lastClaim + ONE_DAY_IN_SECONDS,
	}

	local sig = Resilience.statusSig({
		canClaim = payload.canClaim,
		streak = payload.streak,
		streakBroken = payload.streakBroken,
		dayIndex = payload.dayIndex,
	})

	if force or lastStatusSig[player.UserId] ~= sig then
		lastStatusSig[player.UserId] = sig
		DailyRewardStatusSignal:FireTo(player, payload)
	end
end

-- ========= SAVE (SERIALIZED) =========
function DailyRewardEngine.SavePlayerStreak(userId: number)
	if savingNow[userId] then
		return false
	end
	savingNow[userId] = true

	local data = playerStreakData[userId]
	if not data then
		savingNow[userId] = nil
		return false
	end

	local key = keyFor(userId)
	local success, err = Resilience.RetryWithBackoff(Resilience.GetMaxAttempts(), function()
		StreakStore:UpdateAsync(key, function(existingData)
			-- Merge local and remote data.
			local mergedData = mergeStreak(data, existingData)

			-- Save merged data.
			if not mergedData then
				warn(string.format("[DailyRewardEngine] Failed to merge streak data for user %d", userId))
				return nil
			end
			playerStreakData[userId] = mergedData

			-- Return updated streak data.
			return mergedData
		end)
	end)

	savingNow[userId] = nil

	if success then
		dirtySaves[userId] = nil
		Metrics.inc("daily_reward.save_success")
	else
		warn(
			string.format(
				"[DailyRewardEngine] Save still failing for %d after %d attempts: %s",
				userId,
				Resilience.GetMaxAttempts(),
				err
			)
		)
		Metrics.inc("daily_reward.save_failure")
	end

	return success
end

-- ========= CLAIM =========
function DailyRewardEngine.ClaimDailyReward(player: Player)
	Metrics.inc("daily_reward.claim_attempts")

	local userId = player.UserId
	local data = playerStreakData[userId]
	if not data then
		DailyRewardResultSignal:FireTo(player, false, "No streak data found.")
		Metrics.inc("daily_reward.claim_no_data")
		return
	end

	local gate = claimGates[userId]
	if not gate then
		gate = RequestGate.new({
			cooldownSeconds = 0.5,
			idempotenceWindow = 3.0,
		})
		claimGates[userId] = gate
	end

	if gate:isRecentlySuccessful() then
		DailyRewardResultSignal:FireTo(player, false, "Reward already claimed.", {
			streak = data.streak,
			rewards = {},
			nextClaimTime = data.lastClaim + ONE_DAY_IN_SECONDS,
		})
		return
	end

	if not gate:canAttempt() then
		DailyRewardResultSignal:FireTo(player, false, "Please wait before claiming again.")
		Metrics.inc("daily_reward.claim_rate_limit")
		return
	end

	local now = TimeGuard.now()
	local timeSinceClaim = math.max(0, now - data.lastClaim)

	if timeSinceClaim < ONE_DAY_IN_SECONDS then
		DailyRewardResultSignal:FireTo(player, false, "You can only claim once every 24 hours.")
		Metrics.inc("daily_reward.claim_too_soon")
		return
	end

	-- Reset if exceeded grace.
	if data.streak > 0 and timeSinceClaim >= (ONE_DAY_IN_SECONDS + GRACE_PERIOD) then
		data.streak = 0
	end

	data.lastClaim = now
	data.streak += 1

	-- Cycle day index across reward table length.
	local day = getDayIndex(data.streak, #AFKPointConfig.DailyStreakRewards)
	local rewards = AFKPointConfig.DailyStreakRewards[day] or {}
	local rewardLog = {}

	for _, reward in ipairs(rewards) do
		if reward.Type == "Shards" then
			AFKPointEngine.AwardShards(player, reward.Amount)
			table.insert(rewardLog, { type = "Shards", amount = reward.Amount, desc = reward.Description })
			Metrics.inc("daily_reward.claim_shards", reward.Amount or 0)
		elseif reward.Type == "Consumable" then
			local success = AFKPointUtils.AddConsumable(player, reward.Consumable)
			table.insert(rewardLog, {
				type = "Consumable",
				name = reward.Consumable,
				success = success,
				desc = reward.Description,
			})
		elseif reward.Type == "Badge" then
			Metrics.inc("daily_reward.claim_badge")
			local id = reward.BadgeId or 0
			if id > 0 then
				BadgeWorker.grantBadge(player, id)
			end
			table.insert(rewardLog, { type = "Badge", id = reward.BadgeId, desc = reward.Description, queued = id > 0 })
		end
	end

	markDirty(userId)

	DailyRewardResultSignal:FireTo(player, true, "Reward claimed successfully", {
		streak = data.streak,
		rewards = rewardLog,
		nextClaimTime = data.lastClaim + ONE_DAY_IN_SECONDS,
	})

	DailyRewardEngine.UpdateClientStatus(player, true)
end

-- ========= ADMIN / DEBUG RESET =========
function DailyRewardEngine.ResetStreak(player: Player)
	local data = playerStreakData[player.UserId]
	if not data then
		return false
	end

	data.lastClaim = TimeGuard.now() -- Reset to now.
	data.streak = 0
	markDirty(player.UserId)
	DailyRewardEngine.UpdateClientStatus(player)
	return true
end

-- ========= PLAYER LIFECYCLE =========
function DailyRewardEngine.PlayerAdded(player: Player)
	DailyRewardEngine.LoadPlayerStreak(player)

	local userId = player.UserId
	local maid = getPlayerMaid(userId)

	claimGates[userId] = RequestGate.new({
        cooldownSeconds = 0.5,
        idempotenceWindow = 3.0,
    })

	local token = Ticker.start(60 * 5, function()
		if player and player.Parent then
			DailyRewardEngine.UpdateClientStatus(player)
		end
	end)

	maid:GiveTask(function()
		token.cancel()
	end)
end

function DailyRewardEngine.PlayerRemoving(player: Player)
	local userId = player.UserId

	if dirtySaves[userId] then
		DailyRewardEngine.SavePlayerStreak(userId)
	end

	playerStreakData[userId] = nil
	dirtySaves[userId] = nil
	lastStatusSig[userId] = nil
	claimGates[userId] = nil

	local maid = playerMaids[userId]
	if maid then
		maid:DoCleaning()
		playerMaids[userId] = nil
	end
end

Players.PlayerAdded:Connect(DailyRewardEngine.PlayerAdded)
Players.PlayerRemoving:Connect(DailyRewardEngine.PlayerRemoving)

-- ========= AUTOSAVE WORKER =========
-- Adjust MAX_SAVES_PER_CYCLE based on server capacity.
task.spawn(function()
	while true do
		local saves = 0
		for userId in pairs(dirtySaves) do
			if saves >= MAX_SAVES_PER_CYCLE then
				break
			end
			DailyRewardEngine.SavePlayerStreak(userId)
			saves += 1
		end
		task.wait(TIME_BETWEEN_SAVES)
	end
end)

-- ========= REMOTE BIND =========
DailyRewardClaimSignal:Connect(function(player)
	DailyRewardEngine.ClaimDailyReward(player)
end)

local _ = Ticker.start(60 * 5, function()
	Metrics.dump("[DailyReward]")
end)

return DailyRewardEngine
