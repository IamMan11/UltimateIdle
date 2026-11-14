--!strict
-- Lane spectating: a client watches one other player's lane; that owner's level timelines are forwarded to its watchers only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)

local laneEvent = Net.LaneTimeline:Server()

local latest: { [Player]: Types.TimelinePayload } = {}
local watching: { [Player]: Player } = {} -- watcher -> owner

local Spectate = {}

-- Stage calls this with every new level of `owner`.
function Spectate.Publish(owner: Player, payload: Types.TimelinePayload)
	latest[owner] = payload
	for watcher, target in watching do
		if target == owner then
			laneEvent:Fire(watcher, owner.UserId, payload)
		end
	end
end

local function stopWatching(watcher: Player)
	watching[watcher] = nil
end

-- userId 0 = stop watching.
local function watch(player: Player, userId: number)
	if not RateLimit.Allow(player, "WatchLane") then
		return
	end
	if userId == 0 or userId == player.UserId then
		stopWatching(player)
		return
	end
	local owner = Players:GetPlayerByUserId(userId)
	if owner == nil then
		stopWatching(player)
		laneEvent:Fire(player, userId, nil)
		return
	end
	watching[player] = owner
	laneEvent:Fire(player, userId, latest[owner])
end

function Spectate.Start()
	Net.WatchLane:Server():On(watch)
	Players.PlayerRemoving:Connect(function(player)
		latest[player] = nil
		watching[player] = nil
		for watcher, owner in watching do
			if owner == player then
				watching[watcher] = nil
				laneEvent:Fire(watcher, player.UserId, nil)
			end
		end
	end)
end

return Spectate
