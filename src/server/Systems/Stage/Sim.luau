--!strict
-- Pure battle sim: (team, level, rebirth, seed, skipWave) -> result + timeline buffer. Auto-cast hero skills, crit + lifesteal. No Instances, deterministic per seed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Timeline = require(ReplicatedStorage.Shared.Timeline)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Formation = require(ReplicatedStorage.Shared.Config.Formation)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local SkillsConfig = require(ReplicatedStorage.Shared.Config.Skills)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)

local Code = Timeline.Code
local ROW_ORDER = Formation.Rows
-- Extra reach so heroes can hit monsters queued behind the first one (monster offsets go up to 2.4).
local MELEE_SLACK = 3

type SkillState = {
	Def: Types.SimSkill,
	Cd: number,
}

type HeroUnit = {
	Id: number,
	Row: Types.Row,
	X: number,
	Hp: number,
	Stats: Types.HeroStats,
	Cd: number,
	Alive: boolean,
	ReviveAt: number,
	Skills: { SkillState },
}

type MonsterUnit = {
	Id: number,
	Def: Monsters.MonsterDef,
	Stats: Formula.MonsterStats,
	X: number,
	Hp: number,
	Cd: number,
	Alive: boolean,
	Moving: boolean,
	Offset: number,
}

type Wave = { At: number, Number: number, Spawned: boolean }

local Sim = {}

local function teamSpeed(team: { Types.SimHero }): number
	local members: { { Row: string, Speed: number } } = {}
	for _, hero in team do
		table.insert(members, { Row = hero.Row :: string, Speed = hero.Stats.Speed })
	end
	return Formula.Team.Speed(members, Stages.ReferenceSpeed)
end

local function pickMinion(rng: Random, level: number): Monsters.MonsterDef
	local total = 0
	for _, def in Monsters.List do
		if not def.Boss and def.FromLevel <= level then
			total += def.Weight
		end
	end
	local roll = rng:NextNumber() * total
	local last = Monsters.List[1]
	for _, def in Monsters.List do
		if not def.Boss and def.FromLevel <= level then
			last = def
			roll -= def.Weight
			if roll < 0 then
				return def
			end
		end
	end
	return last
end

-- Any boss unlocked at this level, picked with the level's own rng so replays and spectators see the same one.
local function pickBoss(rng: Random, level: number): Monsters.MonsterDef
	local pool: { Monsters.MonsterDef } = {}
	for _, def in Monsters.List do
		if def.Boss and def.FromLevel <= level then
			table.insert(pool, def)
		end
	end
	assert(#pool > 0, "no boss configured")
	return pool[rng:NextInteger(1, #pool)]
end

function Sim.Run(
	team: { Types.SimHero },
	level: number,
	rebirth: number,
	seed: number,
	skipWave: boolean
): Types.SimResult
	local rng = Random.new(seed)
	local builder = Timeline.NewBuilder()
	local dt = Stages.SimStep

	local heroes: { HeroUnit } = {}
	for i, hero in team do
		local skills: { SkillState } = {}
		for _, skill in hero.Skills do
			table.insert(skills, { Def = skill, Cd = math.max(skill.Cooldown * 0.4, SkillsConfig.FirstCastDelay) })
		end
		table.insert(heroes, {
			Id = i,
			Row = hero.Row,
			X = Formation.RowX[hero.Row] or 0,
			Hp = hero.Stats.MaxHp,
			Stats = hero.Stats,
			Cd = 0,
			Alive = true,
			ReviveAt = 0,
			Skills = skills,
		})
	end
	local shieldUntil, shieldReduce = 0, 0

	local interval = Formula.Combat.WaveInterval(teamSpeed(team))
	local waves: { Wave } = {}
	for w = 1, Stages.WavesPerLevel do
		local at = Stages.FirstWaveDelay + if skipWave then 0 else (w - 1) * interval
		table.insert(waves, { At = at, Number = w, Spawned = false })
	end

	local perWave = Formula.Combat.MonstersPerWave(level)
	local monsters: { MonsterUnit } = {}
	local nextMonsterId = Timeline.MonsterBase
	local kills: { [string]: number } = {}
	local bossKills = 0
	local wavesLeft = #waves

	local function spawn(t: number, def: Monsters.MonsterDef, order: number)
		local stats = Formula.Stats.Monster(def, level, rebirth)
		local unit: MonsterUnit = {
			Id = nextMonsterId,
			Def = def,
			Stats = stats,
			X = Stages.SpawnX + order * Stages.SpawnSpread,
			Hp = stats.MaxHp,
			Cd = stats.AtkInterval * 0.5,
			Alive = true,
			Moving = true,
			Offset = (order % 4) * 0.8,
		}
		nextMonsterId += 1
		table.insert(monsters, unit)
		Timeline.Push(builder, t, Code.Spawn, unit.Id, def.Index, unit.X, stats.MaxHp)
	end

	local function frontRow(): (string?, number)
		for _, row in ROW_ORDER do
			for _, h in heroes do
				if h.Alive and h.Row == row then
					return row, Formation.RowX[row]
				end
			end
		end
		return nil, 0
	end

	local function damageMonster(t: number, src: HeroUnit, m: MonsterUnit, raw: number)
		local amount = raw
		if src.Stats.Crit > 0 and rng:NextNumber() < src.Stats.Crit then
			amount *= Inserts.CritMult
		end
		amount = math.min(amount, m.Hp)
		m.Hp -= amount
		Timeline.Push(builder, t, Code.Hit, src.Id, m.Id, amount, m.Hp)
		if src.Stats.Lifesteal > 0 and src.Alive and src.Hp < src.Stats.MaxHp then
			local healed = math.min(amount * src.Stats.Lifesteal, src.Stats.MaxHp - src.Hp)
			src.Hp += healed
			Timeline.Push(builder, t, Code.Heal, src.Id, src.Id, healed, src.Hp)
		end
		if m.Hp <= 0 then
			m.Alive = false
			Timeline.Push(builder, t, Code.Die, m.Id, 0, 0, 0)
			kills[m.Def.Id] = (kills[m.Def.Id] or 0) + 1
			if m.Def.Boss then
				bossKills += 1
			end
		end
	end

	local function monstersInRange(h: HeroUnit): { MonsterUnit }
		local inRange: { MonsterUnit } = {}
		for _, m in monsters do
			if m.Alive and m.X - h.X <= h.Stats.Range + Stages.ContactGap + MELEE_SLACK then
				table.insert(inRange, m)
			end
		end
		table.sort(inRange, function(a, b)
			return a.X < b.X
		end)
		return inRange
	end

	local function healPower(h: HeroUnit): number
		return if h.Stats.Heal > 0 then h.Stats.Heal else h.Stats.Atk
	end

	-- Casts the skill if its condition holds right now; returns whether it fired.
	local function tryCast(t: number, h: HeroUnit, skill: Types.SimSkill): boolean
		local kind = skill.Kind
		if kind == "Damage" then
			local inRange = monstersInRange(h)
			if #inRange == 0 then
				return false
			end
			local n = if skill.Targets > 0 then skill.Targets else SkillsConfig.MaxDamageTargets
			Timeline.Push(builder, t, Code.Skill, h.Id, skill.Index, 0, 0)
			for i = 1, math.min(n, #inRange) do
				local m = inRange[i]
				damageMonster(t, h, m, Formula.Combat.Damage(h.Stats.Atk * skill.Mult, m.Stats.Def))
			end
			return true
		elseif kind == "Shield" then
			if t < shieldUntil then
				return false
			end
			local engaged = false
			for _, m in monsters do
				if m.Alive and not m.Moving then
					engaged = true
					break
				end
			end
			if not engaged then
				return false
			end
			shieldUntil, shieldReduce = t + skill.Duration, skill.Reduce
			Timeline.Push(builder, t, Code.Skill, h.Id, skill.Index, skill.Duration, 0)
			return true
		elseif kind == "HealAll" then
			local needed = false
			for _, ally in heroes do
				if ally.Alive and ally.Hp < ally.Stats.MaxHp * skill.Threshold then
					needed = true
					break
				end
			end
			if not needed then
				return false
			end
			Timeline.Push(builder, t, Code.Skill, h.Id, skill.Index, 0, 0)
			local power = healPower(h) * skill.Mult
			for _, ally in heroes do
				if ally.Alive and ally.Hp < ally.Stats.MaxHp then
					local amount = math.min(power, ally.Stats.MaxHp - ally.Hp)
					ally.Hp += amount
					Timeline.Push(builder, t, Code.Heal, h.Id, ally.Id, amount, ally.Hp)
				end
			end
			return true
		elseif kind == "Revive" then
			local fallen: HeroUnit? = nil
			for _, ally in heroes do
				if not ally.Alive and (fallen == nil or ally.ReviveAt > fallen.ReviveAt) then
					fallen = ally -- the one with the longest wait left
				end
			end
			if fallen == nil then
				return false
			end
			fallen.Alive = true
			fallen.Hp = fallen.Stats.MaxHp * skill.HpRatio
			fallen.Cd = 0
			Timeline.Push(builder, t, Code.Skill, h.Id, skill.Index, 0, 0)
			Timeline.Push(builder, t, Code.Revive, fallen.Id, 0, 0, fallen.Hp)
			return true
		end
		return false
	end

	local won = false
	local t = 0
	local maxSteps = math.ceil(Stages.MaxDuration / dt)
	for _ = 1, maxSteps do
		t += dt

		-- Waves
		for _, wave in waves do
			if not wave.Spawned and t >= wave.At then
				wave.Spawned = true
				wavesLeft -= 1
				Timeline.Push(builder, t, Code.Wave, wave.Number, 0, 0, 0)
				if wave.Number == Stages.WavesPerLevel then
					spawn(t, pickBoss(rng, level), 0)
					for i = 1, math.max(perWave - Stages.BossWaveMinionDrop, 0) do
						spawn(t, pickMinion(rng, level), i)
					end
				else
					for i = 0, perWave - 1 do
						spawn(t, pickMinion(rng, level), i)
					end
				end
			end
		end

		-- Revives
		for _, h in heroes do
			if not h.Alive and t >= h.ReviveAt then
				h.Alive = true
				h.Hp = h.Stats.MaxHp * Stages.ReviveHpRatio
				h.Cd = 0
				Timeline.Push(builder, t, Code.Revive, h.Id, 0, 0, h.Hp)
			end
		end

		local row, frontX = frontRow()
		if row == nil then
			break -- whole team down at once
		end

		-- Monsters move / attack the first alive row
		for _, m in monsters do
			if m.Alive then
				local reach = math.max(Stages.ContactGap, m.Stats.Range * 0.8)
				local stopX = frontX + reach + m.Offset
				if m.X > stopX + 0.001 then
					if not m.Moving then
						m.Moving = true
						Timeline.Push(builder, t, Code.Move, m.Id, 0, 0, 0)
					end
					m.X = math.max(stopX, m.X - m.Stats.MoveSpeed * dt)
					if m.X <= stopX + 0.001 then
						m.Moving = false
						Timeline.Push(builder, t, Code.Stop, m.Id, 0, m.X, 0)
					end
				end
				m.Cd -= dt
				if not m.Moving and m.Cd <= 0 then
					local targets: { HeroUnit } = {}
					for _, h in heroes do
						if h.Alive and h.Row == row then
							table.insert(targets, h)
						end
					end
					if #targets > 0 then
						local target = targets[rng:NextInteger(1, #targets)]
						local dmg = Formula.Combat.Damage(m.Stats.Atk, target.Stats.Def)
						if t < shieldUntil then
							dmg *= 1 - shieldReduce
						end
						target.Hp = math.max(target.Hp - dmg, 0)
						Timeline.Push(builder, t, Code.Hit, m.Id, target.Id, dmg, target.Hp)
						if target.Hp <= 0 then
							target.Alive = false
							target.ReviveAt = t + Stages.ReviveSeconds
							Timeline.Push(builder, t, Code.Die, target.Id, 0, 0, 0)
						end
						m.Cd = m.Stats.AtkInterval
					end
				end
			end
		end

		if frontRow() == nil then
			break
		end

		-- Skills: at most one cast per hero per step, highest priority first
		for _, h in heroes do
			if h.Alive then
				local cast = false
				for _, state in h.Skills do
					state.Cd -= dt
					if not cast and state.Cd <= 0 and tryCast(t, h, state.Def) then
						state.Cd = state.Def.Cooldown
						cast = true
					end
				end
			end
		end

		-- Heroes heal or attack
		for _, h in heroes do
			if h.Alive then
				h.Cd -= dt
				if h.Cd <= 0 then
					local acted = false
					if h.Stats.Heal > 0 then
						local hurt: HeroUnit? = nil
						for _, ally in heroes do
							if ally.Alive and ally.Hp < ally.Stats.MaxHp * 0.98 then
								if hurt == nil or ally.Hp / ally.Stats.MaxHp < hurt.Hp / hurt.Stats.MaxHp then
									hurt = ally
								end
							end
						end
						if hurt ~= nil then
							local amount = math.min(h.Stats.Heal, hurt.Stats.MaxHp - hurt.Hp)
							hurt.Hp += amount
							Timeline.Push(builder, t, Code.Heal, h.Id, hurt.Id, amount, hurt.Hp)
							acted = true
						end
					end
					if not acted then
						local inRange = monstersInRange(h)
						if #inRange > 0 then
							for i = 1, math.min(1 + h.Stats.Splash, #inRange) do
								local m = inRange[i]
								damageMonster(t, h, m, Formula.Combat.Damage(h.Stats.Atk, m.Stats.Def))
							end
							acted = true
						end
					end
					if acted then
						h.Cd = h.Stats.AtkInterval
					end
				end
			end
		end

		-- Cleared?
		if wavesLeft == 0 then
			local anyAlive = false
			for _, m in monsters do
				if m.Alive then
					anyAlive = true
					break
				end
			end
			if not anyAlive then
				won = true
				break
			end
		end
	end

	local events, count = Timeline.Finish(builder)
	return {
		Won = won,
		Duration = t + 0.5,
		Kills = kills,
		BossKills = bossKills,
		Events = events,
		EventCount = count,
	}
end

return table.freeze(Sim)
