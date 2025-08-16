
local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local PopulateLeaderboard = RR.get(game.ServerScriptService.PopulateLeaderboard)

while true do
	task.wait(60)
	PopulateLeaderboard.Populate()
end