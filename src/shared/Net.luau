--!strict
-- Every remote event (Red) with its payload shape check. Handlers re-check ranges/ownership server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage.Packages.Red)

-- Shape checks: Red runs these in pcall on the server and drops the call when they error.
local function str(value: unknown, maxLen: number): string
	assert(type(value) == "string" and #value > 0 and #value <= maxLen, "bad argument")
	return value
end

local function int(value: unknown, min: number, max: number): number
	assert(
		type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max,
		"bad argument"
	)
	return value
end

local function num(value: unknown): number
	assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge, "bad argument")
	return value
end

local function strList(value: unknown, maxCount: number, maxLen: number): { string }
	assert(type(value) == "table", "bad argument")
	local out: { string } = {}
	for i, v in value :: { [unknown]: unknown } do
		assert(type(i) == "number" and i % 1 == 0 and i >= 1 and i <= maxCount, "bad argument")
		out[i] = str(v, maxLen)
	end
	assert(#out <= maxCount, "bad argument")
	return out
end

-- Team list: 1..4 entries of { HeroId, Row }; the server checks ownership, slot count and row capacity.
local function teamList(value: unknown): { { HeroId: string, Row: string } }
	assert(type(value) == "table", "bad argument")
	local out: { { HeroId: string, Row: string } } = {}
	for i, v in value :: { [unknown]: unknown } do
		assert(type(i) == "number" and i % 1 == 0 and i >= 1 and i <= 4 and type(v) == "table", "bad argument")
		local entry = v :: { [unknown]: unknown }
		out[i] = { HeroId = str(entry.HeroId, 16), Row = str(entry.Row, 8) }
	end
	assert(#out >= 1 and #out <= 4, "bad argument")
	return out
end

local function scalar(value: unknown): boolean | number | string
	assert(type(value) == "boolean" or type(value) == "number" or type(value) == "string", "bad argument")
	return value :: any
end

local Net = {
	-- server -> client (the validators are never run for these; they only carry the payload type)
	StateSnapshot = Red.Event("StateSnapshot", function(data: unknown)
		return data :: any
	end),
	StateDelta = Red.Event("StateDelta", function(changes: unknown)
		return changes :: { { any } }
	end),
	StageTimeline = Red.Event("StageTimeline", function(payload: unknown)
		return payload :: any
	end),
	Notice = Red.Event("Notice", function(kind: unknown, payload: unknown)
		return kind :: string, payload :: any
	end),

	-- client -> server
	RequestSnapshot = Red.Event("RequestSnapshot", function() end),
	ChooseFirstHero = Red.Event("ChooseFirstHero", function(class: unknown)
		return str(class, 16)
	end),
	BuyHero = Red.Event("BuyHero", function(class: unknown)
		return str(class, 16)
	end),
	SetStageMode = Red.Event("SetStageMode", function(mode: unknown)
		return str(mode, 16)
	end),
	SetSetting = Red.Event("SetSetting", function(key: unknown, sub: unknown, value: unknown)
		return str(key, 32), if sub == nil then nil else str(sub, 32), scalar(value)
	end),
	Equip = Red.Event("Equip", function(heroId: unknown, uid: unknown, slot: unknown)
		return str(heroId, 16), str(uid, 16), str(slot, 16)
	end),
	Unequip = Red.Event("Unequip", function(heroId: unknown, slot: unknown)
		return str(heroId, 16), str(slot, 16)
	end),
	Salvage = Red.Event("Salvage", function(uids: unknown)
		return strList(uids, 100, 16)
	end),
	OpenBox = Red.Event("OpenBox", function(boxId: unknown, count: unknown)
		return str(boxId, 32), int(count, 1, 1000)
	end),
	ConvertBox = Red.Event("ConvertBox", function(source: unknown, class: unknown, count: unknown)
		return str(source, 32), str(class, 16), int(count, 1, 100)
	end),
	SetTeam = Red.Event("SetTeam", function(entries: unknown)
		return teamList(entries)
	end),
	Advance = Red.Event("Advance", function(heroId: unknown)
		return str(heroId, 16)
	end),
	BuyNode = Red.Event("BuyNode", function(id: unknown)
		return str(id, 32)
	end),
	ToggleNode = Red.Event("ToggleNode", function(id: unknown, on: unknown)
		assert(type(on) == "boolean", "bad argument")
		return str(id, 32), on
	end),
	RequestRejoin = Red.Event("RequestRejoin", function() end),
	DevCommand = Red.Event("DevCommand", function(cmd: unknown, arg: unknown)
		return str(cmd, 16), num(arg)
	end),
}

return Net
