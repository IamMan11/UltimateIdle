--!strict
-- Display formatting: large numbers with suffixes (1.5T, 3.2Qa) and durations (1h 05m).

local SMALL = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local UNIT = { "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "N" }
local GROUP = { "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Ng" }
local GROUP_TAIL = { "d", "vg", "tg", "qag", "qig", "sxg", "spg", "ocg", "ng" }

-- SUFFIXES[t] is the suffix for 1000^t; past the end we fall back to scientific notation.
local SUFFIXES: { string } = {}
for t = 1, #SMALL do
	SUFFIXES[t] = SMALL[t]
end
for illion = 10, 99 do
	local group, unit = illion // 10, illion % 10
	SUFFIXES[illion + 1] = if unit == 0 then GROUP[group] else UNIT[unit] .. GROUP_TAIL[group]
end
table.freeze(SUFFIXES)

local EPSILON = 1e-9

-- Truncates (never rounds up) so a value just under the next tier never shows as "1000K".
local function trimmed(value: number): string
	local decimals = if value < 10 then 2 elseif value < 100 then 1 else 0
	local scale = 10 ^ decimals
	local cut = math.floor(value * scale + EPSILON) / scale
	local text = string.format("%." .. decimals .. "f", cut)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text
end

local Format = {}

function Format.Number(n: number): string
	if n ~= n then
		return "NaN"
	end
	if n == math.huge then
		return "inf"
	end
	if n == -math.huge then
		return "-inf"
	end

	local sign = if n < 0 then "-" else ""
	local abs = math.abs(n)
	if abs < 1000 then
		return sign .. trimmed(abs)
	end

	local tier = math.floor(math.log10(abs) / 3)
	local value = abs / 1000 ^ tier
	if value >= 1000 then
		tier += 1
		value /= 1000
	elseif value < 1 then
		tier -= 1
		value *= 1000
	end

	local suffix = SUFFIXES[tier]
	if suffix == nil then
		local exponent = math.floor(math.log10(abs))
		return sign .. trimmed(abs / 10 ^ exponent) .. "e" .. exponent
	end
	return sign .. trimmed(value) .. suffix
end

-- Two largest units: "2d 03h", "1h 05m", "4m 09s", "37s".
function Format.Time(seconds: number): string
	if seconds ~= seconds or seconds <= 0 then
		return "0s"
	end
	if seconds == math.huge then
		return "inf"
	end

	local s = math.floor(seconds)
	local days = s // 86400
	local hours = (s % 86400) // 3600
	local minutes = (s % 3600) // 60
	local secs = s % 60

	if days > 0 then
		return string.format("%dd %02dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

return table.freeze(Format)
