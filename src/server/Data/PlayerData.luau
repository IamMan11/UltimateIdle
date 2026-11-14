--!strict
-- Sole owner of player save data: wraps ProfileStore, holds PROFILE_TEMPLATE.

local Players = game:GetService("Players")

local ProfileStore = require(script.Parent.ProfileStore)

export type Data = {
	Cash: number,
	Level: number,
	LogInTimes: number,
}

local PROFILE_TEMPLATE: Data = {
	Cash = 0,
	Level = 1,
	LogInTimes = 0,
}

-- Store name is the DataStore key: renaming it later orphans every saved profile.
local PlayerStore = ProfileStore.New("PlayerData", PROFILE_TEMPLATE)

-- Derived from the store itself: ProfileStore.Profile<Data> fails strict checks against this value.
export type Profile = typeof(assert(PlayerStore:StartSessionAsync("", {})))

local profiles: { [Player]: Profile } = {}

local PlayerData = {}

function PlayerData.Get(player: Player): Profile?
	return profiles[player]
end

local function onPlayerAdded(player: Player)
	-- ProfileStore types params as { Steal: boolean? } only, but Cancel exists and is needed.
	local params = {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	} :: any

	local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), params)

	if profile == nil then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	profile.Data.LogInTimes += 1
	print(`[PlayerData] Loaded {player.Name}: LogInTimes = {profile.Data.LogInTimes}`)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function PlayerData.Start()
	-- Players who joined before this script ran (happens when Studio starts a playtest).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return PlayerData
