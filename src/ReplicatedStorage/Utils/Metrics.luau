--!strict
-- Minimal counters you can reuse anywhere.

local Metrics = {}
local counters: { [string]: number } = {}

function Metrics.inc(name: string, by: number?)
	local n = counters[name] or 0
	counters[name] = n + (by or 1)
end

function Metrics.add(name: string, by: number)
	Metrics.inc(name, by)
end

function Metrics.snapshot(): { [string]: number }
	-- return a shallow copy
	local copy = table.clone(counters)
	return copy
end

function Metrics.dump(prefix: string?)
	prefix = prefix or "[Metrics]"
	local parts = {}
	for k, v in pairs(counters) do
		table.insert(parts, string.format("%s=%d", k, v))
	end
	print(prefix, table.concat(parts, "  "))
end

return Metrics
