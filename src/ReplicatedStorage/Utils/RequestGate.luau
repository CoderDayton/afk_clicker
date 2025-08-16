--!strict
-- Rate limiting guard with per-minute caps, burst allowance, backoff, and idempotence tracking
-- Luna Protocol™ - Aggressive defense against API spam

local RequestGate = {}
RequestGate.__index = RequestGate

export type RateLimitConfig = {
    requestsPerMinute: number?, -- Max requests per minute (default: 60)
    burstSize: number?, -- How many requests can happen in burst (default: 5)
    cooldownSeconds: number?, -- Minimum time between individual requests (default: 0.1)
    jitterPercent: number?, -- Random jitter to prevent thundering herd (default: 15%)
    idempotenceWindow: number?, -- Seconds to consider the same request "already done" (default: 0)
}

export type Gate = {
    -- Config
    requestsPerMinute: number,
    burstSize: number,
    cooldownSeconds: number,
    jitterPercent: number,
    idempotenceWindow: number,

    -- State
    requestTimes: { number },
    lastRequestTime: number,
    consecutiveFailures: number,
    lastSuccess: number,
}

function RequestGate.new(config: RateLimitConfig): Gate
    -- No more legacy parameters - clean is better than dirty
    return setmetatable({
        -- Config with defaults
        requestsPerMinute = config.requestsPerMinute or 60,
        burstSize = config.burstSize or 5,
        cooldownSeconds = config.cooldownSeconds or 0.1,
        jitterPercent = config.jitterPercent or 15,
        idempotenceWindow = config.idempotenceWindow or 0,

        -- State
        requestTimes = {}, -- Sliding window of request timestamps
        lastRequestTime = 0,
        consecutiveFailures = 0,
        lastSuccess = -1e9, -- far past
    }, RequestGate)
end

-- Try to make a request through the gate
function RequestGate:tryRequest(): boolean
    local now = os.clock()

    -- 1. Check basic cooldown with jitter
    local jitterMultiplier = 1 + (math.random() * self.jitterPercent / 100)
    local effectiveCooldown = self.cooldownSeconds * jitterMultiplier

    if now - self.lastRequestTime < effectiveCooldown then
        return false
    end

    -- 2. Clean up old requests outside our minute window
    local oneMinuteAgo = now - 60
    local i = 1
    while i <= #self.requestTimes do
        if self.requestTimes[i] < oneMinuteAgo then
            table.remove(self.requestTimes, i)
        else
            i += 1
        end
    end

    -- 3. Check if we're exceeding our rate limit
    if #self.requestTimes >= self.requestsPerMinute then
        return false
    end

    -- 4. Check if we're exceeding burst
    local recentWindow = now - 1 -- Last second
    local recentCount = 0

    for _, t in ipairs(self.requestTimes) do
        if t > recentWindow then
            recentCount += 1
            if recentCount >= self.burstSize then
                return false
            end
        end
    end

    -- All checks passed, record this request
    self.lastRequestTime = now
    table.insert(self.requestTimes, now)
    return true
end

-- Record a successful request and reset backoff
function RequestGate:recordSuccess()
    self.lastSuccess = os.clock()
    self.consecutiveFailures = 0
end

-- Check if a previous request was recently successful (idempotence check)
function RequestGate:isRecentlySuccessful(): boolean
    return (os.clock() - self.lastSuccess) <= self.idempotenceWindow
end

-- Record a failed request to implement exponential backoff
function RequestGate:recordFailure()
    self.consecutiveFailures += 1

    -- Apply a temporary cooldown increase based on failure count
    local backoffSeconds = math.min(30, 0.5 * (2 ^ self.consecutiveFailures))
    self.lastRequestTime = os.clock() + backoffSeconds
end

-- Get metrics about this gate's performance
function RequestGate:getMetrics(): { [string]: any }
    local now = os.clock()
    local oneMinuteAgo = now - 60

    -- Count requests in various time windows
    local last60s = 0
    local last10s = 0
    local last1s = 0

    for _, t in ipairs(self.requestTimes) do
        if t > oneMinuteAgo then
            last60s += 1
            if t > now - 10 then
                last10s += 1
                if t > now - 1 then
                    last1s += 1
                end
            end
        end
    end

    return {
        requestsLastMinute = last60s,
        requestsLast10Seconds = last10s,
        requestsLastSecond = last1s,
        utilizationPercent = (last60s / self.requestsPerMinute) * 100,
        consecutiveFailures = self.consecutiveFailures,
        isBackingOff = self.lastRequestTime > now,
        backoffTimeRemaining = math.max(0, self.lastRequestTime - now),
        idempotenceActive = self:isRecentlySuccessful(),
        idempotenceTimeRemaining = math.max(0, (self.lastSuccess + self.idempotenceWindow) - now),
    }
end

return RequestGate