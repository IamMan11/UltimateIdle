--!strict
-- Page groups: pages that share one window and switch by tabs; the HUD shows one button per group.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local State = require(script.Parent.Parent.Parent.State)

local UI = Text.UI

export type Tab = { Id: string, Label: string }

local GROUPS: { [string]: { Title: string, Tabs: { Tab } } } = {
	Inventory = {
		Title = UI.Inventory,
		Tabs = {
			{ Id = "Bag", Label = UI.Bag },
			{ Id = "Boxes", Label = UI.Boxes },
			{ Id = "Forge", Label = UI.Forge },
		},
	},
}

local Groups = {}

-- Group id that owns `page`, if any.
function Groups.Of(page: string?): string?
	for id, group in GROUPS do
		for _, tab in group.Tabs do
			if tab.Id == page then
				return id
			end
		end
	end
	return nil
end

function Groups.Title(group: string): string
	return GROUPS[group].Title
end

function Groups.Tabs(group: string): { Tab }
	return GROUPS[group].Tabs
end

-- HUD button: closes the group if one of its pages is open, else opens the page last used in it.
function Groups.Toggle(group: string)
	if Groups.Of(State.Ui.Page) == group then
		State.SetPage(nil)
	else
		State.SetPage(State.Ui.Tabs[group] or GROUPS[group].Tabs[1].Id)
	end
end

-- Tab button inside the window.
function Groups.Select(page: string)
	if State.Ui.Page ~= page then
		State.SetPage(page)
	end
end

-- Records the open page as its group's last tab (pages can also be opened from elsewhere, e.g. State.OpenForge).
function Groups.Remember()
	local page = State.Ui.Page
	local group = Groups.Of(page)
	if group ~= nil and page ~= nil then
		State.Ui.Tabs[group] = page
	end
end

return Groups
