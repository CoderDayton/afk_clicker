local RR = require(game.ReplicatedStorage.Utils.RobustRequire)
local RemoteSignal = RR.get(game.ReplicatedStorage.Utils.RemoteSignal)

local AdminMessage = RemoteSignal.new("AdminMessage")

local TextChatService = game:GetService("TextChatService")
local TextChannels = TextChatService:WaitForChild("TextChannels")
local SystemChannel = TextChannels:WaitForChild("RBXSystem")

AdminMessage:Connect(function(message)
	SystemChannel:DisplaySystemMessage(message)
end)
