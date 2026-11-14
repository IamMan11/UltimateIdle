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
Dev.Start()
Replication.Start()
PlayerData.Start()
