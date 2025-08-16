-- Central server-side remote event registration

local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)

-- List all remote signal names used in the project
local SIGNAL_NAMES = {
	"ShardUpdate",
	"ShardSpendRequest",
	"ShardSpendResult",
	"ShardBonusRequest",
	"ShardBonusResult",
	"ShardMinigameRequest",
	"ShardMinigameResult",
	"ConsumableUpdate",
    "DailyRewardClaim",
    "DailyRewardStatus",
    "DailyRewardResult"
}

for _, name in ipairs(SIGNAL_NAMES) do
	RemoteSignal.new(name)
end

print("[RemoteSignalInit] All RemoteSignals initialized on server.")
