--[[
    Maid.lua
    Enhanced utility for cleaning up resources for better memory.

    --

    License: MIT License
    See LICENSE file in the repository root for full license text.
--]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	local self = setmetatable({}, Maid)
	self._tasks = {}
	return self
end

function Maid:GiveTask(task)
	local n = #self._tasks + 1
	self._tasks[n] = task

	return function()
		if self._tasks[n] then
			self:_doTask(self._tasks[n])
			self._tasks[n] = nil
		end
	end
end

function Maid:DoCleaningByType(type)
	local tasksToKeep = {}
	for i = 1, #self._tasks do
		local task = self._tasks[i]
		if typeof(task) == type then
			self:_doTask(task)
		else
			table.insert(tasksToKeep, task)
		end
	end
	self._tasks = tasksToKeep
end

function Maid:DoCleaning()
	local tasksToClean = self._tasks
	self._tasks = {}

	for i = 1, #tasksToClean do
		self:_doTask(tasksToClean[i])
	end
end

function Maid:_doTask(task)
	if not task then
		return
	end

	local taskType = typeof(task)

	if taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "Instance" then
		if task.Parent then
			task:Destroy()
		end
	elseif taskType == "function" then
		task()
	elseif taskType == "thread" then
		if coroutine.status(task) ~= "dead" then
			coroutine.close(task)
		end
	elseif taskType == "table" and task.Destroy then
		task:Destroy()
	elseif taskType == "userdata" and task.disconnect then
		task:disconnect()
	elseif taskType == "table" and task.Cancel then
		task:Cancel()
	end
end

return Maid :: {
	new: () -> {
		GiveTask: (self: any, task: any) -> (),
		DoCleaningByType: () -> (),
		DoCleaning: () -> (),
	},
}
