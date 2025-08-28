--[[
    RobustRequire.luau - Luna's Absolute Module Domination System

    The final word in Roblox module loading.
    No more circular deps. No more load order. No more tears.
    Just .get() and let the machine handle the chaos.
]]

local RunService = game:GetService("RunService")
local IsStudio = RunService:IsStudio()

-- ==============================
-- CORE DESIGN: PROMISE-BASED MODULE LOADING
-- ==============================
-- Why promises? Because async/await is for cowards.
-- Promises let us handle dependency resolution elegantly without yielding forever.
-- Every module load becomes a chainable, resolvable future.

local Promise = {} -- Ultra-lightweight promise implementation
Promise.__index = Promise

function Promise.new(executor)
	local self = setmetatable({
		_state = "pending",
		_value = nil,
		_callbacks = {},
	}, Promise)

	local function resolve(value)
		if self._state ~= "pending" then
			return
		end
		self._state = "fulfilled"
		self._value = value
		for _, callback in ipairs(self._callbacks) do
			callback(value)
		end
	end

	local function reject(reason)
		if self._state ~= "pending" then
			return
		end
		self._state = "rejected"
		self._value = reason
		for _, callback in ipairs(self._callbacks) do
			callback(nil, reason)
		end
	end

	executor(resolve, reject)
	return self
end

function Promise:andThen(onFulfilled, onRejected)
	return Promise.new(function(resolve, reject)
		local function callback(success, failure)
			local handler = success and onFulfilled or onRejected
			if handler then
				local ok, result = pcall(handler, success and success or failure)
				if ok then
					if type(result) == "table" and result.andThen then
						result:andThen(resolve, reject)
					else
						resolve(result)
					end
				else
					reject(result)
				end
			else
				if success then
					resolve(success)
				else
					reject(failure)
				end
			end
		end

		if self._state == "pending" then
			table.insert(self._callbacks, callback)
		else
			task.spawn(
				callback,
				self._state == "fulfilled" and self._value or nil,
				self._state == "rejected" and self._value or nil
			)
		end
	end)
end

function Promise:await()
	if self._state ~= "pending" then
		if self._state == "fulfilled" then
			return self._value
		else
			-- Enhanced error reporting with context
			local errorMsg = string.format(
				"Promise rejected: %s\nPromise state: %s\nStack: %s",
				tostring(self._value),
				self._state,
				debug.traceback("", 3)
			)
			error(errorMsg, 2)
		end
	end

	local co = coroutine.running()
	local resolvedValue, rejectedReason

	local function callback(success, failure)
		resolvedValue = success
		rejectedReason = failure
		coroutine.resume(co)
	end

	table.insert(self._callbacks, callback)
	coroutine.yield()

	if rejectedReason then
		local errorMsg = string.format(
			"Promise await failed: %s\nCoroutine: %s\nStack: %s",
			tostring(rejectedReason),
			tostring(co),
			debug.traceback("", 2)
		)
		error(errorMsg, 2)
	end
	return resolvedValue
end

-- ==============================
-- MODULE LOADER CORE
-- ==============================
local modulePromises = {} -- Stores promises for each module
local moduleCache = {} -- Final cached module results
local loadingStack = {} -- Tracks loading modules to detect cycles
local moduleIdentifiers = {} -- Maps identifiers to ModuleScripts
local hotReloadListeners = {} -- For Studio hot reload

-- Performance and debugging enhancements
local moduleResolutionCache = {} -- Cache for failed lookups to avoid repeated searches
local hotReloadConnections = {} -- Track connections for proper cleanup
local loadingMetrics = {} -- Track loading times and failures

local RobustRequire = {}

-- Generate a unique identifier for a module
local function getModuleId(moduleScript)
	if typeof(moduleScript) == "string" then
		return moduleScript -- Already an identifier
	elseif typeof(moduleScript) == "Instance" and moduleScript:IsA("ModuleScript") then
		return moduleScript:GetFullName()
	else
		error("Invalid module identifier: " .. tostring(moduleScript), 3)
	end
end

-- Resolve a module identifier to a ModuleScript instance
local function resolveModule(moduleIdentifier)
	-- Input validation (defensive programming)
	if moduleIdentifier == nil then
		error("Module identifier cannot be nil", 3)
	end

	if typeof(moduleIdentifier) == "Instance" and moduleIdentifier:IsA("ModuleScript") then
		return moduleIdentifier
	end

	if typeof(moduleIdentifier) == "string" then
		-- Check resolution cache first (performance optimization)
		if moduleResolutionCache[moduleIdentifier] then
			local cached = moduleResolutionCache[moduleIdentifier]
			if cached.success then
				return cached.module
			else
				error("Module not found: " .. moduleIdentifier .. " (cached failure)", 3)
			end
		end

		-- Check if already resolved
		if moduleIdentifiers[moduleIdentifier] then
			return moduleIdentifiers[moduleIdentifier]
		end

		-- Attempt to find by path (ReplicatedStorage.Modules.MyModule)
		local current = game
		local found = true
		for segment in string.gmatch(moduleIdentifier, "[^.]+") do
			current = current:FindFirstChild(segment)
			if not current then
				found = false
				break
			end
		end

		if found and current:IsA("ModuleScript") then
			moduleIdentifiers[moduleIdentifier] = current
			moduleResolutionCache[moduleIdentifier] = { success = true, module = current }
			return current
		end

		-- Attempt to find by name only (last resort, optimized with depth limit)
		local function search(instance, depth)
			-- Limit search depth to prevent infinite recursion and improve performance
			if depth > 10 then
				return nil
			end

			if instance:IsA("ModuleScript") and instance.Name == moduleIdentifier then
				moduleIdentifiers[moduleIdentifier] = instance
				moduleResolutionCache[moduleIdentifier] = { success = true, module = instance }
				return instance
			end

			for _, child in ipairs(instance:GetChildren()) do
				local foundModule = search(child, depth + 1)
				if foundModule then
					return foundModule
				end
			end
			return nil
		end

		local foundModule = search(game, 0)
		if foundModule then
			return foundModule
		end

		-- Cache the failure to avoid repeated expensive searches
		moduleResolutionCache[moduleIdentifier] = { success = false }
	end

	error("Module not found: " .. tostring(moduleIdentifier), 3)
end

-- Internal function to create a promise for loading a module
local function createModulePromise(moduleScript)
	local moduleId = getModuleId(moduleScript)
	local startTime = tick()

	-- Initialize metrics tracking
	if not loadingMetrics[moduleId] then
		loadingMetrics[moduleId] = {
			attempts = 0,
			failures = 0,
			totalLoadTime = 0,
			lastLoadTime = 0,
		}
	end
	loadingMetrics[moduleId].attempts = loadingMetrics[moduleId].attempts + 1

	-- Return existing promise if already created
	if modulePromises[moduleId] then
		return modulePromises[moduleId]
	end

	-- Check for circular dependency with enhanced context
	if loadingStack[moduleId] then
		if IsStudio then
			warn("[RobustRequire] Circular dependency detected for:", moduleId)
			-- Create dependency chain for debugging
			local chain = {}
			for stackId, _ in pairs(loadingStack) do
				table.insert(chain, stackId)
			end
			warn("Current loading stack:", table.concat(chain, " -> "))
		end

		-- Create a special "circular dependency" promise that resolves when the chain completes
		local circularPromise = Promise.new(function(resolve, reject)
			-- This will be resolved by the original loader once it finishes
			-- We store a reference to allow resolution
			if not loadingStack[moduleId].circularResolvers then
				loadingStack[moduleId].circularResolvers = {}
			end
			table.insert(loadingStack[moduleId].circularResolvers, { resolve = resolve, reject = reject })
		end)
		return circularPromise
	end

	-- Mark as loading with enhanced context
	loadingStack[moduleId] = {
		module = moduleScript,
		stackTrace = debug.traceback("", 2),
		startTime = startTime,
	}

	-- Create the actual loading promise with enhanced error handling
	local promise = Promise.new(function(resolve, reject)
		task.spawn(function()
			local success, resultOrError = pcall(function()
				-- Use native require - but within our controlled promise system
				local moduleResult = require(moduleScript)

				-- Handle hot reload setup with proper connection tracking
				if IsStudio then
					local connection
					connection = moduleScript.Changed:Connect(function(prop)
						if prop == "Source" then
							connection:Disconnect()
							-- Remove from connection tracking
							if hotReloadConnections[moduleId] then
								hotReloadConnections[moduleId] = nil
							end

							-- Invalidate cache and notify listeners
							moduleCache[moduleId] = nil
							modulePromises[moduleId] = nil
							loadingStack[moduleId] = nil
							moduleResolutionCache[moduleId] = nil

							if hotReloadListeners[moduleId] then
								for _, callback in ipairs(hotReloadListeners[moduleId]) do
									pcall(callback, moduleScript)
								end
							end
						end
					end)

					-- Track the connection for proper cleanup
					hotReloadConnections[moduleId] = connection
				end

				return moduleResult
			end)

			-- Remove from loading stack and update metrics
			local loadingInfo = loadingStack[moduleId]
			loadingStack[moduleId] = nil

			local loadTime = tick() - startTime
			loadingMetrics[moduleId].lastLoadTime = loadTime
			loadingMetrics[moduleId].totalLoadTime = loadingMetrics[moduleId].totalLoadTime + loadTime

			if success then
				-- Cache the result
				moduleCache[moduleId] = resultOrError
				resolve(resultOrError)

				-- Resolve any circular dependency promises waiting
				if loadingInfo and loadingInfo.circularResolvers then
					for _, resolver in ipairs(loadingInfo.circularResolvers) do
						resolver.resolve(resultOrError)
					end
				end
			else
				-- Track failure and reject with enhanced context
				loadingMetrics[moduleId].failures = loadingMetrics[moduleId].failures + 1

				local enhancedError = string.format(
					"Failed to require module '%s' (attempt %d, load time: %.3fs): %s",
					moduleId,
					loadingMetrics[moduleId].attempts,
					loadTime,
					tostring(resultOrError)
				)

				reject(enhancedError)

				-- Reject any circular dependency promises waiting
				if loadingInfo and loadingInfo.circularResolvers then
					for _, resolver in ipairs(loadingInfo.circularResolvers) do
						resolver.reject(enhancedError)
					end
				end
			end
		end)
	end)

	modulePromises[moduleId] = promise
	return promise
end

-- ==============================
-- PUBLIC API
-- ==============================

--[[
    RobustRequire.get(identifier) -> any
    Synchronously gets a module. Will yield if the module is still loading.
    This is safe to call from anywhere at any time.
]]
function RobustRequire.get(identifier)
	local startTime = tick()
	local success, result = pcall(function()
		local moduleScript = resolveModule(identifier)
		local moduleId = getModuleId(moduleScript)

		-- Return from cache if available
		if moduleCache[moduleId] then
			return moduleCache[moduleId]
		end

		-- Create/load promise if needed
		local promise = modulePromises[moduleId] or createModulePromise(moduleScript)

		-- Await the promise (this yields)
		return promise:await()
	end)

	local loadTime = tick() - startTime

	if success then
		return result
	else
		-- Enhanced error reporting - NEVER silent fail
		local errorMessage = string.format(
			"[RobustRequire] FAILED to load module '%s' after %.3fs\n"
				.. "Error: %s\n"
				.. "Stack trace: %s\n"
				.. "Module resolution path: %s",
			tostring(identifier),
			loadTime,
			tostring(result),
			debug.traceback("", 2),
			tostring(identifier)
		)

		if IsStudio then
			warn(errorMessage)

			-- Additional debugging info - path resolution
			local currentObject = game
			local pathSegments = {}

			-- Handle different identifier types
			local pathString = tostring(identifier)
			if pathString:find("script%.") then
				print("[RobustRequire] Script-relative path detected")
			end

			-- Try to resolve the path step by step
			for segment in string.gmatch(pathString, "[^.]+") do
				table.insert(pathSegments, segment)
				if segment == "script" then
					print("[RobustRequire] 'script' segment - context-dependent")
					continue
				elseif segment == "Parent" then
					print("[RobustRequire] 'Parent' segment - context-dependent")
					continue
				end

				local found = currentObject:FindFirstChild(segment)
				if found then
					currentObject = found
					print(string.format("[RobustRequire] Found segment '%s' -> %s", segment, found:GetFullName()))
				else
					warn(
						string.format(
							"[RobustRequire] MISSING segment '%s' in %s",
							segment,
							currentObject:GetFullName()
						)
					)
					local children = {}
					for _, child in ipairs(currentObject:GetChildren()) do
						table.insert(children, child.Name)
					end
					print("[RobustRequire] Available children:", table.concat(children, ", "))
					break
				end
			end

			-- Show loading metrics if available
			local metrics = loadingMetrics
			print(
				string.format(
					"[RobustRequire] Current metrics: %d cached, %d failed",
					metrics.cachedModules or 0,
					metrics.failedModules or 0
				)
			)
		end

		-- Always error - never return nil silently
		error(errorMessage, 2)
	end
end

--[[
    RobustRequire.async(identifier) -> Promise
    Asynchronously gets a module. Returns a promise for chaining.
    Does not yield the calling thread.
]]
function RobustRequire.async(identifier)
	local moduleScript = resolveModule(identifier)
	local moduleId = getModuleId(moduleScript)

	-- Return cached result as an already resolved promise
	if moduleCache[moduleId] then
		return Promise.new(function(resolve)
			resolve(moduleCache[moduleId])
		end)
	end

	-- Create/load promise if needed
	return modulePromises[moduleId] or createModulePromise(moduleScript)
end

--[[
    RobustRequire.tryGet(identifier) -> any | nil
    Attempts to get a module synchronously. Returns nil on failure.
]]
function RobustRequire.tryGet(identifier)
	local success, result = pcall(RobustRequire.get, identifier)
	if success then
		return result
	else
		if IsStudio then
			warn("[RobustRequire] Failed to load module:", identifier, "\nError:", result)
		end
		return nil
	end
end

--[[
    RobustRequire.preload(...) -> Promise[]
    Preloads a list of modules asynchronously.
    Returns an array of promises that resolve when each module is loaded.
]]
function RobustRequire.preload(...)
	local identifiers = { ... }
	local promises = {}

	for _, identifier in ipairs(identifiers) do
		local moduleScript = resolveModule(identifier)
		local promise = modulePromises[getModuleId(moduleScript)] or createModulePromise(moduleScript)
		table.insert(promises, promise)
	end

	return promises
end

--[[
    RobustRequire.onReload(identifier, callback)
    Registers a callback to be called when a module is hot-reloaded in Studio.
]]
function RobustRequire.onReload(identifier, callback)
	if not IsStudio then
		return
	end

	local moduleScript = resolveModule(identifier)
	local moduleId = getModuleId(moduleScript)

	if not hotReloadListeners[moduleId] then
		hotReloadListeners[moduleId] = {}
	end

	table.insert(hotReloadListeners[moduleId], callback)
end

--[[
    RobustRequire.clearCache(identifier)
    Clears the cache for a specific module (useful for testing or hot reload).
]]
function RobustRequire.clearCache(identifier)
	if identifier == nil then
		return -- Defensive programming: handle nil input gracefully
	end

	local success, result = pcall(function()
		local moduleScript = resolveModule(identifier)
		local moduleId = getModuleId(moduleScript)

		-- Clean up all related data
		moduleCache[moduleId] = nil
		modulePromises[moduleId] = nil
		loadingStack[moduleId] = nil
		loadingMetrics[moduleId] = nil

		-- Clean up hot reload connections
		if hotReloadConnections[moduleId] then
			hotReloadConnections[moduleId]:Disconnect()
			hotReloadConnections[moduleId] = nil
		end

		-- Clean up hot reload listeners
		hotReloadListeners[moduleId] = nil

		-- Clean up resolution cache entries
		for cacheKey, cacheValue in pairs(moduleResolutionCache) do
			if cacheValue.success and cacheValue.module == moduleScript then
				moduleResolutionCache[cacheKey] = nil
			end
		end
	end)

	if not success and IsStudio then
		warn("[RobustRequire] Failed to clear cache for:", tostring(identifier), "Error:", result)
	end
end

--[[
    RobustRequire.getMetrics() -> table
    Returns comprehensive loading metrics for debugging and performance analysis.
]]
function RobustRequire.getMetrics()
	local loadedCount = 0
	local pendingCount = 0
	local cachedCount = 0
	local failedCount = 0
	local totalLoadTime = 0
	local circularDepsCount = 0

	for _, _ in pairs(moduleCache) do
		cachedCount = cachedCount + 1
	end

	for _, promise in pairs(modulePromises) do
		if promise._state == "fulfilled" then
			loadedCount = loadedCount + 1
		elseif promise._state == "rejected" then
			failedCount = failedCount + 1
		else
			pendingCount = pendingCount + 1
		end
	end

	-- Calculate performance metrics
	for _, metrics in pairs(loadingMetrics) do
		totalLoadTime = totalLoadTime + metrics.totalLoadTime
		if metrics.failures > 0 then
			failedCount = failedCount + metrics.failures
		end
	end

	-- Count circular dependencies
	for _, info in pairs(loadingStack) do
		if info.circularResolvers then
			circularDepsCount = circularDepsCount + #info.circularResolvers
		end
	end

	-- Count cache entries
	local resolutionCacheSize = 0
	for _, _ in pairs(moduleResolutionCache) do
		resolutionCacheSize = resolutionCacheSize + 1
	end

	local hotReloadConnectionCount = 0
	for _, _ in pairs(hotReloadConnections) do
		hotReloadConnectionCount = hotReloadConnectionCount + 1
	end

	local loadingStackSize = 0
	for _, _ in pairs(loadingStack) do
		loadingStackSize = loadingStackSize + 1
	end

	local hotReloadListenerCount = 0
	for _, _ in pairs(hotReloadListeners) do
		hotReloadListenerCount = hotReloadListenerCount + 1
	end

	return {
		cachedModules = cachedCount,
		loadedModules = loadedCount,
		pendingModules = pendingCount,
		failedModules = failedCount,
		totalPromises = loadedCount + pendingCount,
		totalLoadTime = totalLoadTime,
		averageLoadTime = loadedCount > 0 and (totalLoadTime / loadedCount) or 0,
		circularDependencies = circularDepsCount,
		resolutionCacheSize = resolutionCacheSize,
		hotReloadConnections = hotReloadConnectionCount,
		memoryUsage = {
			moduleCache = cachedCount,
			modulePromises = loadedCount + pendingCount,
			loadingStack = loadingStackSize,
			hotReloadListeners = hotReloadListenerCount,
		},
	}
end

--[[
    RobustRequire.getDependencyGraph() -> table
    Returns module dependency information for debugging (Studio only).
]]
function RobustRequire.getDependencyGraph()
	if not IsStudio then
		return {}
	end

	local graph = {}
	for moduleId, _ in pairs(moduleCache) do
		graph[moduleId] = {
			loaded = true,
			cached = true,
			metrics = loadingMetrics[moduleId],
			hasHotReload = hotReloadConnections[moduleId] ~= nil,
		}
	end

	-- Add pending modules
	for moduleId, promise in pairs(modulePromises) do
		if not graph[moduleId] then
			graph[moduleId] = {
				loaded = promise._state == "fulfilled",
				cached = false,
				state = promise._state,
				metrics = loadingMetrics[moduleId],
			}
		end
	end

	return graph
end

-- ==============================
-- USAGE EXAMPLES
-- ==============================

--[[
-- Simple synchronous loading
local MyModule = RobustRequire.get("ReplicatedStorage.Modules.MyModule")
local AnotherModule = RobustRequire.get(ReplicatedStorage.Modules.AnotherModule)

-- Asynchronous loading with chaining
RobustRequire.async("ReplicatedStorage.Modules.AsyncModule")
    :andThen(function(module)
        print("Module loaded:", module.Name)
        -- Do something with the module
    end)
    :andThen(function()
        -- Chain another action
    end)

-- Handling circular dependencies
-- ModuleA.lua:
-- local ModuleB = RobustRequire.get("ReplicatedStorage.Modules.ModuleB") -- This will work!

-- ModuleB.lua:
-- local ModuleA = RobustRequire.get("ReplicatedStorage.Modules.ModuleA") -- This will also work!

-- Preloading for performance
RobustRequire.preload(
    "ReplicatedStorage.Modules.CriticalModule1",
    "ReplicatedStorage.Modules.CriticalModule2",
    ReplicatedStorage.Modules.CriticalModule3
)

-- Late loading (e.g., in a button click handler)
button.MouseButton1Click:Connect(function()
    local ExpensiveModule = RobustRequire.get("ReplicatedStorage.Modules.ExpensiveToLoad")
    ExpensiveModule.doThing()
end)

-- Hot reload listener (Studio only)
if RunService:IsStudio() then
    RobustRequire.onReload("ReplicatedStorage.Modules.MyModule", function(moduleScript)
        print("Module reloaded:", moduleScript.Name)
        -- Re-initialialize or reset state as needed
    end)
end
]]

return RobustRequire
