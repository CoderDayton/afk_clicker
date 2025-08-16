--!strict
-- Cheap guard: never return a timestamp lower than the last one we returned.

local TimeGuard = {}

local last = os.time() -- start with current wall clock

function TimeGuard.now(): number
	local t = os.time()
	if t < last then
		-- clamp tiny backwards jumps (NTP, server drift)
		t = last
	end
	-- If you want to also clamp huge forward jumps, uncomment next two lines:
	local MAX_STEP = 60 * 10 -- 10 minutes
	if t - last > MAX_STEP then t = last + MAX_STEP end

	last = t
	return t
end

return TimeGuard
