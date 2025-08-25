-- Fallback entity categorization data for memory system
-- This file serves as a backup categorization method when MCP tools are unavailable
-- Categories and priorities are based on entity roles and importance

return {
    -- Core AFK System Entities
    AFKPointSystem = {
        category = "Core Systems",
        priority = "High",
        description = "Roblox AFK currency system with passive/active earning mechanics"
    },
    AFKPointConfig = {
        category = "Configuration",
        priority = "High",
        description = "Defines core parameters and gamepass definitions"
    },
    AFKPointUtils = {
        category = "Utilities",
        priority = "Medium",
        description = "Handles multiplier calculations and gamepass verification"
    },
    AFKPointEngine = {
        category = "Server Modules",
        priority = "High",
        description = "Manages data persistence and core earning logic"
    },
    AFKPointClient = {
        category = "Client Modules",
        priority = "High",
        description = "Handles UI updates and player input processing"
    },

    -- Roblox API Entities
    MarketplaceService = {
        category = "Roblox APIs",
        priority = "High",
        description = "Core service for handling in-game purchases and subscriptions"
    },
    DataStoreService = {
        category = "Roblox APIs",
        priority = "High",
        description = "Persistent data storage across game sessions"
    },
    Vector3 = {
        category = "Roblox APIs",
        priority = "High",
        description = "Represents a 3D vector with X, Y, and Z components"
    },
    ["math Library"] = {
        category = "Roblox APIs",
        priority = "High",
        description = "Provides mathematical functions for calculations"
    },
    TweenService = {
        category = "Roblox APIs",
        priority = "High",
        description = "Animates object properties smoothly over time"
    },

    -- Utility Modules
    BadgeWorker = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Server-only badge awarding system with queue and retry logic"
    },
    GradientAnimator = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Advanced gradient animation system with multiple strategies"
    },
    GradientUtil = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Wrapper for easy gradient application to UI elements"
    },
    LeaderboardUtils = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Leaderboard entry creation and formatting utilities"
    },
    Maid = {
        category = "Utility Modules",
        priority = "High",
        description = "Resource cleanup utility for managing tasks and connections"
    },
    Metrics = {
        category = "Utility Modules",
        priority = "Low",
        description = "Simple counter system for tracking metrics"
    },
    RemoteSignal = {
        category = "Utility Modules",
        priority = "High",
        description = "Enhanced RemoteEvent wrapper with local callback support"
    },
    RequestGate = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Rate limiting system with burst control and backoff"
    },
    Resilience = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Retry and backoff utilities for robust operations"
    },
    RobustRequire = {
        category = "Utility Modules",
        priority = "High",
        description = "Advanced module loading system with promise-based resolution"
    },
    SoftShadow = {
        category = "Utility Modules",
        priority = "Low",
        description = "Optimized soft shadow application for GUI elements"
    },
    SoundHandler = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Sound management system with channel-based polyphony control"
    },
    Ticker = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Simple cancellable timer for periodic tasks"
    },
    TimeGuard = {
        category = "Utility Modules",
        priority = "Medium",
        description = "Timestamp protection to prevent time going backwards"
    },
    UIUtils = {
        category = "Utility Modules",
        priority = "Medium",
        description = "UI utility functions for text effects and formatting"
    },

    -- Daily Reward System
    DailyRewardClient = {
        category = "Client Modules",
        priority = "Medium",
        description = "Client-side daily reward system with OOP patterns"
    },
    DailyRewardState = {
        category = "Data Structures",
        priority = "Medium",
        description = "Type definition for daily reward state"
    },
    ClaimResult = {
        category = "Data Structures",
        priority = "Medium",
        description = "Type definition for claim results"
    },

    -- Category Definitions (for reference)
    Categories = {
        ["Core Systems"] = "Critical application systems essential for functionality",
        ["Configuration"] = "Modules defining parameters and settings",
        ["Utilities"] = "Helper functions and utility modules",
        ["Server Modules"] = "Server-side logic and data handling",
        ["Client Modules"] = "Client-side UI and input handling",
        ["Roblox APIs"] = "Native Roblox services and APIs",
        ["Utility Modules"] = "Specific utility implementations",
        ["Data Structures"] = "Data type definitions and structures"
    },

    PriorityLevels = {
        High = "Critical functionality, essential for system operation",
        Medium = "Important functionality, but not critical",
        Low = "Optional or diagnostic functionality"
    }
}