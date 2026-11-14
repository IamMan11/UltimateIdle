--!strict
-- Value checks for remote arguments and economy math: finite numbers, integer ranges, membership.

local Guard = {}

function Guard.Finite(n: unknown): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Finite and >= 0.
function Guard.Amount(n: unknown): boolean
	return Guard.Finite(n) and (n :: number) >= 0
end

function Guard.Int(n: unknown, min: number, max: number): boolean
	return Guard.Finite(n) and (n :: number) % 1 == 0 and (n :: number) >= min and (n :: number) <= max
end

function Guard.OneOf(value: unknown, options: { string }): boolean
	return type(value) == "string" and table.find(options, value) ~= nil
end

function Guard.Key<V>(value: unknown, map: { [string]: V }): boolean
	return type(value) == "string" and map[value] ~= nil
end

return table.freeze(Guard)
