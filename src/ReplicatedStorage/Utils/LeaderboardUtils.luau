local LeaderboardUtils = {}

local function formatRobux(n)
	n = tonumber(n) or 0
	local s = tostring(n)
	local new = ""
	local count = 0
	for i = #s, 1, -1 do
		count += 1
		new = s:sub(i, i) .. new
		if count % 3 == 0 and i > 1 then
			new = "," .. new
		end
	end
	return new
end

function LeaderboardUtils.CreateRecentEntry(parent, userId, playerName, itemName, price)
	local template = game.ReplicatedStorage:WaitForChild("LeaderboardEntryTemplate_Recent")
	local entry = template:Clone()
	entry.Parent = parent

	entry.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=100&h=100"
	entry.Content.PlayerName.Text = playerName or ""
	entry.Content.ItemName.Text = itemName or ""
	entry.RobuxRow.RobuxAmount.Text = formatRobux(price)

	return entry
end

function LeaderboardUtils.CreateTopSpenderEntry(parent, userId, playerName, robuxAmount, rank)
	local template = game.ReplicatedStorage:WaitForChild("LeaderboardEntryTemplate_Top")
	local entry = template:Clone()
	entry.Parent = parent

	entry.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=100&h=100"
	entry.Content.PlayerName.Text = playerName or ""
	entry.Content.RobuxRow.RobuxAmount.Text = formatRobux(robuxAmount)
	entry.RankLabel.Text = "#" .. tostring(rank)

	return entry
end

return LeaderboardUtils
