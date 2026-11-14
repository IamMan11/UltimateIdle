--!strict
-- Owner of the tutorial: steps advance on server events (Tutorial.Event, quest progress hooks), each step pays its reward once per account, skip/replay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.Tutorial)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Replication = require(script.Parent.Replication)
local Rewards = require(script.Parent.Rewards)
local Quest = require(script.Parent.Quest)
local Analytics = require(script.Parent.Analytics)

local Steps = TutorialConfig.Steps

local Tutorial = {}

local function sync(player: Player)
	local data = PlayerData.Data(player)
	if data ~= nil then
		Replication.Set(player, { "Tutorial" }, data.Tutorial)
	end
end

-- Systems report what happened; the current step completes when its event matches.
function Tutorial.Event(player: Player, event: string)
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	if event == "ChooseHero" then
		Analytics.Onboarding(player, 1, "ChooseHero")
		return
	end
	local t = data.Tutorial
	local step = Steps[t.Step]
	if t.Done or step == nil or step.Event ~= event then
		return
	end
	if t.Step > t.Rewarded then
		t.Rewarded = t.Step
		Rewards.Grant(player, step.Reward, "Reward")
		Analytics.Onboarding(player, t.Step + 1, step.Id)
	end
	t.Step += 1
	t.Done = t.Step > #Steps
	sync(player)
	Replication.Notify(player, "TutorialStep", { Id = step.Id, Done = t.Done })
end

local function skip(player: Player)
	if not RateLimit.Allow(player, "TutorialSkip") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or data.Tutorial.Done then
		return
	end
	data.Tutorial.Done = true
	sync(player)
	Analytics.Custom(player, "TutorialSkipped", data.Tutorial.Step)
end

local function restart(player: Player)
	if not RateLimit.Allow(player, "TutorialSkip") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	data.Tutorial.Step = 1
	data.Tutorial.Done = false
	sync(player)
end

function Tutorial.Start()
	Net.TutorialSkip:Server():On(skip)
	Net.TutorialRestart:Server():On(restart)
	Quest.OnProgress(function(player: Player, kind: string)
		Tutorial.Event(player, kind)
	end)
end

return Tutorial
