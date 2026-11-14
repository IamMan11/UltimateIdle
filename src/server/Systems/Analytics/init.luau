--!strict
-- AnalyticsService wrapper (batched economy, progression milestones, onboarding funnel, custom events) + anomaly flags logged as `[Anomaly]`.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config.Analytics)
local Formula = require(ReplicatedStorage.Shared.Formula)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)

type Pending = { Flow: "Source" | "Sink", Currency: string, Tx: string, Amount: number }
type Sample = { At: number, Amount: number }

type PlayerState = {
	Pending: { [string]: Pending },
	Gold: { Sample },
	Ruby: { Sample },
	Trips: { number },
	Flagged: { [string]: number }, -- flag kind -> os.clock() of last report
	Funnel: { [number]: boolean },
}

local states: { [Player]: PlayerState } = {}
local sendErrors = 0

local Analytics = {}

local function stateOf(player: Player): PlayerState
	local s = states[player]
	if s == nil then
		s = { Pending = {}, Gold = {}, Ruby = {}, Trips = {}, Flagged = {}, Funnel = {} }
		states[player] = s
	end
	return s
end

-- Engine call guarded: analytics failures are logged (rate-limited), never thrown into gameplay.
local function send(what: string, fn: () -> ())
	local ok, err = pcall(function(): nil
		fn()
		return nil
	end)
	if not ok then
		sendErrors += 1
		if sendErrors % 50 == 1 then
			warn(`[Analytics] {what} failed ({sendErrors}): {err}`)
		end
	end
end

local function bestLevel(player: Player): number
	local data = PlayerData.Data(player)
	local best = 1
	if data ~= nil then
		for _, p in data.Stage.ByRebirth do
			best = math.max(best, p.MaxLevel)
		end
	end
	return best
end

local function prune(samples: { Sample }, now: number)
	while #samples > 0 and now - samples[1].At > Config.WindowSeconds do
		table.remove(samples, 1)
	end
end

local function windowSum(samples: { Sample }): number
	local total = 0
	for _, s in samples do
		total += s.Amount
	end
	return total
end

-- Logs a suspicious pattern once per cooldown per player/kind.
function Analytics.Flag(player: Player, kind: string, detail: string)
	local s = stateOf(player)
	local now = os.clock()
	local last = s.Flagged[kind]
	if last ~= nil and now - last < Config.FlagCooldown then
		return
	end
	s.Flagged[kind] = now
	warn(`[Anomaly] {kind} {player.Name} ({player.UserId}): {detail}`)
	send("custom", function()
		AnalyticsService:LogCustomEvent(player, `Anomaly_{kind}`, 1)
	end)
end

local function checkEarn(player: Player, currency: string, source: string, amount: number)
	if table.find(Config.NonGameplay, source) ~= nil then
		return
	end
	local s = stateOf(player)
	local now = os.clock()
	if currency == "Gold" then
		local best = bestLevel(player)
		if amount > Formula.Economy.Gold(Config.GoldLevelsSingle, best) then
			Analytics.Flag(player, "GoldSingle", `{source} +{amount} at best level {best}`)
		end
		table.insert(s.Gold, { At = now, Amount = amount })
		prune(s.Gold, now)
		local total = windowSum(s.Gold)
		local limit = Formula.Economy.Gold(Config.GoldLevelsPerMinute * Config.WindowSeconds / 60, best)
		if total > limit then
			Analytics.Flag(player, "GoldRate", `{total} gold in {Config.WindowSeconds}s (limit {limit})`)
		end
	elseif currency == "Ruby" then
		table.insert(s.Ruby, { At = now, Amount = amount })
		prune(s.Ruby, now)
		local total = windowSum(s.Ruby)
		if total > Config.RubyPerWindow then
			Analytics.Flag(player, "RubyRate", `{total} ruby in {Config.WindowSeconds}s`)
		end
	end
end

-- Currency calls this for every balance change (source = Config.Analytics.TransactionTypes key).
function Analytics.Economy(player: Player, currency: string, flow: "Source" | "Sink", amount: number, source: string)
	if amount <= 0 or source == "Dev" then
		return
	end
	if flow == "Source" then
		checkEarn(player, currency, source, amount)
		if source == "Trade" and currency == "Gold" then
			local best = bestLevel(player)
			if amount > Formula.Economy.Gold(Config.TradeGoldLevels, best) then
				Analytics.Flag(player, "TradeGold", `received {amount} gold at best level {best}`)
			end
		end
	end
	local tx = Config.TransactionTypes[source] or "Gameplay"
	local key = `{currency}|{flow}|{tx}`
	local pending = stateOf(player).Pending
	local entry = pending[key]
	if entry == nil then
		pending[key] = { Flow = flow, Currency = currency, Tx = tx, Amount = amount }
	else
		entry.Amount += amount
	end
end

local function flush(player: Player)
	local s = states[player]
	local data = PlayerData.Data(player)
	if s == nil or data == nil or next(s.Pending) == nil then
		return
	end
	local pending = s.Pending
	s.Pending = {}
	if RunService:IsStudio() then
		return -- Studio does not report analytics; keep the batching path exercised
	end
	for _, entry in pending do
		local balance: number = (data :: any)[entry.Currency] or 0
		local flow = if entry.Flow == "Source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		send("economy", function()
			AnalyticsService:LogEconomyEvent(
				player,
				flow,
				entry.Currency,
				math.floor(entry.Amount),
				math.floor(balance),
				entry.Tx
			)
		end)
	end
end

-- New highest level in a rebirth (logged every Config.ProgressEvery levels).
function Analytics.Progress(player: Player, rebirth: number, level: number)
	if level % Config.ProgressEvery ~= 0 then
		return
	end
	send("progression", function()
		AnalyticsService:LogProgressionEvent(player, `Stage_R{rebirth}`, Enum.AnalyticsProgressionType.Complete, level)
	end)
end

-- Onboarding funnel step (each step once per session; the tutorial keeps steps once per account).
function Analytics.Onboarding(player: Player, step: number, name: string)
	local s = stateOf(player)
	if s.Funnel[step] then
		return
	end
	s.Funnel[step] = true
	send("onboarding", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.Custom(player: Player, name: string, value: number?)
	send("custom", function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

local function onTrip(player: Player, key: string)
	local s = stateOf(player)
	local now = os.clock()
	table.insert(s.Trips, now)
	while #s.Trips > 0 and now - s.Trips[1] > 60 do
		table.remove(s.Trips, 1)
	end
	if #s.Trips > Config.RateLimitTripsPerMinute then
		Analytics.Flag(player, "RateLimit", `{#s.Trips} refused calls in 60s (last: {key})`)
	end
end

function Analytics.Start()
	RateLimit.OnTrip(onTrip)
	task.spawn(function()
		while true do
			task.wait(Config.FlushSeconds)
			for player in states do
				flush(player)
			end
		end
	end)
	PlayerData.OnReleasing(function(player: Player)
		flush(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			states[player] = nil
		end)
	end)
end

return Analytics
