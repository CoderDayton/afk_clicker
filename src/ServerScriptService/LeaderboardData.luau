local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RR = require(ReplicatedStorage.Utils.RobustRequire)
local Resilience = RR.get("ReplicatedStorage.Utils.Resilience")

-- DataStores
local RECENT_PAYLOAD_DS = DataStoreService:GetDataStore("RecentPurchasePayloads") -- payloads by composite key
local RECENT_INDEX_DS = DataStoreService:GetOrderedDataStore("RecentPurchaseIndex") -- sorted feed
local TOP_SPENDERS_DS = DataStoreService:GetOrderedDataStore("TopSpenders") -- totals by userId

-- Configuration
local MAX_RECENT = 25
local CLEANUP_INTERVAL_SECONDS = 12 * 60 * 60 -- 12 hours
local CLEANUP_RETENTION_DAYS = 30
local CACHE_TTL = 60 -- 1 minute
local MAX_CACHE_SIZE = 100

-- Memoization System
local MEMO_CACHE = {}
local PURGE_CHUNK = 10
local purchaseCooldown: { [number]: number } = {}
local cleanupActive = false

-- Top Spender Cache
local TOP_SPENDERS_CACHE = {}
local LAST_TOP_UPDATE = 0
local TOP_CACHE_TTL = 30 -- Seconds

local function key_composite(timestamp: number, userId: number): string
	-- Always string; keep short ASCII
	return ("%d_%d"):format(timestamp, userId)
end

local function safeNumber(n: any, default: number): number
	return (type(n) == "number" and n == n) and n or default
end

local function cleanupCache()
	local now = os.time()
	local candidates = {}
	local count = 0

	for userId, entry in pairs(MEMO_CACHE) do
        count += 1
		if now - entry.lastUpdated > CACHE_TTL or count > MAX_CACHE_SIZE then
			table.insert(candidates, userId)
		end
	end

	table.sort(candidates, function(a, b)
		return MEMO_CACHE[a].lastUpdated < MEMO_CACHE[b].lastUpdated
	end)

	for i = 1, math.min(PURGE_CHUNK, #candidates) do
		MEMO_CACHE[candidates[i]] = nil
	end
end

local function batchGetPayloads(keys)
	local payloads = {}
	for _, key in ipairs(keys) do
		local success, result = Resilience.RetryWithBackoff(3, function()
			return RECENT_PAYLOAD_DS:GetAsync(key)
		end)
		if success then
			table.insert(payloads, result)
		end
	end
	return payloads
end

local LeaderboardData = {}

-- Public API: RecordPurchase
function LeaderboardData.RecordPurchase(userId, playerName, itemName, price)
	local now = os.time()
	userId = tonumber(userId) or 0
	price = safeNumber(price, 0)

	-- Validation
	if userId <= 0 or price <= 0 then
		return
	end
	if purchaseCooldown[userId] and (now - purchaseCooldown[userId]) < 2 then
		warn("[Cooldown] ", userId)
		return
	end
	purchaseCooldown[userId] = now

	-- Atomic writes using only existing resilience methods
	local ckey = key_composite(now, userId)
	local payload = {
		userId = userId,
		name = tostring(playerName),
		item = tostring(itemName),
		price = price,
		timestamp = now,
	}

	-- Async writes with coroutine wrapping
	coroutine.wrap(function()
		local success1 = Resilience.RetryWithBackoff(3, function()
			return RECENT_PAYLOAD_DS:SetAsync(ckey, payload)
		end)
		local success2 = Resilience.RetryWithBackoff(3, function()
			return RECENT_INDEX_DS:SetAsync(ckey, now)
		end)
		local success3 = Resilience.RetryWithBackoff(3, function()
			return TOP_SPENDERS_DS:UpdateAsync(tostring(userId), function(old)
				return (tonumber(old) or 0) + price
			end)
		end)

		if not (success1 and success2 and success3) then
			warn("Partial failure in purchase recording")
		end
	end)()
end

-- Public API: Get recent purchases for one user (reads at most MAX_RECENT payload keys for that user)
-- Note: With new model, per-user recent requires scanning global index and filtering minimal amount.
function LeaderboardData.GetRecentPurchases(userId)
	userId = tonumber(userId) or 0
	if userId <= 0 then
		return {}
	end

	-- Cache check and cleanup
	cleanupCache()
	if MEMO_CACHE[userId] then
		return table.clone(MEMO_CACHE[userId].data)
	end

	-- Key collection
	local keys = {}
	local pages, success = Resilience.RetryWithBackoff(3, function()
		return RECENT_INDEX_DS:GetSortedAsync(false, 100)
	end)
	if not success then
		return {}
	end

	local page = pages:GetCurrentPage()
	for _, entry in ipairs(page) do
		if #keys >= MAX_RECENT then
			break
		end
		local _, uidStr = entry.key:match("_(%d+)$")
		if uidStr and tonumber(uidStr) == userId then
			table.insert(keys, entry.key)
		end
	end

	while #keys < MAX_RECENT and pages.IsFinished ~= true do
		local successAdv = Resilience.RetryWithBackoff(3, function()
			return pages:AdvanceToNextPageAsync()
		end)
		if not successAdv then
			break
		end

		for _, entry in ipairs(pages:GetCurrentPage()) do
			if #keys >= MAX_RECENT then
				break
			end
			local _, uidStr = entry.key:match("_(%d+)$")
			if uidStr and tonumber(uidStr) == userId then
				table.insert(keys, entry.key)
			end
		end
	end

	-- Batch get and cache
	local payloads = batchGetPayloads(keys)
	MEMO_CACHE[userId] = {
		lastUpdated = os.time(),
		data = table.clone(payloads),
	}

    LAST_TOP_UPDATE = 0 -- Force cache refresh

	return payloads
end

-- Public API: Global feed (fast) — only MAX_RECENT GetAsync calls total (not N per user)
function LeaderboardData.GetAllRecentPurchases()
	-- Batch fetch all keys first
	local keys = table.create(MAX_RECENT)
	local success, pages = Resilience.RetryWithBackoff(3, function()
		return RECENT_INDEX_DS:GetSortedAsync(false, MAX_RECENT)
	end)

	if not success or not pages then
		return {}
	end

	-- Extract keys in one pass
	local currentPage = pages:GetCurrentPage()
	for i = 1, math.min(#currentPage, MAX_RECENT) do
		keys[i] = tostring(currentPage[i].key)
	end

	-- Batch load payloads with resilience
	local feed = table.create(#keys)
	for i, key in ipairs(keys) do
		local payloadSuccess, payload = Resilience.RetryWithBackoff(2, function()
			return RECENT_PAYLOAD_DS:GetAsync(key)
		end)

		if payloadSuccess and payload then
			feed[i] = payload
		end
	end

	-- Filter nil entries and maintain order
	local cleanFeed = table.create(#feed)
	local count = 0
	for _, v in ipairs(feed) do
		if v then
			count += 1
			cleanFeed[count] = v
		end
	end

	return cleanFeed
end

-- Public API: Top spenders
function LeaderboardData.GetTopSpenders(limit)
	local now = os.time()

	-- Refresh cache if stale
	if now - LAST_TOP_UPDATE > TOP_CACHE_TTL then
		local success, pages = Resilience.RetryWithBackoff(3, function()
			return TOP_SPENDERS_DS:GetSortedAsync(false, 100)
		end)

		if success and pages then
			local entries = pages:GetCurrentPage()
			TOP_SPENDERS_CACHE = table.create(#entries)
			for i, entry in ipairs(entries) do
				TOP_SPENDERS_CACHE[i] = {
					userId = tonumber(entry.key) or 0,
					amount = safeNumber(entry.value, 0),
				}
			end
			LAST_TOP_UPDATE = now
		end
	end

	-- Return sliced cache
	local lim = math.clamp(tonumber(limit) or MAX_RECENT, 1, 100)
	return table.move(TOP_SPENDERS_CACHE, 1, lim, 1, table.create(lim))
end

-- Admin: ClearAll (careful in production)
function LeaderboardData.ClearAll()
	-- Clear top spenders (limited page)
	pcall(function()
		local page = TOP_SPENDERS_DS:GetSortedAsync(false, 100):GetCurrentPage()
		for _, entry in ipairs(page) do
			TOP_SPENDERS_DS:RemoveAsync(entry.key)
		end
	end)

	-- Clear recent index and payloads (walk a few pages)
	pcall(function()
		local pages = RECENT_INDEX_DS:GetSortedAsync(false, 100)
		repeat
			local cur = pages:GetCurrentPage()
			if not cur or #cur == 0 then
				break
			end
			for _, entry in ipairs(cur) do
				local key = tostring(entry.key)
				-- remove index
				RECENT_INDEX_DS:RemoveAsync(key)
				-- remove payload
				RECENT_PAYLOAD_DS:RemoveAsync(key)
			end
			local okAdv = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)
			if not okAdv then
				break
			end
		until pages.IsFinished
	end)
end

-- Maintenance: cleanup old index + payloads
function LeaderboardData.CleanupOldIndexEntries(daysOld: number)
	if cleanupActive then
		warn("[LeaderboardData] Cleanup already active")
		return
	end
	cleanupActive = true

	local cutoff = os.time() - (math.max(1, daysOld) * 24 * 60 * 60)

	local ok, pages = pcall(function()
		return RECENT_INDEX_DS:GetSortedAsync(false, 100) -- fetch up to 100 entries. MAX.
	end)
	if not ok or not pages then
		warn("[LeaderboardData] Cleanup fetch failed")
		cleanupActive = false
		return
	end

	while true do
		local cur = pages:GetCurrentPage()
		if not cur or #cur == 0 then
			break
		end

		for _, entry in ipairs(cur) do
			local key = tostring(entry.key)
			local tsStr = key:match("^(%d+)")
			local ts = tonumber(tsStr or "0") or 0
			if ts < cutoff then
				-- old -> remove index and payload
				local _ok1, err1 = pcall(function()
					RECENT_INDEX_DS:RemoveAsync(key)
				end)
				if not _ok1 then
					warn("[LeaderboardData] Cleanup remove index err", err1)
				end
				local _ok2, err2 = pcall(function()
					RECENT_PAYLOAD_DS:RemoveAsync(key)
				end)
				if not _ok2 then
					warn("[LeaderboardData] Cleanup remove payload err", err2)
				end
			else
				-- Reached newer entries; since sorted descending, we can stop
				cleanupActive = false
				return
			end
		end

		local okAdv, _ = pcall(function()
			return pages:AdvanceToNextPageAsync()
		end)
		if not okAdv then
			break
		end
		if pages.IsFinished then
			break
		end
		task.wait(0.05)
	end

	cleanupActive = false
end

function LeaderboardData.IsCleanupActive()
	return cleanupActive
end

-- Auto-clean loop (yields safely)
task.spawn(function()
	while true do
		local ok = pcall(function()
			LeaderboardData.CleanupOldIndexEntries(CLEANUP_RETENTION_DAYS)
		end)
		if not ok then
			warn("[LeaderboardData] Cleanup task error")
		end
		task.wait(CLEANUP_INTERVAL_SECONDS)
	end
end)

function LeaderboardData.GetCacheStats()
    local count = 0
    for _ in pairs(MEMO_CACHE) do count += 1 end
    return {
        size = count,
        max_size = MAX_CACHE_SIZE,
        ttl = CACHE_TTL
    }
end

return LeaderboardData
