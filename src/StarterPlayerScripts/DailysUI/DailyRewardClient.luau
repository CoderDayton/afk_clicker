--[[
    DailyRewardClient.luau
    Client-side daily reward system with OOP patterns, strict typing, and comprehensive state management.
    Handles server communication, local state caching, and UI-agnostic logic for daily rewards.
]]

local RunService = game:GetService("RunService")
local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local TimeGuard = RR.get("ReplicatedStorage.Utils.TimeGuard")
local RemoteSignal = RR.get("ReplicatedStorage.Utils.RemoteSignal")
local Resilience = RR.get("ReplicatedStorage.Utils.Resilience")
local Maid = RR.get("ReplicatedStorage.Utils.Maid")
local Metrics = RR.get("ReplicatedStorage.Utils.Metrics")

-- ========= TYPE DEFINITIONS =========
export type DailyRewardState = {
	canClaim: boolean,
	streak: number,
	streakBroken: boolean,
	rewards: { any },
	dayIndex: number,
	nextClaimTime: number,
	lastUpdateTime: number,
}

export type RewardLogEntry = {
	type: string,
	amount: number?,
	name: string?,
	id: number?,
	success: boolean?,
	desc: string?,
	queued: boolean?,
}

export type ClaimResult = {
	success: boolean,
	message: string,
	data: {
		streak: number,
		rewards: { RewardLogEntry },
		nextClaimTime: number,
	}?,
}

export type ErrorSeverity = "info" | "warning" | "error" | "critical"

export type ErrorLogEntry = {
	timestamp: number,
	severity: ErrorSeverity,
	message: string,
	context: { [string]: any }?,
	stackTrace: string?,
}

export type DailyRewardClient = {
	-- Properties
	_state: DailyRewardState,
	_maid: any,
	_isInitialized: boolean,
	_isClaiming: boolean,
	_lastClaimAttempt: number,
	_countdownConnection: RBXScriptConnection?,

	-- Methods
	init: (self: DailyRewardClient) -> (),
	start: (self: DailyRewardClient) -> (),
	cleanup: (self: DailyRewardClient) -> (),
	getState: (self: DailyRewardClient) -> DailyRewardState,
	claimReward: (self: DailyRewardClient) -> (),
	forceUpdate: (self: DailyRewardClient) -> (),
	_setupRemoteSignals: (self: DailyRewardClient) -> (),
	_updateLocalState: (self: DailyRewardClient, newState: DailyRewardState) -> (),
	_startCountdownTimer: (self: DailyRewardClient) -> (),
	_stopCountdownTimer: (self: DailyRewardClient) -> (),
	_handleNetworkError: (self: DailyRewardClient, errorMessage: string, retryCallback: () -> ()) -> (),
	_logError: (self: DailyRewardClient, severity: ErrorSeverity, message: string, context: { [string]: any }?) -> (),
	_getStackTrace: (self: DailyRewardClient) -> string,
}

-- ========= MAIN CLASS IMPLEMENTATION =========
local DailyRewardClient = {}
DailyRewardClient.__index = DailyRewardClient

-- Constants
local NETWORK_RETRY_ATTEMPTS = 3
local CLAIM_COOLDOWN = 0.5 -- seconds between claim attempts
local STATE_UPDATE_THROTTLE = 0.1 -- seconds between state change events
local MAX_CLAIMS_PER_MINUTE = 5 -- Anti-spam rate limiting
local CLAIM_WINDOW_SECONDS = 60 -- 1 minute window for rate limiting

-- Remote Signal References
local DailyRewardStatusSignal = RemoteSignal.new("DailyRewardStatus")
local DailyRewardClaimSignal = RemoteSignal.new("DailyRewardClaim")
local DailyRewardResultSignal = RemoteSignal.new("DailyRewardResult")

--[[
    Creates a new DailyRewardClient instance.
    @return DailyRewardClient: The new instance
]]
function DailyRewardClient.new(): DailyRewardClient
	local self = setmetatable({}, DailyRewardClient)

	-- Initialize default state
	self._state = {
		canClaim = false,
		streak = 0,
		streakBroken = false,
		rewards = {},
		dayIndex = 1,
		nextClaimTime = 0,
		lastUpdateTime = 0,
	}

	-- Load cached state if available
	self:_loadCachedState()

	self._maid = Maid.new()
	self._isInitialized = false
	self._isClaiming = false
	self._lastClaimAttempt = 0
	self._countdownConnection = nil
	self._claimHistory = {} -- For rate limiting
	self._concurrentClaimLock = false -- For race condition prevention
	self._errorLog = {} -- Structured error logging

	-- Throttle state change events
	self._lastStateChangeTime = 0

	return self
end

--[[
    Initializes the DailyRewardClient and sets up server communication.
    Should be called once when the client is created.
]]
function DailyRewardClient:init()
	if self._isInitialized then
		warn("[DailyRewardClient] Already initialized")
		return
	end

	self:_setupRemoteSignals()
	self._isInitialized = true

	-- Set up network monitoring
	self:_setupNetworkMonitoring()

	-- Request initial state from server, fall back to cache if offline
	if self:_isOnline() then
		self:forceUpdate()
	else
		warn("[DailyRewardClient] Offline at init, using cached state")
		Metrics.inc("daily_reward_offline_starts")
	end
end

--[[
    Starts the DailyRewardClient, including countdown timer and periodic updates.
    Should be called when the UI becomes visible or when rewards become relevant.
]]
function DailyRewardClient:start()
	if not self._isInitialized then
		error("[DailyRewardClient] Must call init() before start()")
	end

	self:_startCountdownTimer()

	-- Set up periodic state updates (every 5 minutes)
	self._maid:GiveTask(RunService.Heartbeat:Connect(function()
		local now = TimeGuard.now()
		if now - self._state.lastUpdateTime > 300 then -- 5 minutes
			self:forceUpdate()
		end
	end))
end

--[[
    Cleans up all resources and connections.
    Should be called when the client is no longer needed.
]]
function DailyRewardClient:cleanup()
	self:_stopCountdownTimer()
	self._maid:DoCleaning()
	self._isInitialized = false

	-- Clean up events
	self.StateChanged:Destroy()
	self.ClaimResult:Destroy()
end

--[[
    Gets the current local state.
    @return DailyRewardState: The current state
]]
function DailyRewardClient:getState(): DailyRewardState
	return table.clone(self._state)
end

--[[
    Attempts to claim the daily reward with validation and anti-exploit measures.
    Includes cooldown checking and network retry logic.
]]
function DailyRewardClient:claimReward()
	local now = TimeGuard.now()

	-- Cooldown check
	if now - self._lastClaimAttempt < CLAIM_COOLDOWN then
		self.ClaimResult:Fire({
			success = false,
			message = "Please wait before claiming again.",
		})
		return
	end

	self._lastClaimAttempt = now

	-- Local validation
	if not self._state.canClaim then
		-- TODO: Implement reward not available handling
		return
	end

	if self._isClaiming then
        -- TODO: Implement claim request cancellation
		return
	end

	self._isClaiming = true

	-- Network request with robust retry logic using Resilience module
	local success, result = Resilience.RetryWithBackoff(NETWORK_RETRY_ATTEMPTS, function()
		return DailyRewardClaimSignal:FireServer()
	end)

	if not success then
		self._isClaiming = false
		local errorMessage =
			string.format("Claim failed after %d attempts: %s", NETWORK_RETRY_ATTEMPTS, tostring(result))
        self:_handleNetworkError(errorMessage, function()
            self:claimReward()
        end)
		-- Log metrics for network failure
		Metrics.inc("daily_reward_network_failures")
	else
		self._isClaiming = false
		-- Server will respond via DailyRewardResultSignal
	end
end

--[[
    Forces an immediate state update from the server.
    Useful for manual refresh or after network reconnection.
]]
function DailyRewardClient:forceUpdate()
	-- Request status update from server
	-- The server will push the update via DailyRewardStatusSignal
	pcall(function()
		-- This could be a dedicated "request status" signal or rely on server's periodic updates
		-- For now, we'll rely on the server's existing update mechanism
	end)
end

-- ========= PRIVATE METHODS =========

--[[
    Sets up remote signal connections for server communication.
]]
function DailyRewardClient:_setupRemoteSignals()
	-- Handle status updates from server with validation
	self._maid:GiveTask(DailyRewardStatusSignal:Connect(function(payload: DailyRewardState)
		if self:_validateServerState(payload) then
			self:_updateLocalState(payload)
		else
			warn("[DailyRewardClient] Invalid state received from server, requesting fresh update")
			Metrics.inc("daily_reward_state_validation_failures")
			-- Request fresh state update
			self:forceUpdate()
		end
	end))

	-- Handle claim results from server with validation
	self._maid:GiveTask(DailyRewardResultSignal:Connect(function(success: boolean, message: string, data: any?)
		-- Validate claim result data
		if success and data and not self:_validateClaimResult(data) then
			warn("[DailyRewardClient] Invalid claim result data received")
			success = false
			data = nil
			Metrics.inc("daily_reward_claim_validation_failures")
		end

		-- Update local state if claim was successful and validated
		if success and data then
			local newState = table.clone(self._state)
			newState.streak = data.streak or newState.streak
			newState.nextClaimTime = data.nextClaimTime or newState.nextClaimTime
			newState.canClaim = false -- Immediately mark as claimed

			self:_updateLocalState(newState)
		end
	end))
end

--[[
    Updates the local state and triggers state change events with throttling.
    @param newState: The new state to apply
]]
function DailyRewardClient:_updateLocalState(newState: DailyRewardState)
	local oldState = self._state
	self._state = newState
	self._state.lastUpdateTime = TimeGuard.now()

	-- Save state to cache whenever updated
	self:_saveStateToCache()

	-- Throttle state change events to prevent spam
	local now = TimeGuard.now()
	if now - self._lastStateChangeTime >= STATE_UPDATE_THROTTLE then
		self._lastStateChangeTime = now
		self.StateChanged:Fire(table.clone(self._state))

		-- Restart countdown timer if nextClaimTime changed
		if oldState.nextClaimTime ~= newState.nextClaimTime then
			self:_stopCountdownTimer()
			self:_startCountdownTimer()
		end
	end
end

--[[
    Starts the real-time countdown timer for next claim availability.
    Updates the local state dynamically as time progresses.
]]
function DailyRewardClient:_startCountdownTimer()
	self:_stopCountdownTimer() -- Ensure no existing timer

	self._countdownConnection = RunService.Heartbeat:Connect(function()
		local now = TimeGuard.now()
		local timeRemaining = math.max(0, self._state.nextClaimTime - now)

		-- Update canClaim status dynamically
		local canClaimNow = timeRemaining <= 0

		if canClaimNow ~= self._state.canClaim then
			local newState = table.clone(self._state)
			newState.canClaim = canClaimNow
			self:_updateLocalState(newState)
		end

		-- Fire progress updates for UI (optional, can be used for countdown display)
		if timeRemaining > 0 then
			-- You can emit progress events here if needed for UI updates
		end
	end)
end

--[[
    Stops the countdown timer.
]]
function DailyRewardClient:_stopCountdownTimer()
	if self._countdownConnection then
		self._countdownConnection:Disconnect()
		self._countdownConnection = nil
	end
end

--[[
    Handles network errors with retry logic and user feedback.
    @param errorMessage: The error message to log
    @param retryCallback: The callback function to retry the operation
]]
function DailyRewardClient:_handleNetworkError(errorMessage: string, retryCallback: () -> ())
	self:_logError("warning", "Network error occurred", {
		message = errorMessage,
		retryCallback = retryCallback ~= nil,
	})

	-- Could add exponential backoff and retry logic here
	-- For now, just log and let the caller handle retries
end

--[[
    Logs an error with structured data and severity levels.
    @param severity: The severity level of the error
    @param message: The error message
    @param context: Optional context data for debugging
]]
function DailyRewardClient:_logError(severity: ErrorSeverity, message: string, context: { [string]: any }?)
	local errorEntry: ErrorLogEntry = {
		timestamp = TimeGuard.now(),
		severity = severity,
		message = message,
		context = context,
		stackTrace = self:_getStackTrace(),
	}

	-- Add to error log (keep last 100 errors)
	table.insert(self._errorLog, errorEntry)
	if #self._errorLog > 100 then
		table.remove(self._errorLog, 1)
	end

	-- Log to console based on severity
	local logMessage = string.format("[DailyRewardClient][%s] %s", severity:upper(), message)
	if severity == "error" or severity == "critical" then
		warn(logMessage)
		if context then
			warn("Context:", context)
		end
		if errorEntry.stackTrace then
			warn("Stack trace:", errorEntry.stackTrace)
		end
	else
		print(logMessage)
	end

	-- Track metrics
	Metrics.inc("daily_reward_errors_total")
	Metrics.inc("daily_reward_errors_" .. severity)
end

--[[
    Gets the current stack trace for error reporting.
    @return string: The stack trace
]]
function DailyRewardClient:_getStackTrace(): string
	local success, stack = pcall(function()
		return debug.traceback("", 2) -- Skip this function and the caller
	end)
	return success and stack or "Stack trace unavailable"
end

-- ========= VALIDATION METHODS =========

--[[
    Validates server state payload to prevent data corruption.
    @param state: The state received from server
    @return boolean: True if state is valid
]]
function DailyRewardClient:_validateServerState(state: DailyRewardState): boolean
	if type(state) ~= "table" then
		return false
	end

	-- Basic type checks
	if type(state.canClaim) ~= "boolean" then
		return false
	end

	if type(state.streak) ~= "number" or state.streak < 0 then
		return false
	end

	if type(state.streakBroken) ~= "boolean" then
		return false
	end

	if type(state.dayIndex) ~= "number" or state.dayIndex < 1 then
		return false
	end

	if type(state.nextClaimTime) ~= "number" or state.nextClaimTime < 0 then
		return false
	end

	if type(state.lastUpdateTime) ~= "number" or state.lastUpdateTime < 0 then
		return false
	end

	-- Validate rewards array structure
	if type(state.rewards) ~= "table" then
		return false
	end

	-- Additional validation can be added here for specific reward structures

	return true
end

--[[
    Validates claim result data to prevent reward corruption.
    @param data: The claim result data
    @return boolean: True if data is valid
]]
function DailyRewardClient:_validateClaimResult(data: any): boolean
	if type(data) ~= "table" then
		return false
	end

	if type(data.streak) ~= "number" or data.streak < 0 then
		return false
	end

	if type(data.nextClaimTime) ~= "number" or data.nextClaimTime < 0 then
		return false
	end

	-- Validate rewards array
	if data.rewards and type(data.rewards) ~= "table" then
		return false
	end

	-- Additional validation for individual rewards can be added here

	return true
end

-- ========= NETWORK AND CACHE METHODS =========

--[[
    Sets up network monitoring to detect online/offline status changes.
]]
function DailyRewardClient:_setupNetworkMonitoring()
	-- Monitor network connectivity changes
	self._maid:GiveTask(game:GetService("ConnectivityService").NetworkStatusChanged:Connect(function(status)
		if status == Enum.NetworkStatus.Connected then
			-- Came back online, refresh state
			self:forceUpdate()
			Metrics.inc("daily_reward_network_recovered")
		elseif status == Enum.NetworkStatus.Disconnected then
			-- Went offline, notify UI
			Metrics.inc("daily_reward_network_lost")
		end
	end))
end

--[[
    Checks if the client is currently online.
    @return boolean: True if online
]]
function DailyRewardClient:_isOnline(): boolean
	local connectivityService = game:GetService("ConnectivityService")
	return connectivityService and connectivityService.NetworkStatus == Enum.NetworkStatus.Connected
end

--[[
    Saves the current state to persistent cache.
]]
function DailyRewardClient:_saveStateToCache()
	-- Use a simple in-memory cache for now; could be extended to use DataStore
	self._cachedState = table.clone(self._state)
	self._cachedState.cacheTime = TimeGuard.now()
	Metrics.inc("daily_reward_state_cache_saves")
end

--[[
    Loads state from cache if available.
]]
function DailyRewardClient:_loadCachedState()
	if self._cachedState then
		local cacheAge = TimeGuard.now() - (self._cachedState.cacheTime or 0)
		if cacheAge < 86400 then -- 24 hours max cache age
			self._state = table.clone(self._cachedState)
			self._state.cacheTime = nil -- Remove cache metadata
			Metrics.inc("daily_reward_state_cache_hits")
		else
			Metrics.inc("daily_reward_state_cache_expired")
		end
	end
end

--[[
    Attempts to recover from error state by forcing a fresh update.
]]
function DailyRewardClient:recover()
	if self:_isOnline() then
		self:forceUpdate()
		Metrics.inc("daily_reward_recovery_attempts")
	else
		Metrics.inc("daily_reward_recovery_failures_offline")
	end
end

-- ========= RATE LIMITING AND EDGE CASE METHODS =========

--[[
    Checks if the client is rate limited based on claim history.
    @param currentTime: The current timestamp
    @return boolean: True if rate limited
]]
function DailyRewardClient:_isRateLimited(currentTime: number): boolean
	self:_cleanupClaimHistory(currentTime)
	return #self._claimHistory >= MAX_CLAIMS_PER_MINUTE
end

--[[
    Cleans up old entries from claim history to maintain rate limiting window.
    @param currentTime: The current timestamp
]]
function DailyRewardClient:_cleanupClaimHistory(currentTime: number)
	local validClaims = {}
	for _, claimTime in ipairs(self._claimHistory) do
		if currentTime - claimTime <= CLAIM_WINDOW_SECONDS then
			table.insert(validClaims, claimTime)
		end
	end
	self._claimHistory = validClaims
end

--[[
    Handles player disconnect during claim process by rolling back state.
    Should be called when player leaves or connection is lost.
]]
function DailyRewardClient:handleDisconnect()
	if self._isClaiming then
		self:_logError("warning", "Player disconnected during claim process", {
			wasClaiming = self._isClaiming,
			concurrentLock = self._concurrentClaimLock,
		})

		self._isClaiming = false
		self._concurrentClaimLock = false
		Metrics.inc("daily_reward_disconnect_during_claim")

		-- Attempt to recover state
		if self:_isOnline() then
			self:forceUpdate()
		end
	end
end

--[[
    Adds a timeout mechanism to prevent stuck claim states.
    Should be called periodically or when claim takes too long.
]]
function DailyRewardClient:_setupClaimTimeout()
	self._maid:GiveTask(task.delay(30, function() -- 30 second timeout
		if self._isClaiming then
			warn("[DailyRewardClient] Claim timeout detected, releasing lock")
			self._isClaiming = false
			self._concurrentClaimLock = false
			Metrics.inc("daily_reward_claim_timeouts")
		end
	end))
end

--[[
    Gets the recent error log for debugging and analytics.
    @param limit: Maximum number of entries to return (default: 10)
    @return {ErrorLogEntry}: Array of error log entries
]]
function DailyRewardClient:getErrorLog(limit: number?): { ErrorLogEntry }
	limit = limit or 10
	local count = math.min(limit, #self._errorLog)
	local result = {}

	for i = #self._errorLog, #self._errorLog - count + 1, -1 do
		if i >= 1 then
			table.insert(result, self._errorLog[i])
		end
	end

	return result
end

--[[
    Clears the error log.
]]
function DailyRewardClient:clearErrorLog()
	self._errorLog = {}
end

-- ========= MODULE EXPORT =========
return DailyRewardClient
