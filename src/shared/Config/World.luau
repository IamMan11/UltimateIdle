--!strict
-- Lobby and stage layout (server builds the lobby; client draws units, scenery and cameras at the far-away stage origins).

local Freeze = require(script.Parent.Parent.Freeze)

local LOBBY_SIZE = Vector3.new(80, 1, 80)
local LANE_COUNT = 6

-- Stages sit far outside the walkable map (past the baseplate edge), one per lane slot, side by side along X.
-- +X is "forward" (heroes walk left to right); cameras stand on the +Z side facing -Z, away from the lobby.
local STAGE_ROW = Vector3.new(0, 0, -6000)
local STAGE_SPACING = 900

local origins: { CFrame } = {}
for i = 1, LANE_COUNT do
	origins[i] = CFrame.new(STAGE_ROW + Vector3.new((i - (LANE_COUNT + 1) / 2) * STAGE_SPACING, 0, 0))
end

return Freeze({
	FolderName = "Arena",
	LobbySize = LOBBY_SIZE,
	LaneCount = LANE_COUNT,
	-- Lane origin = top surface centre; unit x in the sim maps to origin + (x + HeroOffsetX) along +X.
	LaneOrigins = origins,
	HeroOffsetX = -18,
	-- Middle of the battle along X (lane origin space): cameras look here and the scenery is centred on it.
	StageCenterX = 4,
	FloorY = 0.5,
	-- Monsters drawn at once per lane (the sim keeps the rest; only the picture is capped).
	MaxMonsters = 40,
	MaxMonstersWatched = 20,
	MaxMonstersMobile = 18,
	MaxMonstersWatchedMobile = 10,
	-- Share of those caps kept with the Low detail setting on.
	LowDetailShare = 0.5,
})
