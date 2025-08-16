--!strict
--[[Resilience.luau
    Utility module for implementing resilience patterns like backoff and retry.
    Provides functions for exponential backoff delays, retry logic with backoff,
    and status coalescing for client-server communication.
]]

-- ========== Type Definitions =========
export type StatusPayload = {
    canClaim: boolean,
    streak: number,
    streakBroken: boolean,
    dayIndex: number,
}

-- ========== Constants =========

-- Constants for backoff strategy
local MAX_ATTEMPTS  = 5 -- Max retry attempts
local BACKOFF_START = 0.75 -- Initial backoff delay in seconds
local BACKOFF_GROW  = 2.0 -- Backoff growth factor
local BACKOFF_CAP   = 10.0 -- Max backoff cap in seconds
local JITTER_MAX    = 0.25 -- Max jitter in seconds

local Resilience = {}

-- ========== Backoff Functions =========
function Resilience.BackOffDelay(attempt: number): number
    local delay = BACKOFF_START * (BACKOFF_GROW ^ (attempt - 1))
    if delay > BACKOFF_CAP then
        delay = BACKOFF_CAP
    end
    local jitter = math.random() * JITTER_MAX
    return delay + jitter
end

function Resilience.RetryWithBackoff(maxAttempts: number, fn: () -> any): any
	local attempts = 0
    local lastError = nil

	while attempts < maxAttempts do
		local success, result = pcall(fn)

		if success then
			return true, result
		end

		attempts += 1
        lastError = result
		task.wait(Resilience.BackOffDelay(attempts))
	end

	return false, lastError
end

function Resilience.GetMaxAttempts(): number
    return MAX_ATTEMPTS
end

-- ========== Status Coalesce =========
function Resilience.StatusSig(payload: StatusPayload)
    return table.concat({
        tostring(payload.canClaim),
        tostring(payload.streak),
        tostring(payload.streakBroken),
        tostring(payload.dayIndex),
    }, "|")
end

return Resilience
