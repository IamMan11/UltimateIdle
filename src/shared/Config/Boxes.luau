--!strict
-- Loot boxes: kinds (stack caps, gear per open), level bands and rebirth in the stack key, class-box conversion. Contents tables live in server Secret/.

local Freeze = require(script.Parent.Parent.Freeze)
local Rebirth = require(script.Parent.Rebirth)

export type BoxDef = {
	Id: string,
	Order: number,
	Max: number,
	GearPerOpen: number,
	Class: string?, -- class boxes only give gear labelled with this class
}

local BAND_SIZE = 25

local list: { BoxDef } = {
	{ Id = "Normal", Order = 1, Max = 25, GearPerOpen = 1 },
	{ Id = "Boss", Order = 2, Max = 25, GearPerOpen = 2 },
}

for i, class in { "Warrior", "Mage", "Archer", "Healer" } do
	table.insert(list, { Id = `Class_{class}`, Order = 10 + i, Max = 10, GearPerOpen = 1, Class = class })
end

local byId: { [string]: BoxDef } = {}
for _, def in list do
	byId[def.Id] = def
end

export type BoxKey = {
	Kind: string,
	Rebirth: number,
	Band: number,
}

local Boxes = {
	List = list,
	ById = byId,
	BandSize = BAND_SIZE,
	-- Either of these kinds converts into a class box of the same rebirth + band.
	ConvertSources = { "Normal", "Boss" },
	ConvertCost = 5,
}

-- Band 1 = levels 1-25, band 2 = 26-50, ...
function Boxes.Band(level: number): number
	return math.max(1, math.ceil(level / BAND_SIZE))
end

-- Item level range a band rolls in, clamped to the rebirth's item level cap.
function Boxes.BandRange(band: number, rebirth: number): (number, number)
	local cap = Rebirth.Get(rebirth).ItemLevelCap
	local low = math.min((band - 1) * BAND_SIZE + 1, cap)
	return low, math.min(band * BAND_SIZE, cap)
end

-- Stack key stored in ProfileData.Boxes: "<Kind>:<rebirth>:<band>".
function Boxes.Key(kind: string, rebirth: number, band: number): string
	return `{kind}:{rebirth}:{band}`
end

function Boxes.Parse(key: string): BoxKey?
	local kind, r, b = string.match(key, "^([%w_]+):(%d+):(%d+)$")
	if kind == nil or byId[kind] == nil then
		return nil
	end
	local rebirth, band = tonumber(r), tonumber(b)
	if rebirth == nil or band == nil or band < 1 or rebirth > 10000 or band > 100000 then
		return nil
	end
	return { Kind = kind, Rebirth = rebirth, Band = band }
end

return Freeze(Boxes)
