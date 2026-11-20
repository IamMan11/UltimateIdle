--!strict
-- Inventory window (floating): left = every bag slot in a paged grid (Grid) · right = Sockets / Enhance / Power tabs working on the gear picked in the grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.State)
local Grid = require(script.Grid)
local SocketsTab = require(script.SocketsTab)
local EnhanceTab = require(script.EnhanceTab)
local PowerTab = require(script.PowerTab)
local UpgradePick = require(script.UpgradePick)

local e = React.createElement
local UI = Text.UI

type Tab = "Sockets" | "Enhance" | "Power"

local TABS: { { Id: Tab, Label: string } } = {
	{ Id = "Sockets", Label = UI.Sockets },
	{ Id = "Enhance", Label = UI.Enhance },
	{ Id = "Power", Label = UI.Enchant },
}

local DEFAULT_SIZE = Vector2.new(1160, 640)
local MIN_SIZE = Vector2.new(640, 360)
-- Share of the window the grid takes; GAP separates it from the tabs.
local LEFT = 0.54
local GAP = 14
local TAB_H = 34

export type Props = { data: Types.ProfileData }

local function close()
	State.CloseWindow("Inventory")
end

local function Inventory(props: Props): React.ReactNode
	local data = props.data
	local tab, setTab = React.useState("Enhance" :: Tab)
	local useUid, setUseUid = Widgets.useOptional(nil :: string?)
	local enhMode, setEnhMode = React.useState("Enhance" :: EnhanceTab.Mode)
	local merging = tab == "Sockets"
	local finding, setFinding = React.useState(false)
	local upgrading = tab == "Enhance" and enhMode == "Upgrade"
	local upPicked, setUpPicked = React.useState({} :: { string })
	local upFinding, setUpFinding = React.useState(false)
	local upSlots = UpgradePick.Slots(data, upPicked)

	local worn = ItemInfo.WornMap(data)
	local keepUid = State.Ui.ForgeUid
	local keep = if keepUid ~= nil then data.Gear[keepUid] else nil
	local use = if useUid ~= nil then data.Gear[useUid] else nil
	-- The piece to use up must still be a duplicate of the kept one (either can change or be merged away).
	if use ~= nil and (keep == nil or worn[use.Uid] ~= nil or not Formula.Forge.CanMerge(keep, use)) then
		use = nil
	end

	local duplicates = 0
	if merging and keep ~= nil then
		for uid, item in data.Gear do
			if worn[uid] == nil and Formula.Forge.CanMerge(keep, item) then
				duplicates += 1
			end
		end
	end
	-- The duplicate list belongs to one kept piece at one socket count; a merge or a new pick ends it.
	local keepSockets = if keep ~= nil then #keep.Sockets else 0
	React.useEffect(function()
		setFinding(false)
	end, { keepUid, keepSockets, merging } :: { any })

	local function onGear(uid: string)
		local item = data.Gear[uid]
		if item == nil then
			return
		end
		-- Create socket with a kept piece: an unworn duplicate becomes the piece to use up; anything else is the new kept piece.
		if merging and keep ~= nil and worn[uid] == nil and Formula.Forge.CanMerge(keep, item) then
			setUseUid(uid)
		else
			State.SelectForge(uid)
			setUseUid(nil)
		end
	end

	-- Upgrade mode: an insert clicked in the grid goes into the next free slot.
	local function onMaterial(id: string)
		if not upgrading then
			return
		end
		local slots = UpgradePick.Add(data, upSlots, id)
		if slots ~= nil then
			setUpPicked(slots)
		end
	end

	local tabs: { [string]: React.ReactNode } = {}
	for i, t in TABS do
		tabs[t.Id] = e(Widgets.Button, {
			text = t.Label,
			size = UDim2.new(1 / #TABS, -4, 1, 0),
			position = UDim2.new((i - 1) / #TABS, 2, 0, 0),
			selected = tab == t.Id,
			onClick = function()
				setTab(t.Id)
				setUpFinding(false)
			end,
		})
	end

	local body: React.ReactNode
	if tab == "Sockets" then
		body = e(SocketsTab, {
			data = data,
			keep = keep,
			use = use,
			onClearKeep = function()
				State.SelectForge(nil)
				setUseUid(nil)
			end,
			onClearUse = function()
				setUseUid(nil)
			end,
			finding = finding,
			duplicates = duplicates,
			onFind = function()
				setFinding(not finding)
			end,
		})
	elseif tab == "Power" then
		body = e(PowerTab, { data = data, item = keep })
	else
		body = e(EnhanceTab, {
			data = data,
			item = keep,
			mode = enhMode,
			onMode = function(mode: EnhanceTab.Mode)
				setEnhMode(mode)
				setUpFinding(false)
			end,
			upgradeSlots = upSlots,
			upgradeFinding = upFinding,
			onUpgradeFind = function()
				setUpFinding(not upFinding)
			end,
			onUpgradeSlots = function(slots: { string })
				setUpPicked(slots)
			end,
		})
	end

	local stackPct = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel).StackPct
	return e(FloatWindow, {
		id = "Inventory",
		title = `{UI.Inventory}  {Formula.Bag.Used(data, stackPct)}/{Game.InventoryCapacity}`,
		onClose = close,
		defaultSize = DEFAULT_SIZE,
		minSize = MIN_SIZE,
		zoom = Game.WindowZoom,
		-- Opens beside the Team window so gear can be dragged between them.
		defaultCenter = Vector2.new(0.7, 0.55),
	}, {
		Left = e("Frame", { Size = UDim2.new(LEFT, -GAP, 1, 0), BackgroundTransparency = 1 }, {
			Grid = e(Grid, {
				data = data,
				keepUid = if keep ~= nil then keep.Uid else nil,
				useUid = if merging and use ~= nil then use.Uid else nil,
				mergeFor = if merging and finding then keep else nil,
				insertsFor = if upgrading and upFinding then UpgradePick.Filter(upSlots) else nil,
				onMaterial = onMaterial,
				onGear = onGear,
			}),
		}),
		Right = e("Frame", {
			Size = UDim2.fromScale(1 - LEFT, 1),
			Position = UDim2.fromScale(LEFT, 0),
			BackgroundTransparency = 1,
		}, {
			Tabs = e("Frame", { Size = UDim2.new(1, 0, 0, TAB_H), BackgroundTransparency = 1 }, tabs),
			Panel = e("Frame", {
				Size = UDim2.new(1, 0, 1, -(TAB_H + 8)),
				Position = UDim2.fromOffset(0, TAB_H + 8),
				BackgroundColor3 = Theme.Bg,
			}, {
				Corner = Widgets.Corner(8),
				Padding = Widgets.Padding(12),
				-- Keyed by tab so each tab starts from its own state (scroll, index view).
				[tab] = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, { Body = body }),
			}),
		}),
	})
end

return Inventory
