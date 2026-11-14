--!strict
-- Studio-only dev commands (gold, xp, level, boxes, gear). Never registered outside Studio.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
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
		Currency.Add(player, "Gold", arg)
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
	end
end

function Dev.Start()
	if RunService:IsStudio() then
		Net.DevCommand:Server():On(run)
	end
end

return Dev
