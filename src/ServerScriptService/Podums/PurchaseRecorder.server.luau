local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local LeaderboardData = RR.get(game.ServerScriptService.LeaderboardData)

game.ReplicatedStorage.PurchaseMade.OnServerEvent:Connect(function(player, itemName, price)
	LeaderboardData.RecordPurchase(player.UserId, player.Name, itemName, price)
end)