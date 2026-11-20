--!strict
-- Inventory window, left side (prop mergeFor = only duplicates for the socket merge): search + Auto (auto-salvage window) + Filter (modal, State.Ui.BagFilter), 8 x 7 grid of bag slots in pages (back / page / next), a line about the picked slot and its actions (gear: salvage · box: open, open all, more). Right click on gear = GearMenu (Lock / Salvage) that starts a mode with a banner over the grid: click or press + drag across cells · Lock = toggles locks, Done leaves · Salvage = marks pieces, the line shows what they give, Confirm salvages, Cancel leaves. Click pins a slot's card; gear: double click or drag onto a Team slot = wear it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Theme = require(script.Parent.Parent.Core.Theme)
local Art = require(script.Parent.Parent.Core.Art)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Entries = require(script.Parent.Entries)
local UpgradePick = require(script.Parent.UpgradePick)
local GearMenu = require(script.Parent.GearMenu)
local SalvageInfo = require(script.Parent.SalvageInfo)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local Tip = require(script.Parent.Parent.Core.Tip)
local Equip = require(script.Parent.Parent.Core.Equip)

local e = React.createElement
local UI = Text.UI

local COLS, ROWS = 8, 7
local PAGE = COLS * ROWS
local HEAD_H = 34
local FOOT_H = 34
local INFO_H = 22
local GAP = 8
local CELL_GAP = 6
local BADGE = 18

type Mode = "Lock" | "Salvage"

export type Props = {
	data: Types.ProfileData,
	keepUid: string?, -- gear the right side works on
	useUid: string?, -- gear picked to be used up (Sockets tab)
	mergeFor: Types.GearItem?, -- show only this piece and the unworn duplicates that can be used up for it
	insertsFor: UpgradePick.Filter?, -- show only upgradable inserts (of this kind + tier once one is picked)
	onGear: (uid: string) -> (),
	onMaterial: (id: string) -> (),
}

local function Grid(props: Props): React.ReactNode
	local data = props.data
	local mergeFor = props.mergeFor
	local insertsFor = props.insertsFor
	local insertsKey = if insertsFor ~= nil then `{insertsFor.Kind}:{insertsFor.Tier}` else ""
	local query, setQuery = React.useState("")
	local filter = State.Ui.BagFilter
	local kind, tier, sort, gearSlot = filter.Kind, filter.Tier, filter.Sort, filter.Slot
	local page, setPage = React.useState(1)
	-- A new filter starts from the first page.
	React.useEffect(function()
		setPage(1)
	end, { kind, tier, sort, gearSlot, mergeFor, insertsKey } :: { any })
	local picked, setPicked = Widgets.useOptional(nil :: string?)
	local menuKey, setMenuKey = Widgets.useOptional(nil :: string?)
	local mode, setMode = Widgets.useOptional(nil :: Mode?)
	local marked, setMarked = React.useState({} :: { [string]: boolean })
	local menuRef = React.useRef(nil :: Frame?)
	-- Lock mode: locks sent but not echoed back yet, so the icon shows at once.
	local pending, setPending = React.useState({} :: { [string]: boolean })
	-- While the pointer is down in a mode: the value being painted onto every cell it crosses (refs: read by input events between renders).
	local paint = React.useRef(nil :: boolean?)
	local lockBatch = React.useRef({} :: { string })
	-- Releasing the pointer ends the stroke; a Lock stroke is sent as one request.
	React.useEffect(function(): () -> ()
		if mode == nil then
			return function() end
		end
		local conn = UserInputService.InputEnded:Connect(function(input: InputObject)
			local press = input.UserInputType
			if press ~= Enum.UserInputType.MouseButton1 and press ~= Enum.UserInputType.Touch then
				return
			end
			local on = paint.current
			paint.current = nil
			if on ~= nil and #lockBatch.current > 0 then
				State.Send.LockGear(lockBatch.current, on)
				lockBatch.current = {}
			end
		end)
		return function()
			conn:Disconnect()
			paint.current = nil
			lockBatch.current = {}
		end
	end, { mode } :: { any })
	-- A press anywhere outside the open menu closes it.
	React.useEffect(function(): () -> ()
		if menuKey == nil then
			return function() end
		end
		local conn = UserInputService.InputBegan:Connect(function(input: InputObject)
			local press = input.UserInputType
			if
				press ~= Enum.UserInputType.MouseButton1
				and press ~= Enum.UserInputType.MouseButton2
				and press ~= Enum.UserInputType.Touch
			then
				return
			end
			local frame = menuRef.current
			if frame ~= nil then
				local p, a, s = input.Position, frame.AbsolutePosition, frame.AbsoluteSize
				if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then
					return
				end
			end
			setMenuKey(nil)
		end)
		return function()
			conn:Disconnect()
		end
	end, { menuKey } :: { any })

	-- Pieces marked for salvage that can still go: in the bag, not worn, not locked.
	local worn = ItemInfo.WornMap(data)
	local salvageUids: { string } = {}
	local salvageGold, salvageStones = 0, 0
	if mode == "Salvage" then
		for uid in marked do
			local item = data.Gear[uid]
			if item ~= nil and worn[uid] == nil and item.Locked ~= true then
				local gold, stones = SalvageInfo.Value(item)
				table.insert(salvageUids, uid)
				salvageGold += gold
				salvageStones += stones
			end
		end
	end
	local function canMark(uid: string): boolean
		local item = data.Gear[uid]
		return item ~= nil and worn[uid] == nil and item.Locked ~= true
	end
	local function isLocked(uid: string): boolean
		local item = data.Gear[uid]
		if pending[uid] ~= nil then
			return pending[uid]
		end
		return item ~= nil and item.Locked == true
	end
	local function leaveMode()
		setMode(nil)
		setMarked({})
		setPending({})
	end
	-- Paints the stroke's value onto one gear cell.
	local function apply(uid: string)
		local on = paint.current
		if on == nil then
			return
		end
		if mode == "Salvage" then
			if not canMark(uid) then
				return
			end
			setMarked(function(prev: { [string]: boolean }): { [string]: boolean }
				local copy = table.clone(prev)
				local count = 0
				for _ in copy do
					count += 1
				end
				if not on then
					copy[uid] = nil
				elseif count < Game.SalvageBatchMax then
					copy[uid] = true
				end
				return copy
			end)
		elseif mode == "Lock" and isLocked(uid) ~= on and #lockBatch.current < Game.SalvageBatchMax then
			table.insert(lockBatch.current, uid)
			setPending(function(prev: { [string]: boolean }): { [string]: boolean }
				local copy = table.clone(prev)
				copy[uid] = on
				return copy
			end)
		end
	end

	local entries: { Entries.Entry }
	if mergeFor ~= nil then
		-- Search and the bag filter are set aside so no duplicate stays hidden.
		entries = {}
		for _, entry in Entries.Build(data, { Query = "", Kind = "Gear", Tier = nil, Sort = sort :: Entries.SortKey }) do
			local item = data.Gear[entry.Id]
			if
				entry.Id == mergeFor.Uid
				or (item ~= nil and not entry.Worn and Formula.Forge.CanMerge(mergeFor, item))
			then
				table.insert(entries, entry)
			end
		end
	elseif insertsFor ~= nil then
		entries = {}
		for _, entry in
			Entries.Build(data, { Query = "", Kind = "Material", Tier = nil, Sort = sort :: Entries.SortKey })
		do
			local def = Inserts.ById[entry.Id]
			if
				def ~= nil
				and UpgradePick.Can(entry.Id)
				and (insertsFor.Kind == nil or def.Kind == insertsFor.Kind)
				and (insertsFor.Tier == nil or def.Tier == insertsFor.Tier)
			then
				table.insert(entries, entry)
			end
		end
	else
		entries = Entries.Build(data, {
			Query = query,
			Kind = kind :: Entries.Kind?,
			Tier = tier,
			Slot = gearSlot,
			Sort = sort :: Entries.SortKey,
		})
	end
	local pages = math.max(math.ceil(#entries / PAGE), 1)
	local shown = math.clamp(page, 1, pages)

	local chosen: Entries.Entry? = nil
	local cells: { [string]: React.ReactNode } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / COLS, -CELL_GAP, 1 / ROWS, -CELL_GAP),
			CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i = 1, PAGE do
		local entry = entries[(shown - 1) * PAGE + i]
		if entry == nil then
			-- Empty slots keep the grid's shape on a short page.
			cells[`Empty{i}`] = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = i,
			}, { Art = Art.Back({ piece = "SlotPaper", transparency = 0.35 }) })
			continue
		end
		local isKeep = entry.Kind == "Gear" and entry.Id == props.keepUid
		local isUse = entry.Kind == "Gear" and entry.Id == props.useUid
		local isPicked = picked == entry.Key
		if isPicked then
			chosen = entry
		end
		local gear = if entry.Kind == "Gear" then data.Gear[entry.Id] else nil
		local locked = gear ~= nil and isLocked(entry.Id)
		local isMarked = mode == "Salvage" and gear ~= nil and marked[entry.Id] == true and canMark(entry.Id)
		local tip = if entry.Kind == "Gear"
			then Tip.BagGear(data.Gear[entry.Id], entry.WornBy)
			elseif entry.Kind == "Box" then Tip.Box(entry.Id, entry.Count)
			else Tip.Material(entry.Id, entry.Count)

		local menu: React.ReactNode = nil
		if menuKey == entry.Key and gear ~= nil then
			local uid = entry.Id
			menu = e(GearMenu, {
				frameRef = menuRef,
				locked = locked,
				up = (i - 1) // COLS >= ROWS - 2,
				right = (i - 1) % COLS >= COLS - 1,
				onLock = function()
					setMenuKey(nil)
					setMarked({})
					setPending({ [uid] = not locked })
					setMode("Lock")
					State.Send.LockGear({ uid }, not locked)
				end,
				onSalvage = function()
					setMenuKey(nil)
					setPending({})
					setMarked(if canMark(uid) then { [uid] = true } else {})
					setMode("Salvage")
				end,
			})
		end
		local enter = Tip.Enter(tip)
		local accent = Theme.TierAccent(entry.Tier)

		cells[entry.Key] = e("TextButton", {
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			-- The cell holding the open menu draws over its neighbours.
			ZIndex = if menu ~= nil then 5 else 1,
			-- In a mode the pointer paints (no hover card over the grid).
			[React.Event.MouseEnter] = function(...: any)
				if mode == nil then
					enter(...)
				elseif gear ~= nil then
					apply(entry.Id)
				end
			end,
			[React.Event.MouseLeave] = Tip.Leave,
			-- In a mode: a press starts a stroke (marks if this cell is unmarked, else unmarks) · otherwise gear can be dragged onto a gear slot of the Team window.
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				local press = input.UserInputType
				if mode ~= nil then
					if
						gear ~= nil
						and menuKey == nil
						and (press == Enum.UserInputType.MouseButton1 or press == Enum.UserInputType.Touch)
					then
						paint.current = if mode == "Salvage" then not isMarked else not locked
						apply(entry.Id)
					end
				elseif entry.Kind == "Gear" and menuKey == nil then
					Tip.Press(input, entry.Id, entry.Label, function(target: string)
						local now = State.Data
						if now ~= nil then
							Equip.FromBag(now, entry.Id, target)
						end
					end)
				end
			end,
			[React.Event.MouseButton2Click] = function(_rbx: TextButton)
				if entry.Kind == "Gear" then
					Tip.Unpin(nil)
					Tip.Hide(nil)
					setMenuKey(entry.Key)
				end
			end,
			-- Click = pick + pin its card, double click on gear = wear it on the Team window's hero (modes handle the press in InputBegan).
			[React.Event.Activated] = function(rbx: TextButton)
				if mode ~= nil then
					return
				end
				setPicked(entry.Key)
				Tip.Pin(rbx, tip)
				if entry.Kind == "Gear" then
					props.onGear(entry.Id)
					if Tip.Double(entry.Key) then
						Equip.FromBag(data, entry.Id, nil)
					end
				elseif entry.Kind == "Material" then
					props.onMaterial(entry.Id)
				end
			end,
		}, {
			Corner = Widgets.Corner(6),
			Art = Art.Back({
				piece = if isKeep or isUse or isPicked then "BtnPaperHover" else "SlotPaper",
				color = if isMarked then Theme.DangerTint else nil,
				padding = 4,
			}),
			Rim = Widgets.TierRim(entry.Tier),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = entry.Label,
				TextColor3 = if accent ~= nil then accent.Color else Theme.Text,
				FontFace = if accent ~= nil then Theme.FontBold else Theme.Font,
				TextSize = Theme.Body(11),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 2,
			}, {
				Max = e("UITextSizeConstraint", { MaxTextSize = Theme.Body(11) }),
				Heavy = if accent ~= nil then Widgets.Heavy(accent.Color, Theme.Body(11)) else nil,
			}),
			Padding = Widgets.Padding(4),
			Stroke = if isMarked
				then Widgets.Stroke(Theme.Danger, 2, 0)
				elseif isKeep or isUse then Widgets.Stroke(Theme.Accent, 2, 0)
				elseif isPicked then Widgets.Stroke(Theme.Accent, 1, 0)
				else nil,
			-- Corner mark: worn by a hero, or its part in the socket merge.
			Mark = if entry.Worn
					or isUse
					or isKeep
				then e(Widgets.Label, {
					text = if isUse then UI.Use elseif isKeep then UI.Keep else UI.EquippedMark,
					bold = true,
					textSize = 11,
					color = Theme.Accent,
					size = UDim2.new(1, 0, 0, 12),
					position = UDim2.fromOffset(0, -4),
				})
				else nil,
			-- Top right: marked for salvage, or locked.
			Badge = if isMarked or locked
				then e(Widgets.Label, {
					text = if isMarked then UI.SalvageMark else UI.LockMark,
					textSize = 15,
					align = Enum.TextXAlignment.Right,
					size = UDim2.fromOffset(BADGE, BADGE),
					position = UDim2.new(1, -BADGE, 0, -2),
				})
				else nil,
			Menu = menu,
		})
	end

	-- Actions for the picked slot
	local actions: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 6) }
	local info = if chosen ~= nil then chosen.Line else ""
	if mode == "Lock" then
		info = UI.LockModeHint
		actions.Done = e(Widgets.Button, {
			text = UI.Done,
			size = UDim2.fromOffset(100, FOOT_H),
			textSize = 15,
			onClick = leaveMode,
		})
	elseif mode == "Salvage" then
		local count = #salvageUids
		info = if count > 0
			then `{UI.Salvage} {count}:  +{Format.Number(salvageGold)} gold  ·  +{salvageStones} {Text.Material(
				"EnhanceStone"
			)}`
			else UI.SalvageModeHint
		actions.Salvage = e(Widgets.Button, {
			text = `{UI.Confirm} ({count})`,
			size = UDim2.fromOffset(130, FOOT_H),
			textSize = 15,
			color = Theme.Danger,
			disabled = count == 0,
			layoutOrder = 1,
			onClick = function()
				State.Send.Salvage(salvageUids)
				leaveMode()
			end,
		})
		actions.Cancel = e(Widgets.Button, {
			text = UI.Cancel,
			size = UDim2.fromOffset(90, FOOT_H),
			textSize = 15,
			layoutOrder = 2,
			onClick = leaveMode,
		})
	elseif chosen ~= nil and chosen.Kind == "Gear" then
		local item = data.Gear[chosen.Id]
		actions.Salvage = e(Widgets.Button, {
			text = UI.Salvage,
			size = UDim2.fromOffset(100, FOOT_H),
			textSize = 15,
			color = Theme.Danger,
			disabled = item == nil or chosen.Worn or item.Locked == true,
			onClick = function()
				if item ~= nil then
					SalvageInfo.Confirm(item)
				end
			end,
		})
	elseif chosen ~= nil and chosen.Kind == "Box" then
		local key, count = chosen.Id, chosen.Count
		actions.Open = e(Widgets.Button, {
			text = UI.Open,
			size = UDim2.fromOffset(72, FOOT_H),
			textSize = 15,
			layoutOrder = 1,
			onClick = function()
				State.Send.OpenBox(key, 1)
			end,
		})
		actions.OpenAll = e(Widgets.Button, {
			text = UI.OpenAll,
			size = UDim2.fromOffset(92, FOOT_H),
			textSize = 15,
			layoutOrder = 2,
			onClick = function()
				State.Send.OpenBox(key, count)
			end,
		})
		-- Open N, convert to class boxes: the full Boxes page.
		actions.More = e(Widgets.Button, {
			text = UI.More,
			size = UDim2.fromOffset(72, FOOT_H),
			textSize = 15,
			layoutOrder = 3,
			onClick = function()
				State.OpenWindow("Boxes")
			end,
		})
	end

	local below = INFO_H + FOOT_H + GAP * 2
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		-- Covers the search row while a mode is on.
		ModeBar = if mode ~= nil
			then e("Frame", {
				Size = UDim2.new(1, 0, 0, HEAD_H + 4),
				BackgroundTransparency = 1,
				ZIndex = 3,
				Active = true,
			}, {
				Art = Art.Back({
					piece = if mode == "Salvage" then "NoticePaper" else "TitleBarSlim",
					color = if mode == "Salvage" then Theme.DangerTint else nil,
					edge = 0.7,
				}),
				Label = e(Widgets.Label, {
					text = if mode == "Salvage" then UI.SalvageModeTitle else UI.LockModeTitle,
					bold = true,
					textSize = 14,
					color = if mode == "Salvage" then Theme.Danger else Theme.OnDark,
					align = Enum.TextXAlignment.Center,
				}),
			})
			else nil,
		Search = e("Frame", { Size = UDim2.new(1, -184, 0, HEAD_H), BackgroundTransparency = 1 }, {
			Input = e(Widgets.TextInput, {
				text = query,
				placeholder = UI.Search,
				onChanged = function(text: string)
					setQuery(text)
					setPage(1)
				end,
			}),
		}),
		AutoSalvage = e(Widgets.Button, {
			text = UI.AutoSalvageButton,
			size = UDim2.fromOffset(84, HEAD_H),
			position = UDim2.new(1, -92, 0, 0),
			anchor = Vector2.new(1, 0),
			textSize = 15,
			-- Lit while auto-salvage is switched on.
			selected = data.Settings.AutoSalvageOn,
			onClick = function()
				State.ToggleWindow("AutoSalvage")
			end,
		}),
		FilterButton = e(Widgets.Button, {
			text = UI.Filter,
			size = UDim2.fromOffset(84, HEAD_H),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			textSize = 15,
			-- Lit while the grid is narrowed down.
			selected = mergeFor ~= nil or insertsFor ~= nil or kind ~= nil or tier ~= nil or gearSlot ~= nil,
			onClick = function()
				State.ShowBagFilter(true)
			end,
		}),
		Cells = e("Frame", {
			Size = UDim2.new(1, CELL_GAP, 1, -(HEAD_H + GAP + below)),
			Position = UDim2.fromOffset(0, HEAD_H + GAP),
			BackgroundTransparency = 1,
			-- Over the footer while a menu hangs out of the last row.
			ZIndex = if menuKey ~= nil then 2 else 1,
		}, cells),
		Info = e(Widgets.Label, {
			text = info,
			stat = true,
			color = Theme.Subtext,
			textSize = 13,
			position = UDim2.new(0, 0, 1, -(FOOT_H + GAP + INFO_H)),
			size = UDim2.new(1, 0, 0, INFO_H),
		}),
		Actions = e("Frame", {
			Size = UDim2.new(1, -220, 0, FOOT_H),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, actions),
		Pager = e("Frame", {
			Size = UDim2.fromOffset(212, FOOT_H),
			Position = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
		}, {
			Back = e(Widgets.Button, {
				text = UI.Back,
				size = UDim2.fromOffset(68, FOOT_H),
				textSize = 15,
				disabled = shown <= 1,
				onClick = function()
					setPage(shown - 1)
				end,
			}),
			Page = e(Widgets.Label, {
				text = `{shown}/{pages}`,
				align = Enum.TextXAlignment.Center,
				textSize = 15,
				position = UDim2.fromOffset(68, 0),
				size = UDim2.fromOffset(76, FOOT_H),
			}),
			Next = e(Widgets.Button, {
				text = UI.Next,
				size = UDim2.fromOffset(68, FOOT_H),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				textSize = 15,
				disabled = shown >= pages,
				onClick = function()
					setPage(shown + 1)
				end,
			}),
		}),
	})
end

return Grid
