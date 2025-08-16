local AFKPointConfig = {
    -- Database keys and configuration
    DataStoreKey = "AFKShards",
	UpgradeKey = "AFKShardUpgrades",
	ConsumableKey = "AFKShardConsumables",
	DailyStreakKey = "AFKDailyStreak",

    -- General configuration
	ShardInterval = 1,      -- seconds between shard awards
	BaseShards = 1,         -- base shards per interval
	MaxClicksPerSecond = 5, -- Prevents autoclicking exploits (set to whatever feels fair)
	FriendBonusCap = 1.5, -- Max 50% from friends

	BonusActions = {
		Click = 2,
		MinigameWin = 10,
	},

	Gamepasses = {
		["x2 Shards"] = {
			GamepassId = 376098507,
			Description = "Earn x2 Shards permanently. Cannot stack with x3 Shards",
			StackType = "Multiply",
			BoundTo = {"x3 Shards"},
			RobuxPrice = 299,
			Features = {
				ShardMultiplier = 2,
			},
			Icon = "rbxassetid://95317559895303",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#05596c")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#181c28")),
			}),
		},
		["x3 Shards"] = {
			GamepassId = 2345678901,
			Description = "Earn triple shards permanently. Cannot stack with x2 Shards",
			StackType = "Multiply",
			BoundTo = {"x2 Shards"},
			RobuxPrice = 499,
			Features = {
				ShardMultiplier = 3,
			},
            Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#05596c")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#181c28")),
			}),
            Icon = "rbxassetid://139284947801349",
		},
		["VIP"] = {
			GamepassId = 3456789012,
			Description = "Exclusive VIP perks including 50% more shards, 50% faster auto-clicking, 10% UGC discount and more.",
			RobuxPrice = 499,
			Icon = "rbxassetid://102392861658517",
			Features = {
				ChatTag = "🌟VIP🌟",
				NameColor = Color3.fromRGB(255, 205, 90),
				DiscountPercent = 10, -- 10% off UGC items
				MinigameBonus = 2, -- 2x minigame rewards
				AutoClickerMultiplier = 1.3, -- 30% faster auto-clicking
				ShardMultiplier = 2, -- 100% more shards
			},
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(193, 171, 46)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(39, 35, 9)),
            }),
		},
		["Fast Collector"] = {
			GamepassId = 4567890123,
			Description = "Shards awarded 30% faster.",
			StackType = "Multiply",
			RobuxPrice = 179,
			Features = {
				IntervalMultiplier = 0.7,
			},
            Icon = "rbxassetid://108950113922810",
		},
		["Auto Clicker"] = {
			GamepassId = 1328275379,
			Description = "Automatically clicks for you, earning shards without manual clicking.",
			RobuxPrice = 49,
			Features = {
				ClickRate = 5,
			},
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(146, 146, 146)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(53, 53, 53)),
            }),
            Icon = "rbxassetid://6293578648",
		}
	},

	Boosts = {
		["Friend Invite"] = {
			Description = "For each friend in-game, get +10% shards (max 50%).",
			StackType = "Multiply",
            Icon = "rbxassetid://6293578648",
			Features = {
				ShardMultiplier = 1.1, -- 10% more shards per friend
			}
		},
		["Premium"] = {
			Description = "Get +20% shards while Premium is active.",
			StackType = "Multiply",
			Icon = "rbxassetid://9795349605",
			Features = {
				ShardMultiplier = 1.2, -- 20% more shards while Premium
			}
		},
	},

	Consumables = {
		["x2 Shards 15m"] = {
			Duration = 900,
			ProductId = 1111111111,
			Description = "x2 shards for 15 minutes.",
			RobuxPrice = 19,
			PointPrice = 12000,
			Features = {
				ShardMultiplier = 2,
			},
			Icon = "rbxassetid://138071024126324",
		},
        ["x2 Shards 30min"] = {
			Duration = 1800,
			ProductId = 1111111111,
			Description = "x2 shards for 30 minutes.",
			RobuxPrice = 38,
			PointPrice = 24000,
			Features = {
				ShardMultiplier = 2,
			},
			Icon = "rbxassetid://138071024126324",
		},
        ["x2 Shards 1hr"] = {
			Duration = 3600,
			ProductId = 1111111111,
			Description = "x2 shards for 1 hour.",
			RobuxPrice = 59,
			PointPrice = 48000,
			Features = {
				ShardMultiplier = 2,
			},
			Icon = "rbxassetid://138071024126324",
		},
		["x10 Shards 5min"] = {
			Duration = 300,
			ProductId = 1111111113,
			Description = "x10 shards for 5 minutes.",
			RobuxPrice = 29,
			PointPrice = 25000,
			Features = {
				ShardMultiplier = 10,
			},
			Icon = "rbxassetid://6293578648",
		},
		["Minigame x2 1hr"] = {
			Duration = 3600,
			ProductId = 1111111115,
			Description = "Double rewards from minigames for 1 hour.",
			RobuxPrice = 25,
			PointPrice = 5000,
			Features = {
				MinigameMultiplier = 2,
			},
			Icon = "rbxassetid://6293578648",
		},
	},

    ShardPurchases = {
        {
            Amount = 250000,
            Price = 9,
            Icon = "rbxassetid://6293578648",
        },
        {
            Amount = 1000000,
            Price = 36,
            Icon = "rbxassetid://6293578648",
        },
        {
            Amount = 2500000,
            Price = 75,
            Icon = "rbxassetid://6293578648",
        },
        {
            Amount = 10000000,
            Price = 249,
            Icon = "rbxassetid://6293578648",
        },
        {
            Amount = 20000000,
            Price = 429,
            Icon = "rbxassetid://6293578648",
        },
        {
            Amount = 30000000,
            Price = 599,
            Icon = "rbxassetid://6293578648",
        },
    },

    DailyStreakRewards = {
        [1] = {
            {Type = "Shards", Amount = 5000, Description = "Day 1: 5,000 Shards"},
        },
        [2] = {
            {Type = "Consumable", Consumable = "x2 Shards 15m", Description = "Day 2: x2 Shards Booster (15 min)"},
        },
        [3] = {
            {Type = "Shards", Amount = 15000, Description = "Day 3: 15,000 Shards"},
        },
        [4] = {
            {Type = "Consumable", Consumable = "Minigame x2 1hr", Description = "Day 4: x2 Minigame Booster (1 hr)"},
            {Type = "Shards", Amount = 20000, Description = "Bonus: 20,000 Shards"},
        },
        [5] = {
            {Type = "Consumable", Consumable = "x2 Shards 30min", Description = "Bonus: x2 Shards Booster (30 min)"},
        },
        [6] = {
            {Type = "Consumable", Consumable = "x10 Shards 5min", Description = "Day 6: x10 Shards Booster (5 min)"},
        },
        [7] = {
            {Type = "Shards", Amount = 100000, Description = "Day 7: 100,000 Shards!"},
            {Type = "Consumable", Consumable = "x2 Shards 30min", Description = "Bonus: x2 Shards Booster (30 min)"},
            {Type = "Badge", BadgeId = 123456789, Description = "Day 7: One Week Streak Badge"},
        },
    },

	Titles = {
		-- Unlocked by total shards earned, claims, or milestones
		{Name = "Rookie Collector", Requirement = {Type = "TotalShards", Amount = 10000}},
		{Name = "UGC Enthusiast", Requirement = {Type = "Claims", Amount = 5}},
		{Name = "Shard Tycoon", Requirement = {Type = "TotalShards", Amount = 100000}},
		{Name = "Legendary", Requirement = {Type = "Claims", Amount = 25}},
	},

    FirstPurchaseBonus = {
        Enabled = true,
        AppliesTo = { "DevProduct", "Gamepass" },
        Shards = {
            Multiplier = 2.0,
            MinProductIds = {}, -- empty means applies to all shard packs
        },
        Gamepasses = {
            Shards = 50000,
            Consumables = {
                ["x2 Shards 15m"] = 2,
            },
        },
        Cosmetics = {
            Title = "Investor", BadeId = 123456789,
        },
        Eligibility = {
            IgnoreIfHasSpentBefore = true, -- If player has spent any Robux before, they are not eligible
            NewUserGraceHours = 72, -- New users have 72 hours to make their first purchase
        },
    }

}

return AFKPointConfig
