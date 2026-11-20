--!strict
-- Rich-text accents: stat phrases ("+16.4K HP", "Attack +12", "220% attack", "9s cooldown") and tier names get their
-- Theme.Stat / Theme.Tier colour. Everything else is escaped plain text.

local Theme = require(script.Parent.Theme)

local Rich = {}

-- Longest phrases first so "attack speed" wins over "attack".
local KEYWORDS: { { string } } = {
	{ "attack speed", "Speed" },
	{ "move speed", "Speed" },
	{ "team speed", "Speed" },
	{ "skill power", "Skill" },
	{ "heal power", "Heal" },
	{ "healing", "Heal" },
	{ "cooldowns", "Cooldown" },
	{ "cooldown", "Cooldown" },
	{ "attack", "Atk" },
	{ "atk", "Atk" },
	{ "defense", "Def" },
	{ "def", "Def" },
	{ "hp", "Hp" },
	{ "speed", "Speed" },
	{ "range", "Range" },
	{ "gold", "Gold" },
	{ "xp", "Xp" },
	{ "gs", "Gs" },
}
local TIERS = { "Uncommon", "Common", "Rare" }

-- A number token next to a keyword: "+16.4K", "220%", "9s", "x1.8".
local NUMBER = "[%+%-x]?%d[%d%.,]*%a*%%?"

local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- `value` (already escaped) in bold `color`: Michroma has no bold face, so the glyphs get a stroke in the same colour.
function Rich.Bold(value: string, color: Color3, size: number?): string
	local c = hex(color)
	return `<font color="{c}"><stroke color="{c}" thickness="{Theme.Heavy(size or 14)}">{value}</stroke></font>`
end

-- `value` (already escaped) in bold, in an accent colour (its light shade on dark plates).
function Rich.Wrap(value: string, accent: Theme.Accent, onDark: boolean?, size: number?): string
	return Rich.Bold(value, if onDark then accent.Light else accent.Color, size)
end

type Span = { From: number, To: number, Accent: Theme.Accent }

local function overlaps(spans: { Span }, a: number, b: number): boolean
	for _, span in spans do
		if a <= span.To and b >= span.From then
			return true
		end
	end
	return false
end

-- Plain text -> rich text with every stat phrase and tier name in bold colour (`size` = drawn text size). `onDark` = light shades for leather plates.
function Rich.Stats(text: string, onDark: boolean?, size: number?): string
	local lower = string.lower(text)
	local spans: { Span } = {}
	local stats = Theme.Stat :: { [string]: Theme.Accent }
	for _, entry in KEYWORDS do
		local word, key = entry[1], entry[2]
		local pattern = "%f[%w]" .. string.gsub(word, " ", "%%s") .. "%f[%W]"
		local init = 1
		while true do
			local a, b = string.find(lower, pattern, init)
			if a == nil or b == nil then
				break
			end
			init = b + 1
			-- Take the number after the word ("Attack +12"), else the one before it ("+12 Attack"), on the same line.
			local _, right = string.find(text, "^ +" .. NUMBER, b + 1)
			if right ~= nil then
				b = right
			else
				local left = string.find(string.sub(text, 1, a - 1), NUMBER .. " +$")
				if left ~= nil then
					a = left
				end
			end
			if not overlaps(spans, a, b) then
				table.insert(spans, { From = a, To = b, Accent = stats[key] })
			end
		end
	end
	for _, tier in TIERS do
		local accent = Theme.TierAccent(tier)
		local init = 1
		while accent ~= nil do
			local a, b = string.find(text, "%f[%w]" .. tier .. "%f[%W]", init)
			if a == nil or b == nil then
				break
			end
			init = b + 1
			if not overlaps(spans, a, b) then
				table.insert(spans, { From = a, To = b, Accent = accent })
			end
		end
	end
	if #spans == 0 then
		return escape(text)
	end
	table.sort(spans, function(x, y)
		return x.From < y.From
	end)
	local out: { string } = {}
	local at = 1
	for _, span in spans do
		table.insert(out, escape(string.sub(text, at, span.From - 1)))
		table.insert(out, Rich.Wrap(escape(string.sub(text, span.From, span.To)), span.Accent, onDark, size))
		at = span.To + 1
	end
	table.insert(out, escape(string.sub(text, at)))
	return table.concat(out)
end

return Rich
