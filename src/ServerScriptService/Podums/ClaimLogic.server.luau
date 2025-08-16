local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService") -- For jitter

local RT = require(game.ReplicatedStorage.Utils.RobustRequire)
local RequestGate = RT.get(game.ReplicatedStorage.Utils.RequestGate) -- Add this
local ClaimUtils = RT.get(game.ReplicatedStorage.Podiums.ClaimUtils)
local UIUtils = RT.get(game.ReplicatedStorage.Utils.UIUtils)

local debug = false -- Set to false in production

-- Marketplace request rate limits
local MARKETPLACE_GATE = RequestGate.new({
	requestsPerMinute = 150, -- Conservative limit to avoid 429s
	burstSize = 10, -- Allow small bursts
})

-- Product info cache with MUCH longer TTL
local productCache = {}
local CACHE_TTL = 300 -- 5 minutes - marketplace data rarely changes
local CACHE_REFRESH_TTL = 180 -- Refresh data before it expires (3 minutes)
local MAX_BACKOFF = 8 -- Maximum backoff in seconds

-- Add metrics collection
local metrics = {
	totalRequests = 0,
	cacheHits = 0,
	cacheMisses = 0,
	rateLimitHits = 0,
	failures = 0,
	lastFailTime = 0,
}

-- Fetch with caching, queuing, and exponential backoff
local function getCachedProductInfo(id, infoType, forceRefresh)
	infoType = infoType or Enum.InfoType.Asset
	local cacheKey = tostring(id) .. "_" .. tostring(infoType)
	local now = tick()
	local cached = productCache[cacheKey]

	-- Return from cache if valid and not forcing refresh
	if cached and not forceRefresh then
		local age = now - cached.timestamp
		if age < CACHE_TTL then
			metrics.cacheHits += 1
			return cached.info
		end
	end

	metrics.cacheMisses += 1
	metrics.totalRequests += 1

	-- Try to get through the rate limit gate
	if not MARKETPLACE_GATE:tryRequest() then
		metrics.rateLimitHits += 1
		-- If we can't make a request but have cached data, use it even if expired
		if cached then
			warn("Rate limited, using expired cache for " .. cacheKey)
			return cached.info
		end
		warn("Rate limited with no cached data for " .. cacheKey)
		return nil
	end

	-- Exponential backoff with jitter
	local attempts = 0
	local maxAttempts = 5
	local baseDelay = 1

	while attempts < maxAttempts do
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)

		if success and info then
			productCache[cacheKey] = {
				info = info,
				timestamp = now,
			}
			return info
		end

		-- Check if it's a rate limit error (429)
		if not success and tostring(info):match("429") then
			metrics.rateLimitHits += 1
			metrics.lastFailTime = now

			-- If we have cached data, use it even if expired
			if cached then
				warn("Rate limited (429), using expired cache for " .. cacheKey)
				return cached.info
			end
		end

		attempts += 1

		if attempts < maxAttempts then
			-- Exponential backoff with jitter
			local jitter = HttpService:GenerateGUID(false):sub(1, 8)
			local jitterValue = tonumber(jitter, 16) / 0xFFFFFFFF -- Convert to value between 0-1
			local delay = math.min(MAX_BACKOFF, baseDelay * (2 ^ (attempts - 1))) * (0.5 + jitterValue)

			task.wait(delay)
		end
	end

	metrics.failures += 1
	warn("Failed to get product info after " .. maxAttempts .. " attempts for " .. tostring(id))

	-- Last resort: return expired cache if available
	if cached then
		warn("Using very expired cache for " .. cacheKey)
		return cached.info
	end

	return nil
end

-- Proactive cache refresh function
local function refreshProductInfo(id, infoType)
	task.spawn(function()
		getCachedProductInfo(id, infoType, true)
	end)
end

-- Queue to manage billboard updates (prevent UI thrashing)
local updateQueue = {}
local isProcessingUpdates = false

local function queueBillboardUpdate(podiumData, info)
	table.insert(updateQueue, { podiumData = podiumData, info = info })

	if not isProcessingUpdates then
		isProcessingUpdates = true

		task.spawn(function()
			while #updateQueue > 0 do
				local update = table.remove(updateQueue, 1)

				if update.podiumData.updateBillboard and update.info then
					update.podiumData.updateBillboard(update.info)
				end

				-- Space out updates to prevent UI thrashing
				task.wait(0.1)
			end

			isProcessingUpdates = false
		end)
	end
end

-- Process all podiums
local limitedPodiums = {} -- Collect limited podiums for centralized updates
for pName, pConfig in pairs(ClaimUtils.GetPodiums()) do
	local podium = ClaimUtils.GetPodiumObject(pName)
	if not podium then
		warn("Podium not found in Workspace: " .. tostring(pName))
		continue
	end

	local claimPrompt = podium:FindFirstChild("ClaimTrigger")
		and podium.ClaimTrigger:FindFirstChildOfClass("ProximityPrompt")
	local billboardLabel = podium:FindFirstChild("TextHolder")
		and podium.TextHolder:FindFirstChild("BillboardGui")
		and podium.TextHolder.BillboardGui:FindFirstChildOfClass("TextLabel")
	local assetId = tonumber(pConfig.UGCAssetId)
	if not assetId then
		warn("No valid UGCAssetId for podium: " .. pName)
		continue
	end

	local initialInfo = getCachedProductInfo(assetId)
	if not initialInfo then
		continue
	end

	local isLimited = initialInfo.IsLimitedUnique
	local gamepassId = isLimited and tonumber(pConfig.GamepassId) or nil

	if isLimited and not gamepassId then
		warn("No GamepassId found for limited item at podium: " .. podium.Name)
		continue
	end

	-- Billboard update function
	local function updateBillboard(info)
		if not billboardLabel or billboardLabel.Text == "" then
			return
		end

		UIUtils.SetupOrUpdateBillboard(podium, pConfig, info)

		if claimPrompt and isLimited then
			local stock = info.Remaining or 0
			claimPrompt.Enabled = (stock > 0)
		end
	end

	updateBillboard(initialInfo)

	-- Collect for centralized updates if limited
	if isLimited then
		table.insert(limitedPodiums, {
			podium = podium,
			pConfig = pConfig,
			assetId = assetId,
			gamepassId = gamepassId,
			isLimited = isLimited,
			claimPrompt = claimPrompt,
			updateBillboard = updateBillboard,
			lastUpdated = tick(),
		})
	end

	if claimPrompt then
		claimPrompt.Triggered:Connect(function(player)
			-- Use the cached data unless it's getting stale
			local info = getCachedProductInfo(assetId)
			if not info then
				UIUtils.ShowFeedback(player, "Item temporarily unavailable. Try again soon.", { Type = "Error" })
				return
			end

			local liveStock = info.Remaining or 0

			-- Queue the update rather than doing it immediately
			queueBillboardUpdate({ updateBillboard = updateBillboard }, info)

			if isLimited and liveStock <= 0 then
				UIUtils.ShowFeedback(player, pConfig.SoldOutMessage, { Type = "Error" })
				return
			end

			local ownsUGC = false
			if ClaimUtils.CreatorUserId == player.UserId and debug then
				ownsUGC = false
			else
				ownsUGC = ClaimUtils.PlayerOwnsUGC(player, assetId)
			end
			if ownsUGC then
				UIUtils.ShowFeedback(player, pConfig.AlreadyClaimedMessage, { Type = "Error" })
				return
			end

			if isLimited then
				local ownsGamepass = false
				if ClaimUtils.CreatorUserId == player.UserId and debug then
					ownsGamepass = false
				else
					ownsGamepass = ClaimUtils.PlayerOwnsGamepass(player, gamepassId)
				end

				if not ownsGamepass then
					MarketplaceService:PromptGamePassPurchase(player, gamepassId)

					local conn
					conn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(
						function(playerId, purchasedGamepassId, wasPurchased)
							if playerId == player.UserId and purchasedGamepassId == gamepassId then
								if wasPurchased then
									-- Use cached data if available, only force refresh if critical
									local currentInfo = getCachedProductInfo(assetId)
									local currentStock = currentInfo and currentInfo.Remaining or 0
									if currentStock <= 0 then
										UIUtils.ShowFeedback(
											player,
											"The item just sold out! Tragic.",
											{ Type = "Error" }
										)
										queueBillboardUpdate({ updateBillboard = updateBillboard }, currentInfo)
										conn:Disconnect()
										return
									end

									-- Use cached gamepass info
									local priceInfo = getCachedProductInfo(gamepassId, Enum.InfoType.GamePass)
									local price = priceInfo and priceInfo.PriceInRobux or 0
									game.ReplicatedStorage.PurchaseMade:FireServer(player, pConfig.DisplayName, price)
									MarketplaceService:PromptPurchase(player, assetId)
									ClaimUtils.PlayClaimEffectAtPodium(podium)
									UIUtils.ShowFeedback(player, pConfig.ClaimMessage)

									-- After successful purchase, refresh in the background
									task.delay(5, function()
										refreshProductInfo(assetId)
									end)
								else
									UIUtils.ShowFeedback(
										player,
										"You need the gamepass to claim this item!",
										{ Type = "Error" }
									)
								end
								conn:Disconnect()
							end
						end
					)
					return
				end
			end

			MarketplaceService:PromptPurchase(player, assetId)

			-- After purchase prompt, refresh in the background
			task.delay(5, function()
				refreshProductInfo(assetId)
			end)
		end)
	end
end

-- Staggered update for limited podiums
task.spawn(function()
	-- Wait for initial setup to complete
	task.wait(5)

	while task.wait(5) do -- Check every 5 seconds, but don't update everything
		-- Check if we're already rate limited
		if tick() - metrics.lastFailTime < 60 then
			-- Back off if we hit rate limits recently
			task.wait(30)
			continue
		end

		-- Prioritize podiums that haven't been updated recently
		local now = tick()
		local updateCandidates = {}

		for _, data in ipairs(limitedPodiums) do
			local timeSinceUpdate = now - (data.lastUpdated or 0)

			if timeSinceUpdate > CACHE_REFRESH_TTL then
				table.insert(updateCandidates, {
					data = data,
					priority = timeSinceUpdate, -- Higher time = higher priority
				})
			end
		end

		-- Sort by priority (stalest first)
		table.sort(updateCandidates, function(a, b)
			return a.priority > b.priority
		end)

		-- Process top candidates (limited batch)
		local batchSize = math.min(3, #updateCandidates) -- Process max 3 at a time

		for i = 1, batchSize do
			local candidate = updateCandidates[i]
			if not candidate then
				break
			end

			local data = candidate.data

			-- Attempt to refresh info
			task.spawn(function()
				local info = getCachedProductInfo(data.assetId, nil, true) -- Force refresh
				if info then
					data.lastUpdated = now
					queueBillboardUpdate(data, info)
				end
			end)

			-- Space out requests to avoid bursts
			task.wait(2)
		end

		-- Print metrics every 5 minutes
		if now % 300 < 5 then
			print("===== Marketplace Metrics =====")
			print("Total requests: " .. metrics.totalRequests)
			print(
				"Cache hits: "
					.. metrics.cacheHits
					.. " ("
					.. math.floor(metrics.cacheHits / (metrics.cacheHits + metrics.cacheMisses) * 100)
					.. "%)"
			)
			print("Rate limit hits: " .. metrics.rateLimitHits)
			print("Failures: " .. metrics.failures)
			print("================================")
		end
	end
end)
