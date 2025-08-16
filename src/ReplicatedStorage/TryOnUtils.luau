local Players = game:GetService("Players")

local TryOnUtils = {}

-- [player][rigName] = { accessories }
local playerAccessoryBackups = {}

-- Utility: Get the attachment name this accessory uses for slotting
local function getAttachmentName(acc)
    local handle = acc:FindFirstChild("Handle")
    if not handle then return nil end
    for _, obj in ipairs(handle:GetChildren()) do
        if obj:IsA("Attachment") then
            return obj.Name
        end
    end
    return nil
end

-- Remove and save accessories matching the slot (by AccessoryType or AttachmentName)
function TryOnUtils.SaveAndRemoveMatchingAccessories(char, accessoryTemplate)
    local removed = {}
    local templateType = accessoryTemplate.AccessoryType
    local templateAttach = getAttachmentName(accessoryTemplate)
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local match = false
            if templateType ~= Enum.AccessoryType.Unknown and acc.AccessoryType == templateType then
                match = true
            elseif templateType == Enum.AccessoryType.Unknown and getAttachmentName(acc) == templateAttach then
                match = true
            end
            if match then
                table.insert(removed, acc:Clone())
                acc:Destroy()
            end
        end
    end
    return removed
end

function TryOnUtils.RestoreAccessories(char, saved)
    if not saved then return end
    for _, acc in ipairs(saved) do
        acc.Parent = char
    end
end

function TryOnUtils.RemoveTryOnAccessory(char, accessoryTemplate)
    local templateType = accessoryTemplate.AccessoryType
    local templateAttach = getAttachmentName(accessoryTemplate)
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") and acc:FindFirstChild("TriedOnRig") then
            if templateType ~= Enum.AccessoryType.Unknown and acc.AccessoryType == templateType then
                acc:Destroy()
            elseif templateType == Enum.AccessoryType.Unknown and getAttachmentName(acc) == templateAttach then
                acc:Destroy()
            end
        end
    end
end

function TryOnUtils.ClearTryOnState(player, rigName, accessoryTemplate)
    local char = player.Character
    if not char then return end
    if accessoryTemplate then
        TryOnUtils.RemoveTryOnAccessory(char, accessoryTemplate)
    else
        -- Fallback: remove all try-on accessories
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") and acc:FindFirstChild("TriedOnRig") then
                acc:Destroy()
            end
        end
    end
    if playerAccessoryBackups[player] and playerAccessoryBackups[player][rigName] then
        TryOnUtils.RestoreAccessories(char, playerAccessoryBackups[player][rigName])
        playerAccessoryBackups[player][rigName] = nil
    end
end

function TryOnUtils.OnPromptTriggered(player, rigName, accessoryTemplate, prompt)
    local char = player.Character
    if not char then return end

    -- Is the try-on accessory already worn?
    local found = nil
    local templateType = accessoryTemplate.AccessoryType
    local templateAttach = getAttachmentName(accessoryTemplate)
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") and acc:FindFirstChild("TriedOnRig") then
            if templateType ~= Enum.AccessoryType.Unknown and acc.AccessoryType == templateType then
                found = acc
                break
            elseif templateType == Enum.AccessoryType.Unknown and getAttachmentName(acc) == templateAttach then
                found = acc
                break
            end
        end
    end

    if found then
        -- Remove try-on, restore original
        found:Destroy()
        TryOnUtils.RestoreAccessories(char, playerAccessoryBackups[player] and playerAccessoryBackups[player][rigName])
        if playerAccessoryBackups[player] then playerAccessoryBackups[player][rigName] = nil end
    else
        -- Remove only matching accessories, save for restore
        playerAccessoryBackups[player] = playerAccessoryBackups[player] or {}
        playerAccessoryBackups[player][rigName] = TryOnUtils.SaveAndRemoveMatchingAccessories(char, accessoryTemplate)

        -- Give them the try-on accessory, marked for cleanup
        local tryAcc = accessoryTemplate:Clone()
        local marker = Instance.new("BoolValue")
        marker.Name = "TriedOnRig"
        marker.Parent = tryAcc
        tryAcc.Parent = char
    end
end

-- Clean up on respawn
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.1)
        if playerAccessoryBackups[player] then
            for rigName, _ in pairs(playerAccessoryBackups[player]) do
                TryOnUtils.ClearTryOnState(player, rigName)
            end
        end
    end)
end)

return TryOnUtils
