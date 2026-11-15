--!strict
-- Stage scenery numbers and colours: ground, path, painted backdrop, 2D cut-out layers, 3D props (placeholder art, client-built).

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	FolderName = "Stage",
	Seed = 7,
	-- Extent along the lane (X), centred on World.StageCenterX; Z is depth (negative = behind the path).
	Width = 640,
	GroundBack = -74,
	GroundFront = 150,
	PathWidth = 16,
	-- Props keep this far from the path centre so they never cover units.
	PathClear = 10,
	PixelsPerStud = 4,
	Colors = {
		Grass = Color3.fromRGB(112, 176, 84),
		Path = Color3.fromRGB(196, 160, 112),
		PathEdge = Color3.fromRGB(160, 124, 84),
		PathPatch = Color3.fromRGB(212, 180, 134),
		Trunk = Color3.fromRGB(110, 80, 56),
		Canopy = { Color3.fromRGB(64, 138, 72), Color3.fromRGB(84, 160, 80), Color3.fromRGB(52, 120, 70) },
		Bush = Color3.fromRGB(78, 150, 70),
		Rock = Color3.fromRGB(140, 140, 146),
	},
	Backdrop = {
		Z = -72,
		Height = 150,
		Buried = 10, -- studs of the wall below the ground line
		-- Painted backdrop image ("rbxassetid://..."), tiled along the wall; empty = gradient sky + hills below.
		Image = "",
		SkyTop = Color3.fromRGB(96, 170, 225),
		SkyBottom = Color3.fromRGB(206, 234, 240),
		HillColor = Color3.fromRGB(160, 206, 196),
		HillMin = 70,
		HillMax = 150,
	},
	-- Flat cut-out layers between the backdrop and the 3D props, far to near.
	Cards = {
		{
			Z = -62,
			Height = 60,
			HillColor = Color3.fromRGB(124, 186, 140),
			HillMin = 40,
			HillMax = 90,
			TreeColor = Color3.fromRGB(96, 164, 116),
			TrunkColor = Color3.fromRGB(120, 110, 96),
			TreeMin = 9,
			TreeMax = 14,
			TreeGap = 11,
		},
		{
			Z = -48,
			Height = 60,
			HillColor = Color3.fromRGB(104, 172, 100),
			HillMin = 30,
			HillMax = 60,
			TreeColor = Color3.fromRGB(70, 146, 86),
			TrunkColor = Color3.fromRGB(104, 84, 64),
			TreeMin = 12,
			TreeMax = 18,
			TreeGap = 15,
		},
	},
	Trees = { Count = 46, ZMin = -40, ZMax = -13, HeightMin = 12, HeightMax = 20 },
	Bushes = { Count = 70, BackZ = -30, FrontZ = 70, SizeMin = 1.6, SizeMax = 3.2 },
	Rocks = { Count = 28, SizeMin = 1, SizeMax = 2.6 },
	PathPatches = 60,
	-- Imported stage kit (ReplicatedStorage.<Folder>.<Name>); used instead of everything above except Width/Ground*/PathWidth when present.
	-- X/Z are studs from the stage centre; -Z is behind the lane, +Z toward the cameras.
	Kit = {
		Folder = "StageKits",
		Name = "Meadow",
		Prefix = "SM_Meadow_",
		FillColor = Color3.fromRGB(103, 170, 79),
		Terrain = { "Ground_A", "Ground_B", "Ground_C", "Ground_D", "FarHills_A", "FarHills_B" },
		-- Grass grows in clusters off the path: sometimes a thicket in the middle, a few single clumps around it.
		Grass = {
			Clusters = 70,
			HalfWidth = 100,
			-- Cluster centres keep this far from the path centre, out to MaxDepth on either side.
			MinDepth = 11,
			MaxDepth = 34,
			Spread = 3.5,
			ClumpsMin = 2,
			ClumpsMax = 5,
			ScaleMin = 0.8,
			ScaleMax = 1.3,
			ThicketChance = 0.45,
			Thickets = { "GrassThicket_A", "GrassThicket_B" },
			Clumps = { "GrassClump_A", "GrassClump_B", "GrassClump_C", "GrassClump_C", "FlowerClump_A" },
		},
		RockSink = 0.3,
		Rocks = {
			{ Piece = "Rock_C", X = 30, Z = -15, Scale = 1 },
			{ Piece = "Rock_E", X = 23, Z = -19, Scale = 1 },
			{ Piece = "Rock_B", X = -14, Z = -22, Scale = 1 },
			{ Piece = "Rock_E", X = -23, Z = -17, Scale = 1.05 },
			{ Piece = "Rock_A", X = -38, Z = -32, Scale = 1 },
			{ Piece = "Rock_D", X = 5, Z = -34, Scale = 1 },
			{ Piece = "Rock_A", X = 48, Z = -28, Scale = 0.9 },
			{ Piece = "Rock_F", X = -30, Z = -11, Scale = 0.9 },
			{ Piece = "Rock_E", X = 36, Z = 15, Scale = 0.8 },
			{ Piece = "Rock_F", X = -19, Z = 16, Scale = 1.1 },
			{ Piece = "Rock_C", X = -55, Z = -16, Scale = 0.75 },
			{ Piece = "Rock_E", X = 62, Z = -14, Scale = 1.15 },
		},
	},
})
