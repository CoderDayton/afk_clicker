local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)

local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)
local AFKPointConfig = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointConfig)
local AFKPointUtils = RR.get(game.ReplicatedStorage.AFKSystem.AFKPointUtils)

-- Maid integration
local Maid = RR.get(game.ReplicatedStorage.Utils.Maid)
local EngineMaid = Maid.new()

local AFKPointEngine = {}

local savingNow: { [number]: boolean } = {}

local function keyFor(userId: number): string
	return string.format("%s:%d", AFKPointConfig.DataStoreKey, userId)
end

local ShardStore = DataStoreService:GetDataStore(AFKPointConfig.DataStoreKey)

-- Session caches
local activePlayers: { [number]: Player } = {} -- [userId] = Player
local playerShards: { [number]: number } = {} -- [userId] = balance
local dirtySet: { [number]: true } = {} -- [userId] = true
local lastAutoAward: { [number]: number } = {} -- [userId] = time()

-- Cached multipliers
type MultCache = { interval: number, shard: number, clickRate: number }
local multCache: { [number]: MultCache } = {}

-- Buffered update queue
local pendingUpdate: { [number]: number } = {} -- [userId] = latest balance

-- Dirty queue (throttled saves)
local dirtyQueue: { number } = {}

local shuttingDown: boolean = false

-- Remotes
local ShardUpdateSignal = RemoteSignal.new("ShardUpdate")
local ShardSpendRequest = RemoteSignal.new("ShardSpendRequest")
local ShardSpendResult = RemoteSignal.new("ShardSpendResult")
local ShardBonusRequest = RemoteSignal.new("ShardBonusRequest")
local ShardBonusResult = RemoteSignal.new("ShardBonusResult")
local ShardMinigameRequest = RemoteSignal.new("ShardMinigameRequest")
local ShardMinigameResult = RemoteSignal.new("ShardMinigameResult")
local PlaySoundRemote = RemoteSignal.new("PlaySoundRemote")

-- Cooldowns
local spendCooldown: { [number]: number } = {}
local lastClickTime: { [number]: number } = {}
local minigameCooldown: { [number]: number } = {}

-- Utility
local function safeNumber(n: any, default: number): number
	if typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge then
		return n
	end
	return default
end

local function markDirty(userId: number)
	if not dirtySet[userId] then
		dirtySet[userId] = true
		table.insert(dirtyQueue, userId)
	end
end

local function refreshMultipliers(player: Player)
	local uid = player.UserId
	local ok1, interval = pcall(AFKPointUtils.GetIntervalMultiplier, player)
	local ok2, shard = pcall(AFKPointUtils.GetShardMultiplier, player)
	local ok3, clickRate = pcall(AFKPointUtils.GetPlayerClickRate, player)

	multCache[uid] = {
		interval = safeNumber(ok1 and interval or 1, 1),
		shard = safeNumber(ok2 and shard or 1, 1),
		clickRate = math.max(1, safeNumber(ok3 and clickRate or 4, 4)),
	}
end

-- AFKPointEngine API
function AFKPointEngine.RefreshPlayerMultipliers(player: Player)
	if player and player.Parent == Players then
		refreshMultipliers(player)
	end
end

-- Persistence
local function LoadShards(player: Player)
	local uid = player.UserId
	local dsKey = keyFor(uid)

	local retries = 0
	local result = 0

	while retries < 3 do
		local ok, val = pcall(function()
			return ShardStore:GetAsync(dsKey)
		end)
		if ok then
			result = safeNumber(val or 0, 0)
			break
		else
			retries += 1
			task.wait(0.7 * retries)
		end
	end

	playerShards[uid] = result
	pendingUpdate[uid] = result
end

local function SaveShards(userId: number): boolean
	if playerShards[userId] == nil then
		dirtySet[userId] = nil
		return true
	end
	if savingNow[userId] then
		return false -- another save is already running; let that finish
	end
	savingNow[userId] = true

	local dsKey = keyFor(userId)
	local valueToSave = playerShards[userId]
	local retries, success, lastErr = 0, false, nil

	while retries < 3 and not success do
		local ok, err = pcall(function()
			ShardStore:UpdateAsync(dsKey, function(old)
				local prev = safeNumber(old or 0, 0)
				return safeNumber(valueToSave, prev)
			end)
		end)
		if ok then
			success = true
		else
			lastErr = err
			retries += 1
			task.wait(0.7 * retries)
		end
	end

	if success then
		dirtySet[userId] = nil
	else
		warn("[AFKPointEngine] Save failed for", userId, lastErr)
	end

	savingNow[userId] = nil
	return success
end

-- Maid helpers
-- Player lifecycle
Players.PlayerAdded:Connect(function(player)
	local uid = player.UserId

	if shuttingDown then
		player:Kick("Server is shutting down, please rejoin later.")
		return
	end

	-- owner check
	if uid == 2006060772 then
		print("[AFKPointEngine] Owner detected, granting x2 Shards for 15 minutes.")
		AFKPointUtils.AddConsumable(player, "x2 Shards 15m")
	end

	activePlayers[uid] = player
	LoadShards(player)
	refreshMultipliers(player)
	lastAutoAward[uid] = time()
end)

Players.PlayerRemoving:Connect(function(player)
	local uid = player.UserId
	activePlayers[uid] = nil

	markDirty(uid)

	-- Only try an immediate save if one isn’t in flight
	local savedNow = false
	if not savingNow[uid] then
		savedNow = SaveShards(uid)
	end
	if savedNow then
		dirtySet[uid] = nil
		playerShards[uid] = nil
	end

	-- clear transient caches (unchanged)
	pendingUpdate[uid] = nil
	lastAutoAward[uid] = nil
	multCache[uid] = nil
	spendCooldown[uid] = nil
	lastClickTime[uid] = nil
	minigameCooldown[uid] = nil

	if AFKPointUtils and AFKPointUtils.CleanupPlayer then
		pcall(AFKPointUtils.CleanupPlayer, player)
	end
end)

game:BindToClose(function()
	shuttingDown = true

	-- Build final unique list (unchanged logic)
	local toSave: { number } = {}
	for uid in pairs(dirtySet) do
		table.insert(toSave, uid)
	end
	for uid in pairs(playerShards) do
		if not dirtySet[uid] then
			table.insert(toSave, uid)
		end
	end
	local seen, final = {}, {}
	for _, uid in ipairs(toSave) do
		if not seen[uid] then
			seen[uid] = true
			table.insert(final, uid)
		end
	end

	-- Save one-by-one with a slightly larger stagger to avoid queue pressure
	for _, uid in ipairs(final) do
		if not savingNow[uid] then
			SaveShards(uid)
		end
		task.wait(0.35)
	end

	pcall(function()
		EngineMaid:DoCleaning()
	end)
end)

-- Award loop
task.spawn(function()
	task.wait(1)
	while true do
		local now = time()
		for uid, plr in pairs(activePlayers) do
			if plr and plr.Parent == Players then
				local cache = multCache[uid]
				if not cache then
					refreshMultipliers(plr)
					cache = multCache[uid]
					if not cache then
						continue
					end
				end

				local baseInterval = AFKPointConfig.ShardInterval or 5
				local interval = math.max(0.1, baseInterval * (cache.interval or 1))
				local last = lastAutoAward[uid] or now

				if now - last >= interval then
					local base = AFKPointConfig.BaseShards or 1
					local shards = math.max(0, math.floor(base * (cache.shard or 1)))
					if shards > 0 then
						playerShards[uid] = (playerShards[uid] or 0) + shards
						pendingUpdate[uid] = playerShards[uid]
						markDirty(uid)
					end
					lastAutoAward[uid] = now
				end
			end
		end
		task.wait(0.5)
	end
end)

-- Buffered update flush
task.spawn(function()
	while true do
		for uid, balance in pairs(pendingUpdate) do
			local plr = activePlayers[uid]
			if plr and plr.Parent == Players then
				ShardUpdateSignal:FireTo(plr, balance)
			end
			pendingUpdate[uid] = nil
		end
		task.wait(0.3)
	end
end)

-- Public API
function AFKPointEngine.SpendShards(player: Player, amount: number): boolean
	local uid = player.UserId
	local amt = safeNumber(amount, -1)
	if amt <= 0 then
		return false
	end

	local cur = safeNumber(playerShards[uid] or 0, 0)
	if cur >= amt then
		playerShards[uid] = cur - amt
		pendingUpdate[uid] = playerShards[uid]
		markDirty(uid)
		return true
	end
	return false
end

function AFKPointEngine.GetShards(player: Player): number
	return safeNumber(playerShards[player.UserId] or 0, 0)
end

function AFKPointEngine.AwardShards(player: Player, amount: number): boolean
	local amt = safeNumber(amount, 0)
	if amt > 0 then
		local uid = player.UserId
		playerShards[uid] = safeNumber(playerShards[uid] or 0, 0) + amt
		pendingUpdate[uid] = playerShards[uid]
		markDirty(uid)
		return true
	end
	return false
end

local function awardBonusInternal(player: Player, action: string): number
	local uid = player.UserId
	local cache = multCache[uid]
	if not cache then
		refreshMultipliers(player)
		cache = multCache[uid]
	end

	local shardMult = (cache and cache.shard) or 1
	local baseTable = AFKPointConfig.BonusActions or {}
	local base = baseTable[action]
	if not base then
		return 0
	end

	local amount = math.max(0, math.floor(safeNumber(base, 0) * shardMult))
	if amount > 0 then
		playerShards[uid] = (playerShards[uid] or 0) + amount
		pendingUpdate[uid] = playerShards[uid]
		markDirty(uid)
		return amount
	end
	return 0
end

function AFKPointEngine.AwardBonus(player: Player, action: string): number
	return awardBonusInternal(player, action)
end

function AFKPointEngine.AwardMinigame(player: Player)
	local ok, mult = pcall(AFKPointUtils.GetMiniggameMultiplier or AFKPointUtils.GetMinigameMultiplier, player)
	local minigameMult = safeNumber(ok and mult or 1, 1)
	local base = (AFKPointConfig.BonusActions and AFKPointConfig.BonusActions.MinigameWin) or 10
	local award = math.max(0, math.floor(safeNumber(base, 10) * minigameMult))
	local uid = player.UserId

	if award > 0 then
		playerShards[uid] = (playerShards[uid] or 0) + award
		pendingUpdate[uid] = playerShards[uid]
		markDirty(uid)
	end
end

-- Save worker (throttled)
task.spawn(function()
	while true do
		if shuttingDown then
			return
		end
		local uid = table.remove(dirtyQueue, 1)
		if uid then
			if not savingNow[uid] then
				SaveShards(uid)
			end
		else
			task.wait(0.25)
		end
		task.wait(1.25)
	end
end)

-- Remote connections (wrapped with EngineMaid for global cleanup)
EngineMaid:GiveTask(ShardSpendRequest:Connect(function(player, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local uid = player.UserId
	local now = time()

	if spendCooldown[uid] and now - spendCooldown[uid] < 0.5 then
		ShardSpendResult:FireTo(player, false, AFKPointEngine.GetShards(player), "Please wait before spending again.")
		return
	end
	spendCooldown[uid] = now

	local amt = tonumber(amount)
	if not amt or amt <= 0 or amt ~= amt or amt == math.huge then
		ShardSpendResult:FireTo(player, false, AFKPointEngine.GetShards(player), "Invalid amount")
		return
	end

	local ok = AFKPointEngine.SpendShards(player, math.floor(amt))
	ShardSpendResult:FireTo(player, ok, AFKPointEngine.GetShards(player), ok and nil or "Not enough shards")
end))

EngineMaid:GiveTask(ShardBonusRequest:Connect(function(player, action)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if typeof(action) ~= "string" then
		ShardBonusResult:FireTo(player, false, AFKPointEngine.GetShards(player), "Invalid action")
		return
	end

	local uid = player.UserId
	local now = time()

	if action == "Click" then
		local mcache = multCache[uid]
		if not mcache then
			refreshMultipliers(player)
			mcache = multCache[uid]
		end

		local allowedRate = math.max(1, safeNumber(mcache and mcache.clickRate or 4, 4))
		local minInterval = 1 / allowedRate

		local last = lastClickTime[uid] or 0
		if now - last < minInterval then
			return -- silently ignore spam
		end

		lastClickTime[uid] = now
		PlaySoundRemote:FireTo(player, "ClickSound")
	end

	local gained = awardBonusInternal(player, action)
	ShardBonusResult:FireTo(player, true, AFKPointEngine.GetShards(player), "", gained)
end))

EngineMaid:GiveTask(ShardMinigameRequest:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local uid = player.UserId
	local now = time()

	if minigameCooldown[uid] and now - minigameCooldown[uid] < 3 then
		ShardMinigameResult:FireTo(
			player,
			false,
			AFKPointEngine.GetShards(player),
			"Please wait before claiming another minigame reward."
		)
		return
	end
	minigameCooldown[uid] = now

	AFKPointEngine.AwardMinigame(player)
	ShardMinigameResult:FireTo(player, true, AFKPointEngine.GetShards(player))
end))

return AFKPointEngine
