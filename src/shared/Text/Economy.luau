--!strict
-- Player-facing strings for phase 6: quests, battle pass, shop items, game passes, trade, reward lines. Built from the main Text table.

local Types = require(script.Parent.Parent.Types)
local Format = require(script.Parent.Parent.Format)
local Quests = require(script.Parent.Parent.Config.Quests)

type Base = {
	Material: (id: string) -> string,
	Box: (key: string) -> string,
}

local QUEST: { [string]: string } = {
	ClearLevel = "Clear %s levels",
	Kill = "Defeat %s monsters",
	Boss = "Defeat %s bosses",
	Enhance = "Enhance gear %s times",
	OpenBox = "Open %s boxes",
	Enchant = "Enchant gear %s times",
}

local PASS: { [string]: { Name: string, Desc: string } } = {
	Gold2x = { Name = "x2 Gold", Desc = "Double gold from levels and offline earnings. Permanent." },
	Xp2x = { Name = "x2 XP", Desc = "Double xp from levels and offline earnings. Permanent." },
}

local SHOP_ITEM: { [string]: string } = {
	Stones = "Stone Bundle",
	BossBoxes = "Boss Box Crate",
	DustSmall = "Dust Pouch",
	Dust = "Dust Sack",
	Shards = "Ancient Shards",
	Core = "Socket Core",
	GoldIdol = "Golden Idol",
	RubyPack = "Ruby Pack",
	CorePack = "Core Pack",
	PremiumPass = "Premium Battle Pass",
}

return function(base: Base)
	local Eco = {}

	function Eco.Quest(def: Quests.QuestDef): string
		local pattern = QUEST[def.Kind] or "%s"
		return string.format(pattern, Format.Number(def.Need))
	end

	function Eco.PassName(key: string): string
		local def = PASS[key]
		return if def ~= nil then def.Name else key
	end

	function Eco.PassDesc(key: string): string
		local def = PASS[key]
		return if def ~= nil then def.Desc else ""
	end

	function Eco.ShopItem(id: string): string
		return SHOP_ITEM[id] or id
	end

	-- One line for a reward; `gold` = the already-scaled gold amount (nil = leave gold out).
	function Eco.Reward(reward: Types.Reward, gold: number?): string
		local parts: { string } = {}
		if (reward.Ruby or 0) > 0 then
			table.insert(parts, `{Format.Number(reward.Ruby or 0)} Ruby`)
		end
		if gold ~= nil and gold > 0 then
			table.insert(parts, `{Format.Number(gold)} gold`)
		end
		if reward.Materials ~= nil then
			local mats: { string } = {}
			for id, n in reward.Materials do
				table.insert(mats, `{n} {base.Material(id)}`)
			end
			table.sort(mats)
			for _, line in mats do
				table.insert(parts, line)
			end
		end
		if reward.Boxes ~= nil then
			for kind, n in reward.Boxes do
				table.insert(parts, `{n} {base.Box(kind)}`)
			end
		end
		return table.concat(parts, ", ")
	end

	Eco.UI = table.freeze({
		Quests = "Quests",
		Shop = "Shop",
		Trade = "Trade",
		Daily = "Daily",
		Weekly = "Weekly",
		Monthly = "Monthly",
		Pass = "Battle Pass",
		Claim = "Claim",
		Claimed = "Claimed",
		ClaimAll = "Claim all",
		ResetsIn = "Resets in",
		SeasonEnds = "Season ends in",
		PassPoints = "pass points",
		Free = "Free",
		Premium = "Premium",
		PremiumActive = "Premium active",
		BuyPremium = "Unlock premium",
		Tier = "Tier",
		MonthlyShop = "Monthly shop",
		Passes = "Passes",
		Owned = "Owned",
		Buy = "Buy",
		Gift = "Gift",
		GiftTo = "Gift a pass to someone in this server",
		NobodyHere = "Nobody else is in this server",
		LeftThisMonth = "left this month",
		SoldOut = "Sold out",
		NotForSale = "Not available yet",
		TradeIntro = "Trade with players in this server. Worn items must be unequipped first.",
		TradeLockedHint = "Trading unlocks at account level %s",
		Requests = "Trade requests",
		Players = "Players here",
		Request = "Request",
		Accept = "Accept",
		Decline = "Decline",
		YourOffer = "Your offer",
		TheirOffer = "Their offer",
		AddGear = "Your bag (click to add / remove)",
		Materials = "Materials",
		Boxes = "Boxes",
		Ready = "Ready",
		NotReady = "Not ready",
		Unready = "Change offer",
		Confirm = "Confirm trade",
		Confirmed = "Confirmed",
		Waiting = "Waiting...",
		CancelTrade = "Cancel trade",
		NothingOffered = "Nothing offered",
		GoldAmount = "Gold",
		RubyAmount = "Ruby",
		TradeNote = "Any change to either offer clears both Ready and Confirm.",
	})

	return table.freeze(Eco)
end
