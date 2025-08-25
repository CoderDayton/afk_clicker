--[[
    DailyRewardAnimations.luau
    Premium animation system for Daily Reward UI with professional easing curves,
    particle effects, and comprehensive animation management.
    Integrates with UIAnimator, SoundHandler, and Maid for a polished experience.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Utilities
local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local UIAnimator = RR.get("ReplicatedStorage.UIAnimator")
local SoundHandler = RR.get("ReplicatedStorage.Utils.SoundHandler")
local GradientAnimator = RR.get("ReplicatedStorage.Utils.GradientAnimator")
local Maid = RR.get("ReplicatedStorage.Utils.Maid")

-- ========= ANIMATION CONFIGURATIONS =========
local DailyRewardAnimations = {}

-- Predefined TweenInfo configurations for consistent animations
DailyRewardAnimations.TweenConfigs = {
    -- Emphasis animations (Elastic, Back, Bounce)
    EMPHASIS_ELASTIC = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
    EMPHASIS_BACK = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    EMPHASIS_BOUNCE = TweenInfo.new(0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
    
    -- Smooth transitions (Quad, Sine)
    SMOOTH_QUAD = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    SMOOTH_SINE = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    
    -- Quick animations
    QUICK = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    
    -- Loading animations
    LOADING = TweenInfo.new(1.0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true),
}

-- Particle effect configurations
DailyRewardAnimations.ParticleEffects = {
    REWARD_CLAIM = {
        Rate = 20,
        Speed = NumberRange.new(50, 100),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.5, 0.8),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Lifetime = NumberRange.new(0.5, 1.0),
        Color = ColorSequence.new(Color3.fromRGB(255, 200, 50)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }
}

-- Quality settings for performance optimization
DailyRewardAnimations.QualitySettings = {
    HIGH = {
        ParticleEnabled = true,
        ComplexAnimations = true,
        MaxParticles = 30,
    },
    MEDIUM = {
        ParticleEnabled = true,
        ComplexAnimations = false,
        MaxParticles = 15,
    },
    LOW = {
        ParticleEnabled = false,
        ComplexAnimations = false,
        MaxParticles = 0,
    }
}

-- Current quality level (default to high, can be adjusted based on device)
DailyRewardAnimations.CurrentQuality = "HIGH"

-- ========= PARTICLE SYSTEM =========
local particlePool = {}
local activeParticles = {}

function DailyRewardAnimations.createParticleEmitter(parent: Instance, config: any): ParticleEmitter?
    local quality = DailyRewardAnimations.QualitySettings[DailyRewardAnimations.CurrentQuality]
    if not quality.ParticleEnabled then
        return nil
    end

    -- Try to reuse from pool
    local emitter
    if #particlePool > 0 then
        emitter = table.remove(particlePool)
        emitter.Parent = parent
        emitter:Clear()
    else
        emitter = Instance.new("ParticleEmitter")
        emitter.Parent = parent
    end

    -- Configure emitter
    emitter.Rate = config.Rate
    emitter.Speed = config.Speed
    emitter.Size = config.Size
    emitter.Lifetime = config.Lifetime
    emitter.Color = config.Color
    emitter.Transparency = config.Transparency
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-60, 60)
    emitter.VelocitySpread = 90

    -- Limit active particles
    if #activeParticles >= quality.MaxParticles then
        local oldest = table.remove(activeParticles, 1)
        if oldest then
            oldest.Enabled = false
            oldest.Parent = nil
            table.insert(particlePool, oldest)
        end
    end

    table.insert(activeParticles, emitter)
    return emitter
end

function DailyRewardAnimations.cleanupParticles()
    for _, emitter in ipairs(activeParticles) do
        emitter.Enabled = false
        emitter.Parent = nil
        table.insert(particlePool, emitter)
    end
    activeParticles = {}
end

-- ========= ANIMATION FUNCTIONS =========
function DailyRewardAnimations.animateHoverEffect(target: GuiObject, maid: Maid?)
    local originalSize = target.Size
    local originalTransparency = target.BackgroundTransparency
    local hoverSize = UDim2.new(originalSize.X.Scale * 1.05, 0, originalSize.Y.Scale * 1.05, 0)
    local hoverTransparency = math.max(0, originalTransparency - 0.1)

    local enterTween = TweenService:Create(target, DailyRewardAnimations.TweenConfigs.SMOOTH_SINE, {
        Size = hoverSize,
        BackgroundTransparency = hoverTransparency
    })

    local leaveTween = TweenService:Create(target, DailyRewardAnimations.TweenConfigs.SMOOTH_SINE, {
        Size = originalSize,
        BackgroundTransparency = originalTransparency
    })

    local enterConnection = target.MouseEnter:Connect(function()
        enterTween:Play()
        SoundHandler.PlaySound("ButtonSound")
    end)

    local leaveConnection = target.MouseLeave:Connect(function()
        leaveTween:Play()
    end)

    if maid then
        maid:GiveTask(enterConnection)
        maid:GiveTask(leaveConnection)
    end

    return enterConnection, leaveConnection
end

function DailyRewardAnimations.animatePressEffect(target: GuiObject, maid: Maid?)
    local originalSize = target.Size
    local pressSize = UDim2.new(originalSize.X.Scale * 0.95, 0, originalSize.Y.Scale * 0.95, 0)

    local pressConnection = target.MouseButton1Down:Connect(function()
        local tween = TweenService:Create(target, DailyRewardAnimations.TweenConfigs.QUICK, {
            Size = pressSize
        })
        tween:Play()
    end)

    local releaseConnection = target.MouseButton1Up:Connect(function()
        local tween = TweenService:Create(target, DailyRewardAnimations.TweenConfigs.EMPHASIS_ELASTIC, {
            Size = originalSize
        })
        tween:Play()
    end)

    if maid then
        maid:GiveTask(pressConnection)
        maid:GiveTask(releaseConnection)
    end

    return pressConnection, releaseConnection
end

function DailyRewardAnimations.animateRewardClaim(card: GuiObject, rewardData: any, maid: Maid?)
    local quality = DailyRewardAnimations.QualitySettings[DailyRewardAnimations.CurrentQuality]
    local sequence = {}

    -- Scale pulse animation
    local originalSize = card.Size
    local pulseOut = TweenService:Create(card, DailyRewardAnimations.TweenConfigs.EMPHASIS_BOUNCE, {
        Size = UDim2.new(originalSize.X.Scale * 1.3, 0, originalSize.Y.Scale * 1.3, 0),
        BackgroundTransparency = 0.1
    })

    local pulseIn = TweenService:Create(card, DailyRewardAnimations.TweenConfigs.SMOOTH_SINE, {
        Size = originalSize,
        BackgroundTransparency = 0.3
    })

    table.insert(sequence, pulseOut)
    table.insert(sequence, pulseIn)

    -- Particle effects if enabled
    if quality.ParticleEnabled then
        task.spawn(function()
            local emitter = DailyRewardAnimations.createParticleEmitter(card, DailyRewardAnimations.ParticleEffects.REWARD_CLAIM)
            if emitter then
                emitter.Enabled = true
                task.delay(1.0, function()
                    emitter.Enabled = false
                    task.delay(2.0, function()
                        if emitter.Parent then
                            emitter.Parent = nil
                            table.insert(particlePool, emitter)
                        end
                    end)
                end)
            end
        end)
    end

    -- Play sound
    SoundHandler.PlaySound("PositiveFeedback")

    -- Execute animation sequence
    local function playSequence(index)
        if index > #sequence then return end
        local tween = sequence[index]
        tween:Play()
        tween.Completed:Connect(function()
            playSequence(index + 1)
        end)
    end

    playSequence(1)
end

function DailyRewardAnimations.animateLoadingState(target: GuiObject, maid: Maid?)
    local loadingIndicator = Instance.new("Frame")
    loadingIndicator.Name = "LoadingIndicator"
    loadingIndicator.Size = UDim2.new(0.6, 0, 0.6, 0)
    loadingIndicator.Position = UDim2.new(0.2, 0, 0.2, 0)
    loadingIndicator.BackgroundTransparency = 1
    loadingIndicator.ZIndex = target.ZIndex + 1
    loadingIndicator.Parent = target

    local spinner = Instance.new("Frame")
    spinner.Name = "Spinner"
    spinner.Size = UDim2.new(0.5, 0, 0.5, 0)
    spinner.Position = UDim2.new(0.25, 0, 0.25, 0)
    spinner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    spinner.BackgroundTransparency = 0.5
    spinner.ZIndex = loadingIndicator.ZIndex + 1

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = spinner

    spinner.Parent = loadingIndicator

    local rotationTween = TweenService:Create(spinner, DailyRewardAnimations.TweenConfigs.LOADING, {
        Rotation = 360
    })
    rotationTween:Play()

    if maid then
        maid:GiveTask(function()
            rotationTween:Cancel()
            loadingIndicator:Destroy()
        end)
    end

    return loadingIndicator
end

function DailyRewardAnimations.animateSuccessFeedback(target: GuiObject, message: string, maid: Maid?)
    -- Use UIUtils for feedback or create custom success animation
    local successGlow = Instance.new("Frame")
    successGlow.Name = "SuccessGlow"
    successGlow.Size = UDim2.new(1.2, 0, 1.2, 0)
    successGlow.Position = UDim2.new(-0.1, 0, -0.1, 0)
    successGlow.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
    successGlow.BackgroundTransparency = 0.8
    successGlow.ZIndex = target.ZIndex + 2
    successGlow.Parent = target

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = successGlow

    local expandTween = TweenService:Create(successGlow, DailyRewardAnimations.TweenConfigs.EMPHASIS_ELASTIC, {
        Size = UDim2.new(1.5, 0, 1.5, 0),
        Position = UDim2.new(-0.25, 0, -0.25, 0),
        BackgroundTransparency = 0.9
    })

    local fadeTween = TweenService:Create(successGlow, TweenInfo.new(0.5), {
        BackgroundTransparency = 1
    })

    expandTween:Play()
    expandTween.Completed:Connect(function()
        fadeTween:Play()
        fadeTween.Completed:Connect(function()
            successGlow:Destroy()
        end)
    end)

    SoundHandler.PlaySound("PositiveFeedback", 0.3)
end

function DailyRewardAnimations.animateFailureFeedback(target: GuiObject, message: string, maid: Maid?)
    local shakeTween = UIAnimator.chain(target, {
        {
            Duration = 0.05,
            EasingStyle = Enum.EasingStyle.Sine,
            Properties = { Position = target.Position + UDim2.new(0.02, 0, 0, 0) }
        },
        {
            Duration = 0.05,
            EasingStyle = Enum.EasingStyle.Sine,
            Properties = { Position = target.Position - UDim2.new(0.04, 0, 0, 0) }
        },
        {
            Duration = 0.05,
            EasingStyle = Enum.EasingStyle.Sine,
            Properties = { Position = target.Position + UDim2.new(0.02, 0, 0, 0) }
        }
    })

    SoundHandler.PlaySound("MenuClose", 0.4)
end

function DailyRewardAnimations.setQualityLevel(level: string)
    level = string.upper(level)
    if DailyRewardAnimations.QualitySettings[level] then
        DailyRewardAnimations.CurrentQuality = level
        if level == "LOW" then
            DailyRewardAnimations.cleanupParticles()
        end
    end
end

-- Initialize quality based on device performance (simplified)
function DailyRewardAnimations.detectQualityLevel()
    -- Simple detection - in real implementation, use metrics like FPS or device info
    if RunService:IsStudio() or settings().Rendering.QualityLevel >= 8 then
        return "HIGH"
    elseif settings().Rendering.QualityLevel >= 5 then
        return "MEDIUM"
    else
        return "LOW"
    end
end

-- Auto-detect quality on startup
DailyRewardAnimations.setQualityLevel(DailyRewardAnimations.detectQualityLevel())

return DailyRewardAnimations