--!strict
-- Sole owner of player save data: wraps ProfileStore, holds PROFILE_TEMPLATE + migrations, load/release hooks, profile messages, save-and-wait for receipts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.ProfileStore)
local Types = require(ReplicatedStorage.Shared.Types)
local Game = require(ReplicatedStorage.Shared.Config.Game)

export type Data = Types.ProfileData

local PROFILE_TEMPLATE: Data = {
	SchemaVersion = Game.SchemaVersion,
	Gold = 0,
	Ruby = 0,
	AccountXp = 0,
	AccountLevel = 1,
	Heroes = {},
	Team = {},
	Gear = {},
	Stacks = {},
	Boxes = {},
	Stage = {
		Mode = "Progress",
		Rebirth = 0,
		ByRebirth = {
			["0"] = { Level = 1, MaxLevel = 1, FarmLevel = 1, LastFarmRound = 0 },
		},
	},
	Rebirth = { Count = 0, Points = 0 },
	SkillTree = {},
	SkillOff = {},
	Purchases = { Receipts = {}, Owned = {}, GiftTo = {} },
	Quests = {
		Daily = { Key = "", Progress = {}, Claimed = {} },
		Weekly = { Key = "", Progress = {}, Claimed = {} },
		Monthly = { Key = "", Progress = {}, Claimed = {} },
	},
	Pass = { Season = "", Points = 0, Premium = false, Free = {}, Paid = {} },
	Shop = { Month = "", Bought = {} },
	LastSeen = 0,
	OfflineRate = { Gold = 0, Xp = 0 },
	NextUid = 1,
	Settings = {
		AutoSalvage = {},
		AutoOpenBoxes = false,
		SkipWave = false,
		UiScale = 1,
		LowDetail = false,
	},
	Tutorial = { Step = 1, Done = false, Rewarded = 0 },
	Daily = { Day = "", Streak = 0 },
	Codes = {},
}

-- MIGRATIONS[v] upgrades a save from version v-1 to v. Runs before Reconcile, so missing keys are filled after.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> () } = {
	[1] = function(data)
		-- Pre-v1 prototype fields; no real players existed yet.
		data.Cash = nil
		data.Level = nil
		data.LogInTimes = nil
	end,
	[2] = function(data)
		-- Box stacks became "<Kind>:<rebirth>:<band>" keys; v1 keys were bare kind names.
		data.Boxes = {}
	end,
	[3] = function(_data)
		-- Quests / Pass / Shop / Purchases.GiftTo are new tables: Reconcile fills them from the template.
	end,
	[4] = function(data)
		-- Tutorial / Daily / Codes / Settings.UiScale+LowDetail are new; players who already picked a hero skip the tutorial.
		if type(data.Heroes) == "table" and next(data.Heroes) ~= nil then
			data.Tutorial = { Step = 1, Done = true, Rewarded = 0 }
		end
	end,
}

local function migrate(data: { [string]: any })
	local version = if type(data.SchemaVersion) == "number" then data.SchemaVersion else 0
	for v = version + 1, Game.SchemaVersion do
		local step = MIGRATIONS[v]
		if step ~= nil then
			step(data)
		end
		data.SchemaVersion = v
	end
end

-- Store name is the DataStore key: renaming it later orphans every saved profile.
local PlayerStore = ProfileStore.New("PlayerData", PROFILE_TEMPLATE)

-- Derived from the store itself: ProfileStore.Profile<Data> fails strict checks against this value.
export type Profile = typeof(assert(PlayerStore:StartSessionAsync("", {})))

type Hook = (player: Player, data: Data) -> ()
-- Returns true when it handled the message (it is then removed from the profile's queue).
type MessageHook = (player: Player, data: Data, message: { [string]: any }) -> boolean

local profiles: { [Player]: Profile } = {}
local loadedHooks: { Hook } = {}
local releasingHooks: { Hook } = {}
local messageHooks: { MessageHook } = {}

local function runHooks(hooks: { Hook }, player: Player, data: Data)
	for _, hook in hooks do
		-- One failing system must not stop the others from loading; the error is reported with its traceback.
		xpcall(hook, function(e: unknown)
			warn(`[PlayerData] hook failed for {player.Name}: {debug.traceback(tostring(e))}`)
		end, player, data)
	end
end

local PlayerData = {}

function PlayerData.Get(player: Player): Profile?
	return profiles[player]
end

-- Shortcut for systems: the live save table, or nil while loading / after leaving.
function PlayerData.Data(player: Player): Data?
	local profile = profiles[player]
	return if profile ~= nil then profile.Data else nil
end

-- Hooks run in registration order, once the profile is ready (loaded) or right before it is released.
function PlayerData.OnLoaded(hook: Hook)
	table.insert(loadedHooks, hook)
end

function PlayerData.OnReleasing(hook: Hook)
	table.insert(releasingHooks, hook)
end

-- Delivers a message to a player's profile whether or not they are online (picked up on load or the next
-- auto-save of their session). Yields. Messages must be idempotent: a retried sender may deliver twice.
function PlayerData.MessageAsync(userId: number, message: { [string]: any }): boolean
	local ok, result = pcall(function()
		return PlayerStore:MessageAsync(tostring(userId), message)
	end)
	if not ok then
		warn(`[PlayerData] MessageAsync to {userId} failed: {result}`)
		return false
	end
	return result == true
end

function PlayerData.OnMessage(hook: MessageHook)
	table.insert(messageHooks, hook)
end

-- Starts a save now (no wait). Used after trades so both sides hit the store close together.
function PlayerData.SaveNow(player: Player)
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		profile:Save()
	end
end

-- Saves and yields until `saved(LastSavedData)` holds (true) or the session ends / times out (false).
function PlayerData.WaitSaved(player: Player, saved: (Data) -> boolean, timeout: number?): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	if saved(profile.LastSavedData) then
		return true
	end
	local done = false
	local connection = profile.OnAfterSave:Connect(function(lastSaved: Data)
		if saved(lastSaved) then
			done = true
		end
	end)
	profile:Save()
	local deadline = os.clock() + (timeout or 30)
	while not done and profile:IsActive() and os.clock() < deadline do
		task.wait(0.25)
	end
	connection:Disconnect()
	return done
end

local function onMessage(player: Player, profile: Profile, message: unknown, processed: () -> ())
	if type(message) ~= "table" or profiles[player] ~= profile then
		return
	end
	for _, hook in messageHooks do
		local ok, handled = xpcall(hook, function(e: unknown)
			warn(`[PlayerData] message hook failed for {player.Name}: {debug.traceback(tostring(e))}`)
		end, player, profile.Data, message :: any)
		if ok and handled then
			processed()
			return
		end
	end
	warn(`[PlayerData] unhandled message for {player.Name}`)
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
	migrate(profile.Data :: any)
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
	print(`[PlayerData] Loaded {player.Name} (schema {profile.Data.SchemaVersion}, gold {profile.Data.Gold})`)
	runHooks(loadedHooks, player, profile.Data)
	profile:MessageHandler(function(message, processed)
		onMessage(player, profile, message, processed)
	end)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile ~= nil then
		runHooks(releasingHooks, player, profile.Data)
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
