--!strict
-- What salvaging a gear piece gives (gold + enhance stones) and the confirm prompt for salvaging one piece from the Inventory grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)

local SalvageInfo = {}

-- Gold and enhance stones one piece gives (same numbers as the server's Loot.SalvageValue).
function SalvageInfo.Value(item: Types.GearItem): (number, number)
	local tier = Tiers.ById[item.Tier]
	if tier == nil then
		return 0, 0
	end
	return math.floor(tier.SalvageGold * Formula.Scaling.Item(item.Level)), tier.SalvageStones
end

function SalvageInfo.Confirm(item: Types.GearItem)
	local gold, stones = SalvageInfo.Value(item)
	State.OpenConfirm({
		Title = `Salvage {ItemInfo.Name(item)} [{Text.Tier(item.Tier)}]?`,
		Body = `You get {Format.Number(gold)} gold + {stones} {Text.Material("EnhanceStone")}. The item is gone for good.`,
		OkText = Text.UI.Salvage,
		Danger = true,
		OnConfirm = function()
			State.Send.Salvage({ item.Uid })
		end,
	})
end

return SalvageInfo
