--!strict
-- Monster kinds: level-1 stats, rewards, from which stage level they appear. Index in List = id on the wire.

local Freeze = require(script.Parent.Parent.Freeze)

export type MonsterDef = {
	Id: string,
	Index: number,
	Boss: boolean,
	FromLevel: number,
	Weight: number,
	MaxHp: number,
	Atk: number,
	Def: number,
	AtkInterval: number,
	Range: number,
	MoveSpeed: number,
	Gold: number,
	Xp: number,
	Scale: number, -- model size multiplier
}

local list: { MonsterDef } = {
	{
		Id = "Slime",
		Index = 1,
		Boss = false,
		FromLevel = 1,
		Weight = 10,
		MaxHp = 24,
		Atk = 3,
		Def = 0,
		AtkInterval = 1.3,
		Range = 3,
		MoveSpeed = 6,
		Gold = 3,
		Xp = 2,
		Scale = 0.8,
	},
	{
		Id = "Goblin",
		Index = 2,
		Boss = false,
		FromLevel = 3,
		Weight = 8,
		MaxHp = 20,
		Atk = 4,
		Def = 1,
		AtkInterval = 0.9,
		Range = 3,
		MoveSpeed = 9,
		Gold = 4,
		Xp = 2,
		Scale = 0.9,
	},
	{
		Id = "SkeletonArcher",
		Index = 3,
		Boss = false,
		FromLevel = 8,
		Weight = 6,
		MaxHp = 18,
		Atk = 4,
		Def = 0,
		AtkInterval = 1.2,
		Range = 7,
		MoveSpeed = 6,
		Gold = 4,
		Xp = 3,
		Scale = 1,
	},
	{
		Id = "Orc",
		Index = 4,
		Boss = false,
		FromLevel = 15,
		Weight = 5,
		MaxHp = 50,
		Atk = 5,
		Def = 3,
		AtkInterval = 1.5,
		Range = 3,
		MoveSpeed = 5,
		Gold = 6,
		Xp = 4,
		Scale = 1.15,
	},
	{
		Id = "OgreKing",
		Index = 5,
		Boss = true,
		FromLevel = 1,
		Weight = 1,
		MaxHp = 200,
		Atk = 8,
		Def = 3,
		AtkInterval = 1.6,
		Range = 4,
		MoveSpeed = 4,
		Gold = 40,
		Xp = 20,
		Scale = 1.7,
	},
}

local byId: { [string]: MonsterDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	List = list,
	ById = byId,
})
