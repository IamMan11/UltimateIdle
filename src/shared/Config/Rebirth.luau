--!strict
-- Per-rebirth table (index 0 = before any rebirth): unlock level, caps, difficulty, one-time rewards, points, account bonus.

local Freeze = require(script.Parent.Parent.Freeze)

export type RebirthDef = {
	Index: number,
	RequiredLevel: number, -- clear this level in the previous rebirth to unlock this one (0 for index 0)
	HeroLevelCap: number,
	ItemLevelCap: number,
	Difficulty: number, -- monster stat multiplier while this rebirth is played
	FarmRoundCap: number, -- farm round ends (lump paid) when this level is cleared
	AccountLevelCap: number,
	WearCaps: { number }, -- highest item level a hero may wear, by class advancement (index 1 = not advanced)
	Points: number, -- rebirth points granted when reaching this rebirth
	Items: { [string]: number }, -- materials granted when reaching this rebirth
	GoldPct: number, -- account-wide bonus while this many rebirths are owned (not stacked with lower ones)
	XpPct: number,
}

local MAX_REBIRTH = 20
local CAP_BASE, CAP_STEP = 150, 50

local function round10(n: number): number
	return math.floor(n / 10 + 0.5) * 10
end

local list: { RebirthDef } = {}
for i = 0, MAX_REBIRTH do
	local cap = CAP_BASE + CAP_STEP * i
	table.insert(list, {
		Index = i,
		RequiredLevel = if i == 0 then 0 else CAP_BASE + CAP_STEP * (i - 1),
		HeroLevelCap = cap,
		ItemLevelCap = cap,
		Difficulty = 1.8 ^ i,
		FarmRoundCap = 1000 + 250 * i,
		AccountLevelCap = 100 + 25 * i,
		WearCaps = { round10(cap * 0.4), round10(cap * 0.73), cap },
		Points = i,
		Items = if i == 0
			then {}
			else { EnhanceStone = 100 * i, EnchantDust = 20 * i, SocketCore = i, AncientShard = 2 * i },
		GoldPct = 0.05 * i,
		XpPct = 0.05 * i,
	})
end

local Rebirth = {
	List = list,
	Max = MAX_REBIRTH,
}

function Rebirth.Get(index: number): RebirthDef
	return list[math.clamp(index + 1, 1, #list)]
end

-- The rebirth unlocked by the next Rebirth action, or nil at the top.
function Rebirth.Next(count: number): RebirthDef?
	return if count < MAX_REBIRTH then list[count + 2] else nil
end

function Rebirth.WearCap(index: number, advancement: number): number
	local caps = Rebirth.Get(index).WearCaps
	return caps[math.clamp(advancement + 1, 1, #caps)]
end

return Freeze(Rebirth)
