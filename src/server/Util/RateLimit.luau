--!strict
-- Token-bucket rate limit per player per remote key; unknown keys are refused.

local Players = game:GetService("Players")

type Bucket = { Tokens: number, Last: number }

-- rate = tokens per second, burst = bucket size. Picked from how fast a human can click, with headroom.
local LIMITS: { [string]: { Rate: number, Burst: number } } = {
	RequestSnapshot = { Rate = 0.2, Burst = 2 },
	ChooseFirstHero = { Rate = 1, Burst = 3 },
	BuyHero = { Rate = 2, Burst = 4 },
	SetStageMode = { Rate = 1, Burst = 3 },
	SetSetting = { Rate = 5, Burst = 10 },
	Equip = { Rate = 8, Burst = 16 },
	Unequip = { Rate = 8, Burst = 16 },
	Salvage = { Rate = 3, Burst = 6 },
	OpenBox = { Rate = 4, Burst = 8 },
	ConvertBox = { Rate = 4, Burst = 8 },
	RequestRejoin = { Rate = 0.05, Burst = 1 },
	DevCommand = { Rate = 10, Burst = 20 },
}

local buckets: { [Player]: { [string]: Bucket } } = {}
local trips: { [Player]: number } = {}

local RateLimit = {}

function RateLimit.Allow(player: Player, key: string): boolean
	local limit = LIMITS[key]
	if limit == nil then
		warn(`[RateLimit] no limit configured for {key}`)
		return false
	end
	local byPlayer = buckets[player]
	if byPlayer == nil then
		byPlayer = {}
		buckets[player] = byPlayer
	end
	local now = os.clock()
	local bucket = byPlayer[key]
	if bucket == nil then
		bucket = { Tokens = limit.Burst, Last = now }
		byPlayer[key] = bucket
	end
	bucket.Tokens = math.min(limit.Burst, bucket.Tokens + (now - bucket.Last) * limit.Rate)
	bucket.Last = now
	if bucket.Tokens < 1 then
		local count = (trips[player] or 0) + 1
		trips[player] = count
		if count % 50 == 1 then
			warn(`[RateLimit] {player.Name} over limit on {key} ({count} trips)`)
		end
		return false
	end
	bucket.Tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	trips[player] = nil
end)

return RateLimit
