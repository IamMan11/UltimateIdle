--!strict
-- Frame art from Config.UiArt: 9-slice backgrounds (paper sheets, gilt leather plates, slots, buttons) that fill their parent, with the piece's shadow margin drawn outside it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UiArt = require(ReplicatedStorage.Shared.Config.UiArt)
local Theme = require(script.Parent.Theme)

local e = React.createElement

local Art = {}

export type BackProps = {
	piece: string, -- Config.UiArt.Pieces key
	transparency: number?,
	color: Color3?, -- multiplied over the art (Theme.ArtTint by default)
	edge: number?, -- 9-slice edge scale (shrink the corners on small boxes); 1 = as drawn
	padding: number?, -- the parent's UIPadding (all sides): the art reaches back out over it
	padLeft: number?, -- per-side UIPadding (overrides `padding` on that side)
	padRight: number?,
	padTop: number?,
	padBottom: number?,
	zIndex: number?,
}

local function piece(name: string): UiArt.Piece
	local p = UiArt.Pieces[name]
	if p == nil then
		error(`UiArt has no piece "{name}"`)
	end
	return p
end

-- 9-slice centre in atlas pixels. Pieces whose edges take the whole height (slim bars) get a 2 px centre band:
-- an empty centre rect is ignored by the engine and the image is not drawn.
local function centre(p: UiArt.Piece, slice: { number }): Rect
	local s, pad = p.Scale, p.Pad
	local x1, y1 = (slice[4] + pad) * s, (slice[1] + pad) * s
	local x2, y2 = p.Size.X - (slice[2] + pad) * s, p.Size.Y - (slice[3] + pad) * s
	if x2 - x1 < 2 then
		x1 = math.floor((x1 + x2) / 2) - 1
		x2 = x1 + 2
	end
	if y2 - y1 < 2 then
		y1 = math.floor((y1 + y2) / 2) - 1
		y2 = y1 + 2
	end
	return Rect.new(x1, y1, x2, y2)
end

-- ImageLabel that fills its parent plus the shadow margin. Put it in a container with BackgroundTransparency = 1
-- whose own text is empty (it draws over the parent and under siblings with a higher ZIndex) and with no UIListLayout /
-- UIGridLayout (the layout would move it); pass the parent's UIPadding as `padding`.
function Art.Back(props: BackProps): React.ReactNode
	local p = piece(props.piece)
	local pad = p.Pad
	local s = p.Scale
	local slice = p.Slice
	local edge = props.edge or 1
	local all = props.padding or 0
	local l = pad * edge + (props.padLeft or all)
	local r = pad * edge + (props.padRight or all)
	local t = pad * edge + (props.padTop or all)
	local b = pad * edge + (props.padBottom or all)
	return e("ImageLabel", {
		Size = UDim2.new(1, l + r, 1, t + b),
		Position = UDim2.fromOffset(-l, -t),
		BackgroundTransparency = 1,
		Image = UiArt.Pages[p.Page],
		ImageRectOffset = p.Offset,
		ImageRectSize = p.Size,
		ImageTransparency = props.transparency or 0,
		ImageColor3 = props.color or Theme.ArtTint,
		ScaleType = if slice ~= nil then Enum.ScaleType.Slice else Enum.ScaleType.Stretch,
		SliceCenter = if slice ~= nil then centre(p, slice) else nil,
		SliceScale = edge / s,
		ZIndex = props.zIndex or 0,
		Active = false,
	})
end

-- Edge scale that keeps a piece's top + bottom slices inside a box `height` units tall.
function Art.FitEdge(name: string, height: number): number
	local p = piece(name)
	local slice = p.Slice
	if slice == nil then
		return 1
	end
	return math.clamp(height / (slice[1] + slice[3] + 2), 0.35, 1)
end

export type ImageProps = {
	piece: string,
	width: number, -- width of the shape (without shadow margin) in design units; height follows the art
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	transparency: number?,
	layoutOrder: number?,
}

-- A whole piece drawn at a fixed width (ornaments, rings, rods): the shape box is `width` wide, the shadow spills out.
function Art.Image(props: ImageProps): React.ReactNode
	local p = piece(props.piece)
	local k = props.width / (p.Size.X / p.Scale - p.Pad * 2)
	local full = p.Size / p.Scale * k
	local pad = p.Pad * k
	local box = full - Vector2.new(pad * 2, pad * 2)
	return e("Frame", {
		Size = UDim2.fromOffset(box.X, box.Y),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		Art = e("ImageLabel", {
			Size = UDim2.fromOffset(full.X, full.Y),
			Position = UDim2.fromOffset(-pad, -pad),
			BackgroundTransparency = 1,
			Image = UiArt.Pages[p.Page],
			ImageRectOffset = p.Offset,
			ImageRectSize = p.Size,
			ImageTransparency = props.transparency or 0,
		}),
	})
end

-- Height (design units) of a piece's shape box when drawn `width` wide.
function Art.Height(name: string, width: number): number
	local p = piece(name)
	local k = width / (p.Size.X / p.Scale - p.Pad * 2)
	return (p.Size.Y / p.Scale - p.Pad * 2) * k
end

return Art
