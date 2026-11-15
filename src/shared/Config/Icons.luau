--!strict
-- UI icon image ids (32x32 pixel art uploaded at x4; source: D:\BlenderForUltimateIdle\icons\x4\I_<Name>_128.png).

local Freeze = require(script.Parent.Parent.Freeze)

local Icons: { [string]: string } = {
	Gold = "rbxassetid://127158474227098",
	Ruby = "rbxassetid://107665406653177",
	Inventory = "rbxassetid://137864555895286",
	Boxes = "rbxassetid://111331028287869",
	Forge = "rbxassetid://126716063832656",
	Heroes = "rbxassetid://76498510471405",
	Team = "rbxassetid://105358375921524",
	Tree = "rbxassetid://88807152154753",
	Rebirth = "rbxassetid://105370568323447",
	Quests = "rbxassetid://94775333677217",
	Shop = "rbxassetid://111407956750899",
	Trade = "rbxassetid://124654614663130",
	Daily = "rbxassetid://133072109386667",
	Settings = "rbxassetid://134465902389647",
	Skip = "rbxassetid://133973509683922",
	Camera = "rbxassetid://126077791751590",
	Bag = "rbxassetid://79573046579055",
	View = "rbxassetid://136943849476120",
	Watch = "rbxassetid://99588607963184",
	Farm = "rbxassetid://136871900898671",
}

return Freeze(Icons)
