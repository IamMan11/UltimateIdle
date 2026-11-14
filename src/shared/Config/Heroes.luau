--!strict
-- Hero classes: level-1 stats, preferred row, gold price, display order.

local Freeze = require(script.Parent.Parent.Freeze)

export type HeroDef = {
	Id: string,
	Order: number,
	PreferredRow: string,
	Price: number,
	MaxHp: number,
	Atk: number,
	Def: number,
	AtkInterval: number,
	Range: number,
	Speed: number,
	Splash: number,
	Heal: number,
}

local list: { HeroDef } = {
	{
		Id = "Warrior",
		Order = 1,
		PreferredRow = "Front",
		Price = 1000,
		MaxHp = 160,
		Atk = 12,
		Def = 6,
		AtkInterval = 1.0,
		Range = 4,
		Speed = 10,
		Splash = 0,
		Heal = 0,
	},
	{
		Id = "Mage",
		Order = 2,
		PreferredRow = "Middle",
		Price = 1000,
		MaxHp = 90,
		Atk = 17,
		Def = 3,
		AtkInterval = 1.4,
		Range = 22,
		Speed = 9,
		Splash = 2,
		Heal = 0,
	},
	{
		Id = "Archer",
		Order = 3,
		PreferredRow = "Back",
		Price = 1000,
		MaxHp = 100,
		Atk = 14,
		Def = 4,
		AtkInterval = 0.9,
		Range = 26,
		Speed = 12,
		Splash = 0,
		Heal = 0,
	},
	{
		Id = "Healer",
		Order = 4,
		PreferredRow = "Back",
		Price = 5000,
		MaxHp = 95,
		Atk = 6,
		Def = 4,
		AtkInterval = 1.2,
		Range = 20,
		Speed = 9,
		Splash = 0,
		Heal = 14,
	},
}

local byId: { [string]: HeroDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	List = list,
	ById = byId,
})
