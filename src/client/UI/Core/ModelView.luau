--!strict
-- ViewportFrame that shows hero models (clones of ReplicatedStorage.HeroModels.<class>) standing at given spots, optionally on a scene built once; the camera frames the models, or a fixed spot when `focus` is given. A class with no template draws nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local e = React.createElement

local TEMPLATES = "HeroModels"
local FOV = 30
local LIGHT_DIRECTION = Vector3.new(-0.4, -1, -0.6)

export type Entry = {
	Class: string,
	Position: Vector3, -- where the feet stand
	Yaw: number?, -- radians about Y; templates face -Z at 0
}

export type Focus = { Center: Vector3, Radius: number }

export type Props = {
	entries: { Entry },
	view: Vector3, -- direction from the models to the camera
	scene: ((parent: Instance) -> ())?, -- builds the surroundings once, when the view mounts
	focus: Focus?, -- fixed framing (the camera stays put when models move); nil = fit the models
	size: UDim2?,
	position: UDim2?,
}

-- Clone standing with its feet (bottom centre of the visible parts) on `feetAt`; returns the visible bounds after the move.
local function place(source: Model, feetAt: CFrame): (Model, Vector3, Vector3)
	local model = source:Clone()
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d.Transparency < 1 then
				low = low:Min(d.Position - d.Size / 2)
				high = high:Max(d.Position + d.Size / 2)
			end
		end
	end
	if low.X > high.X then
		local at = model:GetPivot().Position
		low, high = at, at
	end
	local feet = Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	model:PivotTo(feetAt * CFrame.new(-feet) * model:GetPivot())
	-- Yaw can swap the footprint's axes: use the wider one for both.
	local reach = math.max(high.X - low.X, high.Z - low.Z) / 2
	local base = feetAt.Position
	return model, base - Vector3.new(reach, 0, reach), base + Vector3.new(reach, high.Y - low.Y, reach)
end

local function ModelView(props: Props): React.ReactNode
	local ref = React.useRef(nil :: ViewportFrame?)
	local entries, view = props.entries, props.view
	local parts = { tostring(view) }
	for _, entry in entries do
		table.insert(parts, `{entry.Class}@{entry.Position}@{entry.Yaw or 0}`)
	end
	local focus = props.focus
	if focus ~= nil then
		table.insert(parts, `{focus.Center}@{focus.Radius}`)
	end
	local signature = table.concat(parts, ";")

	local scene = props.scene
	React.useEffect(function(): () -> ()
		local frame = ref.current
		if frame == nil or scene == nil then
			return function() end
		end
		local holder = Instance.new("Folder")
		holder.Name = "Scene"
		scene(holder)
		holder.Parent = frame
		return function()
			holder:Destroy()
		end
	end, {})

	React.useEffect(function(): () -> ()
		local frame = ref.current
		local templates = ReplicatedStorage:FindFirstChild(TEMPLATES)
		if frame == nil or templates == nil then
			return function() end
		end
		local made: { Instance } = {}
		local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
		for _, entry in entries do
			local source = templates:FindFirstChild(entry.Class)
			if source ~= nil and source:IsA("Model") then
				local at = CFrame.new(entry.Position) * CFrame.Angles(0, entry.Yaw or 0, 0)
				local model, from, to = place(source, at)
				model.Parent = frame
				table.insert(made, model)
				low, high = low:Min(from), high:Max(to)
			end
		end
		if #made > 0 or focus ~= nil then
			local centre = if focus ~= nil then focus.Center else (low + high) / 2
			local radius = if focus ~= nil then focus.Radius else (high - low).Magnitude / 2
			local camera = Instance.new("Camera")
			camera.FieldOfView = FOV
			camera.CFrame = CFrame.lookAt(centre + view.Unit * (radius / math.sin(math.rad(FOV / 2))), centre)
			camera.Parent = frame
			frame.CurrentCamera = camera
			table.insert(made, camera)
		end
		return function()
			for _, instance in made do
				instance:Destroy()
			end
		end
	end, { signature })

	return e("ViewportFrame", {
		ref = ref,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
		Ambient = Theme.Subtext,
		LightColor = Theme.Text,
		LightDirection = LIGHT_DIRECTION,
	}, {
		Corner = Widgets.Corner(8),
		Stroke = Widgets.Stroke(),
	})
end

return ModelView
