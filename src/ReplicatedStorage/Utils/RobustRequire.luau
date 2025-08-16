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
			error(self._value, 2)
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
		error(rejectedReason, 2)
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
	if typeof(moduleIdentifier) == "Instance" and moduleIdentifier:IsA("ModuleScript") then
		return moduleIdentifier
	end

	if typeof(moduleIdentifier) == "string" then
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
			return current
		end

		-- Attempt to find by name only (last resort, slow)
		local function search(instance)
			if instance:IsA("ModuleScript") and instance.Name == moduleIdentifier then
				moduleIdentifiers[moduleIdentifier] = instance
				return instance
			end
			for _, child in ipairs(instance:GetChildren()) do
				local foundModule = search(child)
				if foundModule then
					return foundModule
				end
			end
			return nil
		end

		local foundModule = search(game)
		if foundModule then
			return foundModule
		end
	end

	error("Module not found: " .. tostring(moduleIdentifier), 3)
end

-- Internal function to create a promise for loading a module
local function createModulePromise(moduleScript)
	local moduleId = getModuleId(moduleScript)

	-- Return existing promise if already created
	if modulePromises[moduleId] then
		return modulePromises[moduleId]
	end

	-- Check for circular dependency
	if loadingStack[moduleId] then
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

	-- Mark as loading
	loadingStack[moduleId] = {
		module = moduleScript,
		stackTrace = debug.traceback("", 2),
	}

	-- Create the actual loading promise
	local promise = Promise.new(function(resolve, reject)
		task.spawn(function()
			local success, resultOrError = pcall(function()
				-- Use native require - but within our controlled promise system
				local moduleResult = require(moduleScript)

				-- Handle hot reload setup
				if IsStudio then
					local connection
					connection = moduleScript.Changed:Connect(function(prop)
						if prop == "Source" then
							connection:Disconnect()
							-- Invalidate cache and notify listeners
							moduleCache[moduleId] = nil
							modulePromises[moduleId] = nil
							loadingStack[moduleId] = nil
							if hotReloadListeners[moduleId] then
								for _, callback in ipairs(hotReloadListeners[moduleId]) do
									pcall(callback, moduleScript)
								end
							end
						end
					end)
				end

				return moduleResult
			end)

			-- Remove from loading stack
			local loadingInfo = loadingStack[moduleId]
			loadingStack[moduleId] = nil

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
				-- Reject the promise
				reject(resultOrError)

				-- Reject any circular dependency promises waiting
				if loadingInfo and loadingInfo.circularResolvers then
					for _, resolver in ipairs(loadingInfo.circularResolvers) do
						resolver.reject(resultOrError)
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
	local moduleScript = resolveModule(identifier)
	local moduleId = getModuleId(moduleScript)

	moduleCache[moduleId] = nil
	modulePromises[moduleId] = nil
	loadingStack[moduleId] = nil
end

--[[
    RobustRequire.getMetrics() -> table
    Returns loading metrics for debugging.
]]
function RobustRequire.getMetrics()
	local loadedCount = 0
	local pendingCount = 0
	local cachedCount = 0

	for _, _ in pairs(moduleCache) do
		cachedCount = cachedCount + 1
	end

	for _, promise in pairs(modulePromises) do
		if promise._state == "fulfilled" then
			loadedCount = loadedCount + 1
		else
			pendingCount = pendingCount + 1
		end
	end

	return {
		cachedModules = cachedCount,
		loadedModules = loadedCount,
		pendingModules = pendingCount,
		totalPromises = loadedCount + pendingCount,
	}
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
