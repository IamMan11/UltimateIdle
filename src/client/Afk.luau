--!strict
-- AFK watcher: no input for Config.Game.AfkRejoinSeconds -> ask the server to rejoin us (before Roblox's 20 min kick).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local State = require(script.Parent.State)

local CHECK_EVERY = 15

local Afk = {}

function Afk.Start()
	local lastInput = os.clock()
	local requested = false
	local function touch()
		lastInput = os.clock()
		requested = false
	end
	UserInputService.InputBegan:Connect(touch)
	UserInputService.InputChanged:Connect(touch)
	-- Roblox's own idle signal: seconds idle as the engine counts it.
	Players.LocalPlayer.Idled:Connect(function(seconds: number)
		if seconds >= Game.AfkRejoinSeconds and not requested then
			requested = true
			State.Send.RequestRejoin()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			if not requested and os.clock() - lastInput >= Game.AfkRejoinSeconds then
				requested = true
				State.Send.RequestRejoin()
			end
		end
	end)
end

return Afk
