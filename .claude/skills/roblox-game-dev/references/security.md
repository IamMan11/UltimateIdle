# Security, Moderation & Compliance

## 1. Threat model

An exploiter on their own client can: read every replicated script and asset, read and modify any local value, call any remote with any arguments at any rate, take network ownership of their character and unanchored parts near them, teleport/fly/speed their own character, spoof the local DataModel so your client checks pass, and automate all of it.

They **cannot**: read `ServerScriptService`/`ServerStorage`, change server-side values directly, or see what the server never replicated.

Therefore: **the only real security boundary is the server.** Client-side checks are UX (instant feedback), never enforcement.

## 2. Validation layers

For every client-initiated action, in order:

1. **Rate** — is this player calling this too often? (see `networking.md`)
2. **Shape** — `typeof` each argument; reject NaN, infinity, wrong classes, over-long strings, tables with unexpected keys.
3. **Existence** — does the referenced Instance/id still exist, in the hierarchy the server controls?
4. **Ownership/permission** — does this player own this item / control this unit / have this role?
5. **State** — is the game in a phase where this is legal? Is the cooldown actually elapsed (server clock)?
6. **Physical plausibility** — distance, line of sight, reachability. The server recomputes; it never accepts a sent position.
7. **Economy** — can they afford it, at the server's price, and does the debit happen before the grant?

Then act, then replicate the result.

## 3. Things the server must own

Currency · inventory · damage and health · cooldowns that matter · loot rolls and RNG · prices · quest and achievement progress · match results and scoring · teleports that grant access · admin/moderator permission · anything that becomes Robux.

Random number generation belongs on the server. A client-rolled crate is a solved problem for an exploiter. Use `Random.new()` instances, not the global `math.random` seed, for anything you need to reason about.

## 4. Common exploit patterns and the fix

| Exploit | Fix |
| --- | --- |
| Remote spam to farm rewards | Token-bucket rate limit + server cooldown keyed to `os.clock()` server-side |
| Calling `BuyItem` with a negative quantity to gain currency | Validate `amount > 0` and integer; do arithmetic server-side only |
| Passing another player's character as the target | Verify the target is valid for this action and in range |
| Passing an Instance from `ReplicatedStorage` instead of `workspace` | `IsDescendantOf` the exact folder you expect |
| Re-firing a "purchase complete" remote | The server must be the one that decides purchases; there is no such client remote |
| Teleporting to a reward zone | Server distance + velocity sanity checks; make the reward server-triggered by a server-owned region |
| Reading drop rates / loot tables | Keep them in `ServerStorage`, not `ReplicatedStorage` |
| Modifying local `WalkSpeed` | Server compares travelled distance vs. allowed; keep movement-affecting rules server-checked |
| Hooking your client-side anti-cheat and returning "clean" | Client anti-cheat is telemetry, never a verdict |
| Infinite `RemoteFunction` yield to hang a server thread | Never `InvokeClient` |
| Injecting huge strings/tables to blow up memory or DataStore writes | Length caps before storage or broadcast |

## 5. Server-side movement check (sketch)

```lua
local LAST: { [Player]: { pos: Vector3, t: number, strikes: number } } = {}

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum and root:IsA("BasePart")) then continue end
		if player:GetAttribute("ServerTeleporting") then
			LAST[player] = nil
			continue
		end

		local prev = LAST[player]
		if prev then
			local dt = now - prev.t
			if dt > 0.25 then
				local allowed = (hum.WalkSpeed + 8) * dt + 4   -- tolerance for lag/jumps
				if (root.Position - prev.pos).Magnitude > allowed then
					prev.strikes += 1
					if prev.strikes >= 5 then
						AntiCheatLog(player, "speed")
						root.CFrame = CFrame.new(prev.pos)     -- rubber-band, don't insta-ban
						prev.strikes = 0
					end
				else
					prev.strikes = math.max(0, prev.strikes - 1)
				end
				prev.pos, prev.t = root.Position, now
			end
		else
			LAST[player] = { pos = root.Position, t = now, strikes = 0 }
		end
	end
end)
```

Design principle: **correct, then punish.** Rubber-band and log first; ban only on a strong, repeated signal. False-positive bans on lag spikes cost you real players.

## 6. Bans

`Players:BanAsync` is the platform-level ban API — it applies across alt accounts Roblox can associate and returns a moderation reason shown to the player.

```lua
Players:BanAsync({
	UserIds = { userId },
	Duration = 60 * 60 * 24 * 7,        -- seconds; -1 for permanent
	DisplayReason = "Exploiting: speed hacking",   -- shown to the player
	PrivateReason = "auto: speed check x20 in 5 min",
	ApplyToUniverse = true,
})
```

Keep an audit trail (who/what/when/evidence) and an unban path. Automated bans need a very high bar; prefer kicks, rollbacks, and shadow limits for ambiguous signals.

## 7. Text and UGC moderation — mandatory

Any text a player writes that another player can see **must be filtered by Roblox before display**. This is platform policy, not optional, and it applies to custom chat, name tags, pet names, signs, drawings-with-labels, team names, and anything typed into a TextBox.

```lua
local TextService = game:GetService("TextService")

local function filterForBroadcast(text: string, fromUserId: number): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId)
	end)
	if not ok or not result then
		return nil            -- on failure, show nothing — never show unfiltered text
	end

	local ok2, filtered = pcall(function()
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return ok2 and filtered or nil
end
```

- `FilterStringAsync` runs on the **server** only, and returns a `TextFilterResult`.
- For text shown to one specific user, use `GetChatForUserAsync(userId)`; for text shown to everyone, `GetNonChatStringForBroadcastAsync()`.
- Filter at the moment of display for a specific audience where possible — filtering is audience- and age-dependent.
- Cap length and reject control characters before filtering.
- If filtering fails, fail closed.

**Chat**: `TextChatService` is the current chat system; the legacy `Chat`/`Players.Chatted`-based custom chat systems have been removed. Customize chat through `TextChannel`s, `TextChatCommand`s, `TextChatService.OnIncomingMessage`, and the chat window/input properties, rather than building a parallel chat out of remotes (which would put the filtering burden entirely on you).

## 8. Policy compliance

`PolicyService:GetPolicyInfoForPlayerAsync(player)` returns per-player regional/age policy, including whether paid random items (loot boxes) are restricted, whether paid item trading is allowed, and which external link references are permitted. Respect it:

```lua
local ok, policy = pcall(function()
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end)
if ok and policy.ArePaidRandomItemsRestricted then
	-- hide loot crates for this player entirely
end
```

Other compliance notes: age-restricted content requires the right experience maturity settings; off-platform links are restricted to allowed domains; do not collect personal information; do not simulate gambling with real-money-equivalent stakes where restricted.

## 9. Not-secrets

There is no safe place on the client for a secret. Do not put API keys, webhook URLs, admin user-id lists, or licence checks in any replicated script. `HttpService` works only on the server; keep it there. Obfuscation is not security — an exploiter has your bytecode.

## 10. Security review checklist

- [ ] Every `OnServerEvent` / `OnServerInvoke` handler validates every argument
- [ ] Every rewarding action recomputes the reward server-side
- [ ] Rate limits exist on every spammable remote
- [ ] No loot tables, drop rates, or validation constants in `ReplicatedStorage`
- [ ] No `InvokeClient`
- [ ] Cooldowns use server time, stored server-side
- [ ] All player-authored text passes through `FilterStringAsync`
- [ ] Purchases are granted from `ProcessReceipt`, idempotently (see monetization)
- [ ] Movement/teleport checks exist and won't false-positive on the game's own teleports
- [ ] Ban/kick actions are logged with evidence
- [ ] `PolicyService` is respected where monetization or links are involved
