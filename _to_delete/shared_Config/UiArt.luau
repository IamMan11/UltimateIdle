--!strict
-- UI texture image ids: old-paper backgrounds, several aspect ratios per kind (source: D:\BlenderForUltimateIdle\ui\paper\<style>\Paper_<style>_<W>x<H>.png).

local Freeze = require(script.Parent.Parent.Freeze)

export type PaperImage = { W: number, H: number, Image: string }

local function paper(w: number, h: number, id: string): PaperImage
	return { W = w, H = h, Image = `rbxassetid://{id}` }
end

local UiArt: { Paper: { [string]: { PaperImage } } } = {
	Paper = {
		-- 01_PlainLight: window sheets
		Sheet = {
			paper(1024, 768, "114193836311515"),
			paper(1024, 1024, "93507060600464"),
			paper(1024, 576, "75485814272669"),
			paper(1024, 512, "81374819763816"),
			paper(1024, 384, "99859065105595"),
			paper(1024, 256, "128399438468342"),
			paper(768, 1024, "87029439878358"),
			paper(683, 1024, "133760097862097"),
			paper(576, 1024, "105837335861290"),
			paper(512, 1024, "117666003531013"),
		},
		-- 03_PlainStained: HUD cards and side panels
		Panel = {
			paper(1024, 384, "134031910699739"),
			paper(1024, 1024, "76071138572505"),
			paper(1024, 768, "99553813671126"),
			paper(1024, 512, "86803826740295"),
			paper(1024, 256, "110891617032773"),
			paper(768, 1024, "70771401937162"),
			paper(683, 1024, "138841037717609"),
			paper(512, 1024, "129030940807925"),
		},
		-- 06_WornChipped: confirm / notice modals
		Notice = {
			paper(1024, 512, "99653486810368"),
			paper(1024, 1024, "93841987357999"),
			paper(1024, 768, "119230329530698"),
			paper(1024, 576, "79084582322117"),
			paper(1024, 384, "87098194348490"),
			paper(768, 1024, "89231072734486"),
			paper(683, 1024, "83077546402992"),
			paper(576, 1024, "94380449348137"),
			paper(512, 1024, "125143292005132"),
		},
		-- 08_TornEdges: thin HUD strips
		Strip = {
			paper(1024, 256, "78116807807516"),
			paper(1024, 512, "112232009547453"),
			paper(1024, 768, "90755717327639"),
		},
	},
}

return Freeze(UiArt)
