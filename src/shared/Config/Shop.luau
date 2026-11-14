--!strict
-- Monetization + monthly shop: game passes (x2 gold / x2 xp, giftable), developer products, shop items with monthly quotas (UTC month).
-- Ids of 0 = not created on the Creator page yet (buttons show as unavailable).

local Freeze = require(script.Parent.Parent.Freeze)
local Types = require(script.Parent.Parent.Types)

export type PassDef = {
	Key: string,
	Order: number,
	PassId: number, -- game pass asset id
	GiftProduct: string, -- Products key of the developer product that gifts this pass
	Mult: number,
}

export type Currency = "Gold" | "Ruby" | "Robux"

export type ShopItem = {
	Id: string,
	Order: number,
	Currency: Currency,
	Price: number, -- Gold: gold-level units (Formula.Economy.Gold) · Ruby: flat · Robux: shown only (set on the product)
	Product: string?, -- Products key (Robux items)
	Quota: number, -- per UTC month
	Reward: Types.Reward,
}

local passes: { PassDef } = {
	{ Key = "Gold2x", Order = 1, PassId = 0, GiftProduct = "GiftGold2x", Mult = 2 },
	{ Key = "Xp2x", Order = 2, PassId = 0, GiftProduct = "GiftXp2x", Mult = 2 },
}

-- Developer product ids by key. Every Robux grant in the game is listed here.
local products: { [string]: number } = {
	GiftGold2x = 0,
	GiftXp2x = 0,
	PremiumPass = 0,
	ShopRuby = 0,
	ShopCores = 0,
}

-- Robux shown on buttons (the real price is whatever the product is set to on the Creator page).
local robuxPrices: { [string]: number } = {
	GiftGold2x = 199,
	GiftXp2x = 199,
	PremiumPass = 299,
	ShopRuby = 99,
	ShopCores = 149,
}

-- No box is sold for Robux or Ruby (Ruby is bought with Robux): paid random items are restricted in some regions.
local items: { ShopItem } = {
	{
		Id = "Stones",
		Order = 1,
		Currency = "Gold",
		Price = 15,
		Quota = 10,
		Reward = { Materials = { EnhanceStone = 30 } },
	},
	{ Id = "BossBoxes", Order = 2, Currency = "Gold", Price = 25, Quota = 5, Reward = { Boxes = { Boss = 3 } } },
	{
		Id = "DustSmall",
		Order = 3,
		Currency = "Gold",
		Price = 30,
		Quota = 5,
		Reward = { Materials = { EnchantDust = 5 } },
	},
	{ Id = "Dust", Order = 4, Currency = "Ruby", Price = 60, Quota = 5, Reward = { Materials = { EnchantDust = 15 } } },
	{
		Id = "Shards",
		Order = 5,
		Currency = "Ruby",
		Price = 80,
		Quota = 5,
		Reward = { Materials = { AncientShard = 3 } },
	},
	{ Id = "Core", Order = 6, Currency = "Ruby", Price = 150, Quota = 3, Reward = { Materials = { SocketCore = 1 } } },
	{
		Id = "GoldIdol",
		Order = 7,
		Currency = "Ruby",
		Price = 200,
		Quota = 1,
		Reward = { Materials = { RelicGold = 1 } },
	},
	{
		Id = "RubyPack",
		Order = 8,
		Currency = "Robux",
		Price = robuxPrices.ShopRuby,
		Product = "ShopRuby",
		Quota = 5,
		Reward = { Ruby = 300 },
	},
	{
		Id = "CorePack",
		Order = 9,
		Currency = "Robux",
		Price = robuxPrices.ShopCores,
		Product = "ShopCores",
		Quota = 2,
		Reward = { Materials = { SocketCore = 3 } },
	},
}

local passByKey: { [string]: PassDef } = {}
for _, def in passes do
	passByKey[def.Key] = def
end
local itemById: { [string]: ShopItem } = {}
for _, def in items do
	itemById[def.Id] = def
end

return Freeze({
	Passes = passes,
	PassByKey = passByKey,
	Products = products,
	RobuxPrices = robuxPrices,
	Items = items,
	ItemById = itemById,
	-- Gold of one "gold-level": roughly one level's kill gold before scaling.
	GoldUnit = 80,
	-- Receipt ids older than this are pruned once there are more than ReceiptKeep of them.
	ReceiptKeep = 200,
	ReceiptMaxAge = 60 * 86400,
})
