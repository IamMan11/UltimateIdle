--!strict
-- Every remote event (Red) with its payload shape check. Handlers re-check ranges/ownership server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage.Packages.Red)
local Types = require(script.Parent.Types)

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

-- String-keyed positive integer counts (materials / boxes in a trade offer).
local function countMap(value: unknown, maxCount: number, maxLen: number, maxN: number): { [string]: number }
	assert(type(value) == "table", "bad argument")
	local out: { [string]: number } = {}
	local n = 0
	for k, v in value :: { [unknown]: unknown } do
		n += 1
		assert(n <= maxCount, "bad argument")
		out[str(k, maxLen)] = int(v, 1, maxN)
	end
	return out
end

local function nonNegative(value: unknown): number
	local n = num(value)
	assert(n >= 0 and n <= 1e300, "bad argument")
	return n
end

local function bool(value: unknown): boolean
	assert(type(value) == "boolean", "bad argument")
	return value
end

local function tradeOffer(value: unknown): Types.TradeOffer
	assert(type(value) == "table", "bad argument")
	local t = value :: { [unknown]: unknown }
	return {
		Gear = strList(if t.Gear == nil then {} else t.Gear, 50, 16),
		Stacks = countMap(if t.Stacks == nil then {} else t.Stacks, 20, 32, 1e12),
		Boxes = countMap(if t.Boxes == nil then {} else t.Boxes, 20, 40, 1e6),
		Gold = nonNegative(if t.Gold == nil then 0 else t.Gold),
		Ruby = nonNegative(if t.Ruby == nil then 0 else t.Ruby),
	}
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
	LaneTimeline = Red.Event("LaneTimeline", function(userId: unknown, payload: unknown)
		return userId :: number, payload :: Types.TimelinePayload?
	end),
	TradeState = Red.Event("TradeState", function(tradeView: unknown)
		return tradeView :: Types.TradeView?
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
	Rebirth = Red.Event("Rebirth", function() end),
	SetPlayRebirth = Red.Event("SetPlayRebirth", function(index: unknown)
		return int(index, 0, 10000)
	end),
	Enhance = Red.Event("Enhance", function(uid: unknown)
		return str(uid, 16)
	end),
	MergeSocket = Red.Event("MergeSocket", function(main: unknown, material: unknown)
		return str(main, 16), str(material, 16)
	end),
	UseSocketCore = Red.Event("UseSocketCore", function(uid: unknown)
		return str(uid, 16)
	end),
	SetSocketKind = Red.Event("SetSocketKind", function(uid: unknown, index: unknown, kind: unknown)
		return str(uid, 16), int(index, 1, 10), str(kind, 16)
	end),
	InsertSocket = Red.Event("InsertSocket", function(uid: unknown, index: unknown, id: unknown)
		return str(uid, 16), int(index, 1, 10), str(id, 32)
	end),
	RemoveInsert = Red.Event("RemoveInsert", function(uid: unknown, index: unknown)
		return str(uid, 16), int(index, 1, 10)
	end),
	Enchant = Red.Event("Enchant", function(uid: unknown)
		return str(uid, 16)
	end),
	TradeRequest = Red.Event("TradeRequest", function(userId: unknown)
		return int(userId, 1, 1e15)
	end),
	TradeRespond = Red.Event("TradeRespond", function(userId: unknown, accept: unknown)
		return int(userId, 1, 1e15), bool(accept)
	end),
	TradeOffer = Red.Event("TradeOffer", function(offer: unknown)
		return tradeOffer(offer)
	end),
	TradeReady = Red.Event("TradeReady", function(on: unknown)
		return bool(on)
	end),
	TradeConfirm = Red.Event("TradeConfirm", function() end),
	TradeCancel = Red.Event("TradeCancel", function() end),
	ClaimQuest = Red.Event("ClaimQuest", function(id: unknown)
		return str(id, 32)
	end),
	ClaimPass = Red.Event("ClaimPass", function(track: unknown, tier: unknown)
		return str(track, 8), int(tier, 0, 100)
	end),
	BuyPass = Red.Event("BuyPass", function(key: unknown)
		return str(key, 32)
	end),
	GiftPass = Red.Event("GiftPass", function(key: unknown, userId: unknown)
		return str(key, 32), int(userId, 1, 1e15)
	end),
	BuyPremium = Red.Event("BuyPremium", function() end),
	BuyShopItem = Red.Event("BuyShopItem", function(id: unknown)
		return str(id, 32)
	end),
	WatchLane = Red.Event("WatchLane", function(userId: unknown)
		return int(userId, 0, 1e15)
	end),
	TutorialSkip = Red.Event("TutorialSkip", function() end),
	TutorialRestart = Red.Event("TutorialRestart", function() end),
	ClaimDaily = Red.Event("ClaimDaily", function() end),
	RedeemCode = Red.Event("RedeemCode", function(text: unknown)
		return str(text, 32)
	end),
	RequestRejoin = Red.Event("RequestRejoin", function() end),
	DevCommand = Red.Event("DevCommand", function(cmd: unknown, arg: unknown)
		return str(cmd, 16), num(arg)
	end),
}

return Net
