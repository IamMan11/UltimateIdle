--!strict
-- Server entry point: starts each server system (Replication last so load-time grants land in the snapshot).

local Server = script

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local PlayerData = require(Server.Data.PlayerData)
local Systems = Server.Systems

local World = require(Systems.World)
local Inventory = require(Systems.Inventory)
local Hero = require(Systems.Hero)
local Loot = require(Systems.Loot)
local Box = require(Systems.Box)
local SkillTree = require(Systems.SkillTree)
local Settings = require(Systems.Settings)
local Offline = require(Systems.Offline)
local Stage = require(Systems.Stage)
local Rebirth = require(Systems.Rebirth)
local Enhance = require(Systems.Enhance)
local Socket = require(Systems.Socket)
local Enchant = require(Systems.Enchant)
local Quest = require(Systems.Quest)
local BattlePass = require(Systems.BattlePass)
local Shop = require(Systems.Shop)
local Trade = require(Systems.Trade)
local Dev = require(Systems.Dev)
local Replication = require(Systems.Replication)

local _ = Net -- registers every remote before clients look them up

World.Start()
Inventory.Start()
Hero.Start()
Loot.Start()
Box.Start()
SkillTree.Start()
Settings.Start()
Offline.Start()
Stage.Start()
Rebirth.Start()
Enhance.Start()
Socket.Start()
Enchant.Start()
Quest.Start()
BattlePass.Start()
Shop.Start()
Trade.Start()
Dev.Start()
Replication.Start()
PlayerData.Start()
