--!strict
-- UTC reset periods (day / ISO week from Monday / month): a stable key per period and the time the period ends.

export type Kind = "Daily" | "Weekly" | "Monthly"

local DAY = 86400

local Period = {}

local kinds: { Kind } = { "Daily", "Weekly", "Monthly" }
-- Every period kind, in reset-length order.
function Period.List(): { Kind }
	return kinds
end

local function utc(t: number): { Year: number, Month: number, Day: number }
	-- The Roblox definitions type ToUniversalTime() as { any }; the fields used are documented (Year/Month/Day).
	local parts: any = DateTime.fromUnixTimestamp(t):ToUniversalTime()
	return { Year = parts.Year, Month = parts.Month, Day = parts.Day }
end

-- Unix day number of the Monday that starts t's week (1970-01-01 was a Thursday).
local function weekStart(t: number): number
	local days = t // DAY
	return days - (days + 3) % 7
end

function Period.Key(kind: Kind, t: number?): string
	local now = t or os.time()
	if kind == "Daily" then
		local d = utc(now)
		return string.format("%04d-%02d-%02d", d.Year, d.Month, d.Day)
	elseif kind == "Weekly" then
		return `W{weekStart(now)}`
	end
	local d = utc(now)
	return string.format("%04d-%02d", d.Year, d.Month)
end

-- os.time() at which the period containing t ends.
function Period.Ends(kind: Kind, t: number?): number
	local now = t or os.time()
	if kind == "Daily" then
		return (now // DAY + 1) * DAY
	elseif kind == "Weekly" then
		return (weekStart(now) + 7) * DAY
	end
	local d = utc(now)
	local year, month = d.Year, d.Month + 1
	if month > 12 then
		year, month = year + 1, 1
	end
	return DateTime.fromUniversalTime(year, month, 1).UnixTimestamp
end

return table.freeze(Period)
