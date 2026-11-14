--!strict
-- Code redemption: normalises the typed text, looks it up in Secret/Codes, pays once per account, refuses expired/used/unknown codes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local CodeList = require(ServerScriptService.Server.Secret.Codes)
local Replication = require(script.Parent.Replication)
local Rewards = require(script.Parent.Rewards)
local Analytics = require(script.Parent.Analytics)

local Codes = {}

-- "  welcome " -> "WELCOME"
function Codes.Normalize(text: string): string
	return string.upper((string.gsub(text, "%s+", "")))
end

local function redeem(player: Player, text: string)
	if not RateLimit.Allow(player, "RedeemCode") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	local code = CodeList[Codes.Normalize(text)]
	if code == nil then
		Replication.Notify(player, "Error", "CodeUnknown")
		return
	end
	if code.Expires ~= nil and os.time() > code.Expires then
		Replication.Notify(player, "Error", "CodeExpired")
		return
	end
	if data.Codes[code.Id] then
		Replication.Notify(player, "Error", "CodeUsed")
		return
	end
	local ok, problem = Rewards.CanGrant(player, code.Reward)
	if not ok then
		Replication.Notify(player, "Error", problem or "BoxFull")
		return
	end
	data.Codes[code.Id] = true
	Replication.Set(player, { "Codes", code.Id }, true)
	local resolved = Rewards.Grant(player, code.Reward, "Reward")
	Replication.Notify(
		player,
		"CodeRedeemed",
		{ Gold = if resolved ~= nil then resolved.Gold else 0, Reward = code.Reward }
	)
	Analytics.Custom(player, `Code_{code.Id}`)
end

function Codes.Start()
	Net.RedeemCode:Server():On(redeem)
end

return Codes
