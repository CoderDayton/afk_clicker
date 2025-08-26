local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local DailyRewardUI = require(script.Parent.DailyRewardUI)

print("Creating DailyRewardUI instance...")
DailyRewardUI.new()
print("Showing UI...")
DailyRewardUI:show()