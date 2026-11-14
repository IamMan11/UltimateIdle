--!strict
-- Studio-only dev commands (gold, xp, level, boxes, gear, materials, rebirth points, ruby, quest/pass progress, fake receipts, gifted passes). Never registered outside Studio.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Rng = require(ServerScriptService.Server.Util.Rng)
local DropTables = require(ServerScriptService.Server.Secret.DropTables)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Hero = require(script.Parent.Hero)
local Box = require(script.Parent.Box)
local Loot = require(script.Parent.Loot)
local Stage = require(script.Parent.Stage)
local Inventory = require(script.Parent.Inventory)
local Rebirth = require(script.Parent.Rebirth)
local Quest = require(script.Parent.Quest)
local BattlePass = require(script.Parent.BattlePass)
local Shop = require(script.Parent.Shop)

-- "receipt" / "pass" pick by index from these lists.
local DEV_PRODUCTS = { "GiftGold2x", "GiftXp2x", "PremiumPass", "ShopRuby", "ShopCores" }
local DEV_PASSES = { "Gold2x", "Xp2x" }
local QUEST_KINDS = { "ClearLevel", "Kill", "Boss", "Enhance", "OpenBox", "Enchant" }

local Dev = {}

local function run(player: Player, cmd: string, arg: number)
	if not RunService:IsStudio() or not RateLimit.Allow(player, "DevCommand") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(arg) then
		return
	end
	if cmd == "gold" then
		Currency.Add(player, "Gold", arg, "Dev")
	elseif cmd == "xp" then
		Hero.AddXp(player, arg)
	elseif cmd == "level" and Guard.Int(arg, 1, 1e6) then
		local progress = Stage.Progress(data)
		progress.Level = arg
		progress.MaxLevel = math.max(progress.MaxLevel, arg)
		Replication.Set(player, { "Stage" }, data.Stage)
		Stage.Restart(player)
	elseif cmd == "box" and Guard.Int(arg, 1, 100) then
		local rebirth = data.Stage.Rebirth
		local band = Boxes.Band(Loot.ItemLevel(Stage.Progress(data).MaxLevel, rebirth))
		Box.Grant(player, Boxes.Key("Normal", rebirth, band), arg)
		Box.Grant(player, Boxes.Key("Boss", rebirth, band), arg)
	elseif cmd == "gear" and Guard.Int(arg, 1, 100) then
		local rng = Rng.new()
		local bundle: Loot.Bundle = { Gear = {}, Materials = {}, Boxes = {} }
		local level = Loot.ItemLevel(Stage.Progress(data).MaxLevel, data.Stage.Rebirth)
		for _ = 1, arg do
			local spec = Loot.RollGear(rng, DropTables.Get(0).TierWeights, level, data.Stage.Rebirth, 0, nil, 0)
			if spec ~= nil then
				table.insert(bundle.Gear, spec)
			end
		end
		Loot.Grant(player, bundle)
	elseif cmd == "mats" and Guard.Int(arg, 1, 10000) then
		for _, def in Materials.List do
			Inventory.AddStack(player, def.Id, arg)
		end
	elseif cmd == "points" and Guard.Int(arg, 1, 1000) then
		Rebirth.AddPoints(player, arg)
	elseif cmd == "ruby" then
		Currency.Add(player, "Ruby", arg, "Dev")
	elseif cmd == "quest" and Guard.Int(arg, 1, 1e6) then
		for _, kind in QUEST_KINDS do
			Quest.Progress(player, kind :: any, arg)
		end
	elseif cmd == "passpts" and Guard.Int(arg, 1, 1e6) then
		BattlePass.AddPoints(player, arg)
	elseif cmd == "pass" and Guard.Int(arg, 1, #DEV_PASSES) then
		Shop.DevTogglePass(player, DEV_PASSES[arg])
	elseif cmd == "receipt" and Guard.Int(arg, 1, #DEV_PRODUCTS * 100) then
		-- arg = product index + 10 * n: same n = same purchase id (tests the dedupe).
		local index = (arg - 1) % 10 + 1
		local key = DEV_PRODUCTS[index]
		if key ~= nil then
			Shop.DevReceipt(player, key, `dev-{arg}`)
		end
	end
end

function Dev.Start()
	if RunService:IsStudio() then
		Net.DevCommand:Server():On(run)
	end
end

return Dev
