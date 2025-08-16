--[[
    RemoteSignal Module
    Provides a way to create and manage RemoteEvents for client-server communication in Roblox.
    Supports both server and client contexts, with local callbacks for client-only functionality.

    Created by: malu
    Date: 6/5/2025

    Usage:
    local RemoteSignal = require(ReplicatedStorage:WaitForChild("RemoteSignal"))
    local mySignal = RemoteSignal.new("MySignalName")
    mySignal:Fire(...)  -- Fire to all clients (server) or server (client)
    mySignal:FireTo(player, ...)  -- Fire to a specific player (server only)
    mySignal:Connect(function(...)  -- Connect a function to handle events
        print("Received:", ...)
    end)

    mySignal:LocalConnect(function(...)  -- Client-only local callback
        print("Local received:", ...)
    end)
    mySignal:FireLocal(...)  -- Fire to local callbacks without network
]]

local RunService = game:GetService("RunService")

local REMOTE_FOLDER_NAME = "RemoteSignals"
local remoteFolder = game.ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
if not remoteFolder then
    remoteFolder = Instance.new("Folder")
    remoteFolder.Name = REMOTE_FOLDER_NAME
    remoteFolder.Parent = game.ReplicatedStorage
end

local RemoteSignal = {}
RemoteSignal.__index = RemoteSignal

-- Cache for shared instances by name
local signalCache = {}

function RemoteSignal.new(name)
    if signalCache[name] then
        return signalCache[name]
    end

    -- Find or create the RemoteEvent with the given name
    local event = remoteFolder:FindFirstChild(name)
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = remoteFolder
    end

    local self = setmetatable({}, RemoteSignal)
    self._event = event
    self._localCallbacks = {}

    signalCache[name] = self
    return self
end

function RemoteSignal:Fire(...)
    if RunService:IsServer() then
        -- On server, fire to all players (broadcast)
        self._event:FireAllClients(...)
    else
        -- On client, fire to server
        self._event:FireServer(...)
    end
end

function RemoteSignal:FireTo(player, ...)
    -- Server-only: fire to a specific player
    if RunService:IsServer() then
        self._event:FireClient(player, ...)
    end
end

function RemoteSignal:Connect(func)
    if RunService:IsServer() then
        return self._event.OnServerEvent:Connect(func)
    else
        return self._event.OnClientEvent:Connect(func)
    end
end

function RemoteSignal:Wait()
    if RunService:IsServer() then
        return self._event.OnServerEvent:Wait()
    else
        return self._event.OnClientEvent:Wait()
    end
end

-- Client-only fire (invokes local callbacks without network)
function RemoteSignal:FireLocal(...)
    if RunService:IsServer() then
        error("FireLocal can only be called on the client")
    end
    for _, callback in ipairs(self._localCallbacks) do
        local success, err = pcall(callback, ...)  -- Call directly with error handling
        if not success then
            warn("[RemoteSignal] Callback error:", err)  -- Log any callback issues
        end
    end
end

-- Client-only connect (adds to local callbacks)
function RemoteSignal:LocalConnect(func)
    if RunService:IsServer() then
        error("LocalConnect can only be called on the client")
    end
    table.insert(self._localCallbacks, func)
    return {
        Disconnect = function()
            for i, cb in ipairs(self._localCallbacks) do
                if cb == func then
                    table.remove(self._localCallbacks, i)
                    break
                end
            end
        end
    }
end

return RemoteSignal
