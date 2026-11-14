--!strict
-- Client entry point: store, battle playback + camera, AFK watcher, React UI mount.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local State = require(script.State)
local Battle = require(script.Battle)
local Afk = require(script.Afk)
local App = require(script.UI.Core.App)

State.Start()
Battle.Start()
Afk.Start()

local gui = Instance.new("ScreenGui")
gui.Name = "Main"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(gui)
root:render(React.createElement(App))
