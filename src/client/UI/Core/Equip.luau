--!strict
-- Links the Inventory and Team windows: which hero the Team window shows, which slot a bag piece goes in, what that hero wears there, equipping by double click / drag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local State = require(script.Parent.Parent.Parent.State)

local Equip = {}

-- The class the Team window shows: the one picked there if it is a real class, else the first owned.
function Equip.TeamHero(data: Types.ProfileData): string
	local picked = State.Ui.TeamHero
	if picked ~= nil and Heroes.ById[picked] ~= nil then
		return picked
	end
	for _, def in Heroes.List do
		if data.Heroes[def.Id] ~= nil then
			return def.Id
		end
	end
	return Heroes.List[1].Id
end

-- Gear slot of `hero` that `item` goes in: `preferred` if it fits, else the first empty one of its kind, else the first.
function Equip.SlotFor(hero: Types.HeroState, item: Types.GearItem, preferred: string?): string?
	local def = Items.ById[item.BaseId]
	local slots = if def ~= nil then Items.Slots[def.Slot] else nil
	if slots == nil or #slots == 0 then
		return nil
	end
	if preferred ~= nil and table.find(slots, preferred) ~= nil then
		return preferred
	end
	for _, slot in slots do
		if hero.Equipped[slot] == nil then
			return slot
		end
	end
	return slots[1]
end

-- What the Team window's hero wears where `item` would go (nil when the window is closed or the slot is empty or holds this piece).
function Equip.Worn(data: Types.ProfileData, item: Types.GearItem): (Types.GearItem?, string?)
	if not State.IsOpen("Team") then
		return nil, nil
	end
	local heroId = Equip.TeamHero(data)
	local hero = data.Heroes[heroId]
	if hero == nil then
		return nil, nil
	end
	local slot = Equip.SlotFor(hero, item, State.Ui.TeamSlot)
	local worn = if slot ~= nil then data.Gear[hero.Equipped[slot] or ""] else nil
	if worn == nil or worn.Uid == item.Uid then
		return nil, heroId
	end
	return worn, heroId
end

-- Puts a bag piece on the Team window's hero; `slot` = the slot it was dropped on (nil = pick one).
function Equip.FromBag(data: Types.ProfileData, uid: string, slot: string?)
	local item = data.Gear[uid]
	if item == nil then
		return
	end
	if not State.IsOpen("Team") then
		State.PushToast(Text.UI.OpenTeamToEquip)
		return
	end
	local heroId = Equip.TeamHero(data)
	local hero = data.Heroes[heroId]
	if hero == nil then
		return
	end
	local def = Items.ById[item.BaseId]
	if slot ~= nil and (def == nil or Items.SlotOf[slot] ~= def.Slot) then
		State.PushToast(Text.UI.WrongSlot)
		return
	end
	local target = slot or Equip.SlotFor(hero, item, State.Ui.TeamSlot)
	if target ~= nil then
		State.Send.Equip(heroId, uid, target)
	end
end

return Equip
