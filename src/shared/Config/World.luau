--!strict
-- Lobby and lane layout (server builds the parts, client places units and cameras from the same numbers).

local Freeze = require(script.Parent.Parent.Freeze)

local LOBBY_SIZE = Vector3.new(80, 1, 80)
local LANE_SIZE = Vector3.new(64, 1, 18)
local LANE_COUNT = 6

-- Lane i: 3 lanes north of the lobby, 3 south; +X is "forward" (heroes walk left to right).
local origins: { CFrame } = {}
for i = 1, LANE_COUNT do
	local col = (i - 1) % 3
	local north = i <= 3
	local x = (col - 1) * (LANE_SIZE.X + 6)
	local z = if north then -(LOBBY_SIZE.Z / 2 + LANE_SIZE.Z / 2 + 6) else LOBBY_SIZE.Z / 2 + LANE_SIZE.Z / 2 + 6
	origins[i] = CFrame.new(x, 0, z)
end

return Freeze({
	FolderName = "Arena",
	LobbySize = LOBBY_SIZE,
	LaneSize = LANE_SIZE,
	LaneCount = LANE_COUNT,
	-- Lane origin = top surface centre; unit x in the sim maps to origin + (x + HeroOffsetX) along +X.
	LaneOrigins = origins,
	HeroOffsetX = -18,
	FloorY = 0.5,
})
