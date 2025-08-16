local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local PodiumConfig = RR.get(game.ReplicatedStorage.Podiums.PodiumConfig)

local ClaimUtils = {}

ClaimUtils.CreatorUserId = 2006060772

function ClaimUtils.GetSetting(podium, key)
    if not PodiumConfig[podium.Name] or not key then
        warn("Invalid podium or key provided to GetSetting")
        return nil
    end
    local config = PodiumConfig[podium.Name]
    if config then
        return config[key]
    else
        warn("No config found for podium: " .. podium.Name)
        return nil
    end
end

function ClaimUtils.GetPodiums()
    return PodiumConfig
end

function ClaimUtils.GetPodiumObject(pName)
    local podiumsFolder = workspace:FindFirstChild("Courtyard") and workspace.Courtyard:FindFirstChild("Podiums")
    if not podiumsFolder then
        warn("Podiums folder not found in workspace.Courtyard!")
        return nil
    end

    local podium = podiumsFolder:FindFirstChild(pName)
    if not podium then
        warn("No podium found with name: " .. pName)
        return nil
    end

    if not PodiumConfig[podium.Name] then
        warn("Podium is not configured: " .. podium.Name)
        return nil
    end

    if not podium:IsA("Model") and not podium:IsA("BasePart") then
        warn("Invalid podium type: " .. podium.Name)
        return nil
    end

    return podium
end

function ClaimUtils.UpdateBillboard(billboard, remaining, podium)
    local config = PodiumConfig[podium.Name]
    if not config then
        warn("No config for podium: "..podium.Name)
        return
    end

    if remaining and remaining > 0 then
        billboard.Text = config.DisplayName .. "\n" .. remaining .. " Left"
        billboard.TextColor3 = config.MainColor
        billboard.TextSize = 24
    elseif remaining and remaining == 0 then
        billboard.Text = config.DisplayName .. "\n" .. (config.SoldOutMessage or "Sold Out")
        billboard.TextColor3 = config.SoldOutColor
        billboard.TextSize = 24
    else
        billboard.Text = config.DisplayName
        billboard.TextColor3 = config.MainColor
        billboard.TextSize = 24
    end
end

function ClaimUtils.PlayClaimEffectAtPodium(podium)
    -- Assumes a ClaimEffects template is in ReplicatedStorage!
    local effectTemplate = game.ReplicatedStorage:WaitForChild("ClaimEffects")
    local effect = effectTemplate:Clone()
    local ugcPart = podium:FindFirstChildWhichIsA("Model") or podium:FindFirstChildWhichIsA("BasePart")
    local attachPos = ugcPart and ugcPart.PrimaryPart and ugcPart.PrimaryPart.Position or podium.Position + Vector3.new(0, 3, 0)
    effect.Position = attachPos + Vector3.new(0, 2, 0)
    effect.Parent = workspace

    -- Particle
    local emitter = effect:FindFirstChildWhichIsA("ParticleEmitter", true)
    if emitter then emitter:Emit(70) end

    -- Sound
    local sound = effect:FindFirstChildWhichIsA("Sound", true)
    if sound then sound:Play() end

    Debris:AddItem(effect, 3)
end

function ClaimUtils.PulseUGC(podium)
    local ugc = podium:FindFirstChildWhichIsA("Model")
    if ugc and ugc.PrimaryPart then
        local part = ugc.PrimaryPart
        local origSize = part.Size
        local pulse = TweenService:Create(part, TweenInfo.new(0.13, Enum.EasingStyle.Quad), {Size = origSize * 1.2})
        local back = TweenService:Create(part, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Size = origSize})
        pulse:Play()
        pulse.Completed:Wait()
        back:Play()
    end
end

function ClaimUtils.PlayerOwnsUGC(player, assetId)
	if player.UserId == ClaimUtils.CreatorUserId then
		return true
	end
	
	local success, result = pcall(function()
		return MarketplaceService:PlayerOwnsAssetAsync(player, assetId)
	end)
	return success and result
end

function ClaimUtils.PlayerOwnsGamepass(player, passId)
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return success and owns
end

return ClaimUtils
