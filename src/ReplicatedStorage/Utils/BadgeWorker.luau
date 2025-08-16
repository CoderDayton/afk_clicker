--!strict
-- Server-only usage: queue + safely award badges with a few retries.

local BadgeService = game:GetService("BadgeService")

local UtilsFolder = script.Parent
local RR = require(UtilsFolder:WaitForChild("RobustRequire"))
local Resilience = RR.get(UtilsFolder.Resilience)

type Job = { userId: number, badgeId: number, attempts: number }

local BadgeWorker = {}
local _queue: { Job } = {}
local _running = false
local _recent: { [number]: { [number]: number } } = {} -- recent[userId][badgeId] = os.clock()

-- Don�t spam the same badge to the same user in a tiny window (double clicks, etc.)
local DEDUPE_SECONDS = 5

local function canEnqueue(userId: number, badgeId: number): boolean
	local byUser = _recent[userId]
	local now = os.clock()
	if byUser and byUser[badgeId] and (now - byUser[badgeId]) < DEDUPE_SECONDS then
		return false
	end
	_recent[userId] = byUser or {}
	_recent[userId][badgeId] = now
	return true
end

function BadgeWorker.enqueue(userId: number, badgeId: number)
	if not canEnqueue(userId, badgeId) then
		return false
	end
	table.insert(_queue, { userId = userId, badgeId = badgeId, attempts = 0 })
	if not _running then
		BadgeWorker._run()
	end
	return true
end

-- Internal: do one job
local function process(job: Job): boolean
	-- Optional: if player left, we can still try; Roblox allows AwardBadge by userId.
	-- If you prefer to require presence, uncomment the next 3 lines:
	-- if not Players:GetPlayerByUserId(job.userId) then
	--     return false
	-- end

	-- If they already have it, we�re done.
	local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, job.userId, job.badgeId)
	if not okHas then
		return false
	end
	if has then
		return true
	end

	-- Try to award with a few retries (handles brief service hiccups).
	local okAward, err = Resilience.RetryWithBackoff(Resilience.MAX_ATTEMPTS, function()
		BadgeService:AwardBadge(job.userId, job.badgeId)
	end)

	if not okAward then
		warn(("[BadgeWorker] Award failed u=%d b=%d: %s"):format(job.userId, job.badgeId, tostring(err)))
	end
	return okAward == true
end

function BadgeWorker._run()
	if _running then
		return
	end
	_running = true
	task.spawn(function()
		while #_queue > 0 do
			-- pop front
			local job = table.remove(_queue, 1)
			if job then
				local ok = process(job)
				if not ok then
					job.attempts += 1
					if job.attempts < Resilience.GetMaxAttempts() then
						-- requeue to try again later
						table.insert(_queue, job)
					else
						warn(
							("[BadgeWorker] Dropping job u=%d b=%d after %d attempts"):format(
								job.userId,
								job.badgeId,
								job.attempts
							)
						)
					end
				end
				-- small yield so we don�t hog the thread
				task.wait(0.1)
			end
		end
		_running = false
	end)
end

return BadgeWorker
