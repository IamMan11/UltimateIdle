--!strict
-- Server-side randomness (never trust client rolls): seedable generator with chance/int/weighted helpers.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { Random: Random }, Rng))

local seeder = Random.new()

function Rng.Seed(): number
	return seeder:NextInteger(1, 2 ^ 31 - 1)
end

function Rng.new(seed: number?): Rng
	return setmetatable({ Random = Random.new(seed or Rng.Seed()) }, Rng)
end

function Rng.Float(self: Rng): number
	return self.Random:NextNumber()
end

function Rng.Range(self: Rng, min: number, max: number): number
	return self.Random:NextNumber(min, max)
end

function Rng.Int(self: Rng, min: number, max: number): number
	return self.Random:NextInteger(min, max)
end

function Rng.Chance(self: Rng, p: number): boolean
	return self.Random:NextNumber() < p
end

-- Picks a key with probability weight/total. Keys are iterated in sorted order so a seed gives the same pick.
function Rng.Weighted(self: Rng, weights: { [string]: number }): string?
	local keys: { string } = {}
	local total = 0
	for key, w in weights do
		if w > 0 then
			table.insert(keys, key)
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(keys)
	local roll = self.Random:NextNumber() * total
	for _, key in keys do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return keys[#keys]
end

-- Integer count with expected value `expected`: floor plus one more with the fractional chance.
function Rng.Count(self: Rng, expected: number): number
	if expected <= 0 then
		return 0
	end
	local whole = math.floor(expected)
	return whole + (if self.Random:NextNumber() < expected - whole then 1 else 0)
end

return Rng
