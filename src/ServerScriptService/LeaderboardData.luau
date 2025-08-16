-- ServerScriptService/LeaderboardData.lua (fixed, low-GetAsync)
-- Goal: Minimize DataStore reads by using write-through indexing and payload-by-key.
-- - Global recent feed index: OrderedDataStore keyed as "<timestamp>_<userId>" -> value = timestamp
-- - Payload store: standard DataStore, key "<timestamp>_<userId>" -> full purchase record table
-- - Top spenders: OrderedDataStore updated via UpdateAsync (no prior GetAsync)

local DataStoreService = game:GetService("DataStoreService")

-- DataStores
local RECENT_PAYLOAD_DS = DataStoreService:GetDataStore("RecentPurchasePayloads") -- payloads by composite key
local RECENT_INDEX_DS   = DataStoreService:GetOrderedDataStore("RecentPurchaseIndex") -- sorted feed
local TOP_SPENDERS_DS   = DataStoreService:GetOrderedDataStore("TopSpenders") -- totals by userId

-- Configuration
local MAX_RECENT = 25
local CLEANUP_INTERVAL_SECONDS = 12 * 60 * 60 -- 12 hours
local CLEANUP_RETENTION_DAYS = 30

-- Internals
local purchaseCooldown: { [number]: number } = {}
local cleanupActive = false

local function key_composite(timestamp: number, userId: number): string
    -- Always string; keep short ASCII
    return ("%d_%d"):format(timestamp, userId)
end

local function safeNumber(n: any, default: number): number
    if typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge then
        return n
    end
    return default
end

local function withRetries(fn, maxRetries: number)
    local tries = 0
    local ok, res, err
    repeat
        ok, res = pcall(fn)
        if ok then return true, res end
        err = res
        tries += 1
        task.wait(0.6 * tries)
    until tries >= maxRetries
    return false, err
end

local LeaderboardData = {}

-- Public API: RecordPurchase
function LeaderboardData.RecordPurchase(userId: number, playerName: string, itemName: string, price: number)
    -- Cooldown
    local now = os.time()
    if purchaseCooldown[userId] and (now - purchaseCooldown[userId]) < 2 then
        warn("[LeaderboardData] Purchase cooldown for userId", userId)
        return
    end
    purchaseCooldown[userId] = now

    -- Validate inputs
    userId = tonumber(userId) or 0
    price = safeNumber(price, 0)
    if userId <= 0 or price <= 0 then
        warn("[LeaderboardData] Invalid userId or price")
        return
    end

    local ts = now
    local ckey = key_composite(ts, userId)

    -- Build payload once
    local payload = {
        userId = userId,
        name = tostring(playerName or ""),
        item = tostring(itemName or ""),
        price = price,
        timestamp = ts,
    }

    -- Write-through:
    -- 1) Write payload by composite key (single SetAsync)
    -- 2) Insert index entry into ordered DS with value = timestamp (single SetAsync)
    -- 3) Update top spenders via UpdateAsync (no GetAsync)
    do
        local ok1, err1 = withRetries(function()
            return RECENT_PAYLOAD_DS:SetAsync(ckey, payload)
        end, 3)
        if not ok1 then
            warn("[LeaderboardData] Failed to write payload:", ckey, err1)
            -- Still attempt index/top so feed not blocked; payload miss would be rare
        end

        local ok2, err2 = withRetries(function()
            return RECENT_INDEX_DS:SetAsync(ckey, ts)
        end, 3)
        if not ok2 then
            warn("[LeaderboardData] Failed to write index:", ckey, err2)
        end

        local ok3, err3 = withRetries(function()
            return TOP_SPENDERS_DS:UpdateAsync(tostring(userId), function(oldValue)
                local prev = safeNumber(oldValue or 0, 0)
                return prev + price
            end)
        end, 3)
        if not ok3 then
            warn("[LeaderboardData] Failed to update top spender:", userId, err3)
        end
    end
end

-- Public API: Get recent purchases for one user (reads at most MAX_RECENT payload keys for that user)
-- Note: With new model, per-user recent requires scanning global index and filtering minimal amount.
function LeaderboardData.GetRecentPurchases(userId: number)
    userId = tonumber(userId) or 0
    if userId <= 0 then return {} end

    -- Fetch some recent index entries and filter for this user until we gather up to MAX_RECENT
    local ok, pages = pcall(function()
        return RECENT_INDEX_DS:GetSortedAsync(false, 100) -- pull 100 latest keys; adjust if needed
    end)
    if not ok or not pages then
        return {}
    end

    local page = pages:GetCurrentPage()
    local results = {}
    for _, entry in ipairs(page) do
        local tsStr, uidStr = tostring(entry.key):match("^(%d+)_(%d+)$")
        if tsStr and uidStr and tonumber(uidStr) == userId then
            local ckey = entry.key
            local okLoad, rec = pcall(function()
                return RECENT_PAYLOAD_DS:GetAsync(ckey)
            end)
            if okLoad and rec then
                table.insert(results, rec)
                if #results >= MAX_RECENT then
                    break
                end
            end
        end
    end

    -- If not enough, optionally scan next page(s). Keep lightweight to avoid many calls.
    while #results < MAX_RECENT and pages.IsFinished ~= true do
        local okAdv = pcall(function() pages:AdvanceToNextPageAsync() end)
        if not okAdv then break end
        page = pages:GetCurrentPage()
        if not page or #page == 0 then break end
        for _, entry in ipairs(page) do
            local tsStr, uidStr = tostring(entry.key):match("^(%d+)_(%d+)$")
            if tsStr and uidStr and tonumber(uidStr) == userId then
                local ckey = entry.key
                local okLoad, rec = pcall(function()
                    return RECENT_PAYLOAD_DS:GetAsync(ckey)
                end)
                if okLoad and rec then
                    table.insert(results, rec)
                    if #results >= MAX_RECENT then
                        break
                    end
                end
            end
        end
        if #results >= MAX_RECENT then
            break
        end
    end

    return results
end

-- Public API: Global feed (fast) — only MAX_RECENT GetAsync calls total (not N per user)
function LeaderboardData.GetAllRecentPurchases()
    local ok, pages = pcall(function()
        return RECENT_INDEX_DS:GetSortedAsync(false, MAX_RECENT)
    end)
    if not ok or not pages then
        return {}
    end

    local feed = {}
    for _, entry in ipairs(pages:GetCurrentPage()) do
        local ckey = tostring(entry.key)
        local okLoad, rec = pcall(function()
            return RECENT_PAYLOAD_DS:GetAsync(ckey)
        end)
        if okLoad and rec then
            table.insert(feed, rec)
        end
    end

    return feed
end

-- Public API: Top spenders
function LeaderboardData.GetTopSpenders(limit: number?)
    local lim = tonumber(limit) or MAX_RECENT
    lim = math.clamp(lim, 1, 100) -- limit to 100 for performance
    local ok, pages = pcall(function()
        return TOP_SPENDERS_DS:GetSortedAsync(false, lim)
    end)
    if not ok or not pages then
        return {}
    end

    local top = {}
    for _, entry in ipairs(pages:GetCurrentPage()) do
        local uid = tonumber(entry.key)
        local amount = safeNumber(entry.value, 0)
        table.insert(top, { userId = uid, amount = amount })
    end
    return top
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
            if not cur or #cur == 0 then break end
            for _, entry in ipairs(cur) do
                local key = tostring(entry.key)
                -- remove index
                RECENT_INDEX_DS:RemoveAsync(key)
                -- remove payload
                RECENT_PAYLOAD_DS:RemoveAsync(key)
            end
            local okAdv = pcall(function() pages:AdvanceToNextPageAsync() end)
            if not okAdv then break end
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
                local _ok1, err1 = pcall(function() RECENT_INDEX_DS:RemoveAsync(key) end)
                if not _ok1 then warn("[LeaderboardData] Cleanup remove index err", err1) end
                local _ok2, err2 = pcall(function() RECENT_PAYLOAD_DS:RemoveAsync(key) end)
                if not _ok2 then warn("[LeaderboardData] Cleanup remove payload err", err2) end
            else
                -- Reached newer entries; since sorted descending, we can stop
                cleanupActive = false
                return
            end
        end

        local okAdv, _ = pcall(function() return pages:AdvanceToNextPageAsync() end)
        if not okAdv then break end
        if pages.IsFinished then break end
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

return LeaderboardData
