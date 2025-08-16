--!strict
-- Simple cancellable timer that calls a function every intervalSec.
-- This is useful for periodic tasks that need to be cancellable.

local Ticker = {}

export type Token = { cancel: () -> () }

function Ticker.start(intervalSec: number, fn: () -> ()): Token
	local cancelled = false

	local function tick()
		if cancelled then return end
		-- protect the callback; if it errors, we don't kill the ticker silently
		local ok, err = pcall(fn)
		if not ok then
			warn("[Ticker] callback error:", err)
		end
		if cancelled then return end
		task.delay(intervalSec, tick)
	end

	-- fire first tick immediately (0 delay)
	task.delay(0, tick)

	return {
		cancel = function()
			cancelled = true
		end,
	}
end

return Ticker
