# Luau Language

Luau is a gradually-typed language derived from Lua 5.1, with Roblox-specific extensions. It is **not** Lua 5.4: no integer division `//` semantics from 5.3+, no `goto` in older code paths, no `__gc`, no bitwise operators (use `bit32`), and `#` on tables with holes is undefined.

## 1. Modes and strictness

Per-file comment on line 1, or `languageMode` in `.luaurc`:

```lua
--!strict    -- everything typed; unannotated values are inferred, mismatches are errors
--!nonstrict -- default; only annotated things are checked
--!nocheck   -- off
```

Write new code `--!strict`. When strict mode fights you:

- Prefer narrowing over `any`: `if typeof(x) == "Instance" and x:IsA("BasePart") then` narrows.
- `::` casts are an escape hatch: `local part = obj :: BasePart`. Each one is a claim you are asserting; comment non-obvious ones.
- `local x: any` needs a comment saying why.

**New type solver.** Roblox shipped a rewritten type solver; it infers more and reports differently (better generics, table literal inference, type functions). Behaviour differs from the old solver on edge cases. If a type error looks nonsensical, check which solver the project uses before rewriting code around it.

## 2. Types

```lua
export type ItemId = string

export type InventoryEntry = {
	Id: ItemId,
	Count: number,
	AcquiredAt: number,
}

export type PlayerData = {
	Coins: number,
	Level: number,
	Inventory: { [ItemId]: InventoryEntry },
	LastLogin: number?,          -- optional
}

type Result<T> = { ok: true, value: T } | { ok: false, err: string }
```

Rules:

- `export type` in a ModuleScript so consumers can `local Types = require(...)` then `Types.PlayerData`.
- Put shared types in one `shared/Types.luau` (or per-feature `types.luau`) so server and client agree.
- Annotate **public** function signatures. Do not annotate obvious locals.
- Use `?` for genuinely optional, not to silence an error you should handle.
- Union + literal types are how you model state machines: `type Phase = "Lobby" | "Countdown" | "Playing" | "Ending"`.

Third-party packages frequently export **no** types. Do not guess `SomePackage.SomeType` — open the source and look for `export type`. `wally-package-types` can backfill types into Wally packages when they exist.

## 3. Modern syntax to use

```lua
-- string interpolation
local msg = `{player.Name} collected {count} coins`

-- generalized iteration: no pairs/ipairs needed for plain tables and most Roblox containers
for _, player in Players:GetPlayers() do end
for key, value in someDictionary do end

-- if-then-else expression
local label = if isWinner then "Victory" else "Defeat"

-- compound assignment
score += 10
name ..= " (guest)"

-- continue
for _, v in list do
	if not v.Enabled then
		continue
	end
end

-- immutable config
local CONFIG = table.freeze({ MaxHealth = 100, Speed = 16 })
```

`table.freeze` on config tables makes accidental mutation an error instead of a mystery bug. `table.clone` for shallow copies (fast); write an explicit deep copy only where needed.

## 4. Task scheduler

Use `task.*`. `wait()`, `spawn()`, `delay()` are legacy: they throttle, resume on an unpredictable schedule, and swallow errors.

| API | Meaning |
| --- | --- |
| `task.wait(t)` | Yield at least `t` seconds, resumes on Heartbeat. Returns elapsed. |
| `task.spawn(fn, ...)` | Run **immediately** on a new thread. |
| `task.defer(fn, ...)` | Run at the end of the current resumption cycle. |
| `task.delay(t, fn, ...)` | Run after `t`. Returns the thread so you can `task.cancel` it. |
| `task.cancel(thread)` | Kill a pending/suspended thread. Store delayed threads you may need to cancel. |
| `task.synchronize()` / `task.desynchronize()` | Parallel Luau phase switching (see performance). |

**`task.spawn` is not a fix for ordering problems.** If code needs B after A, express that with a return value, a signal, or an await — not by spawning and hoping.

Timing sources: `os.clock()` for measuring durations (monotonic, high resolution), `os.time()` / `DateTime` for wall-clock and persistence, `tick()` is legacy, `time()` is engine uptime.

## 5. Yield safety

Any of these can yield: `task.wait`, `WaitForChild`, `:GetAsync`/`:SetAsync`/`:UpdateAsync`, `:InvokeServer`, `:InvokeClient`, `HttpService` calls, `PathfindingService:ComputeAsync`, `Player:LoadCharacter` internals, most `*Async` methods.

After a yield, **nothing is guaranteed**:

```lua
local function grantReward(player: Player, amount: number)
	local data = DataService:GetAsync(player)   -- yields
	if not player.Parent then                  -- player may have left
		return
	end
	if not data then
		return
	end
	data.Coins += amount
end
```

Re-check: player still in game, Instance still parented, humanoid still alive, state machine still in the expected phase.

## 6. Error handling

```lua
local ok, result = pcall(function()
	return store:GetAsync(key)
end)

if not ok then
	warn(`DataStore GetAsync failed for {key}: {result}`)
	-- decide: retry with backoff, fall back to defaults, or refuse to let the player play
	return nil
end
```

- `pcall` around anything that touches the network, the DataModel across a boundary, or user input.
- `xpcall(fn, debug.traceback)` when you need the stack.
- Never `pcall` and ignore. Either handle, retry, or surface.
- `assert(cond, message)` for programmer errors that should never happen in shipped code.
- `error(msg, 2)` to blame the caller's line, not yours.

## 7. ModuleScripts

- A module runs **once per Luau environment (VM)** and the result is cached for that environment.
- Server and each client have separate environments: a module's mutable state is **not shared** across the network. A "singleton" is per-side.
- A module should not have surprising side effects at require time. Prefer explicit `Module.Init()` / `Module.Start()` when order matters.
- Circular requires deadlock or return incomplete tables. Break the cycle by extracting shared types/constants to a third module, or by injecting the dependency at Init.

## 8. Tables and OOP

```lua
local Zone = {}
Zone.__index = Zone

export type Zone = typeof(setmetatable({} :: {
	Part: BasePart,
	_connections: { RBXScriptConnection },
}, Zone))

function Zone.new(part: BasePart): Zone
	local self = setmetatable({
		Part = part,
		_connections = {},
	}, Zone)
	return self
end

function Zone.Destroy(self: Zone)
	for _, c in self._connections do
		c:Disconnect()
	end
	table.clear(self._connections)
end

return Zone
```

- Use metatable OOP where instances have state + behaviour + lifetime. Use a plain table of functions otherwise.
- `_` prefix for internal fields by convention; the type system does not enforce privacy.
- Deep inheritance chains are a smell in Roblox code. Prefer composition and tags.
- Arrays vs dictionaries: never mix them in one table. `#t` is only meaningful on a hole-free array.
- Table iteration order for dictionaries is **unspecified**. Sort explicitly if order matters.

## 9. Performance-relevant language facts

- Table allocation in a hot path is the usual culprit, not "slow Lua". Reuse tables, use `table.clear`.
- String concatenation in a loop allocates each time — collect into a table and `table.concat`.
- `Vector3`/`CFrame` are immutable value types; every arithmetic op allocates. Hoist constants out of loops.
- `buffer` gives packed binary data for serialization and network payloads; far cheaper than tables of numbers for large datasets.
- `@native` / `--!native` enables native code generation for compute-heavy modules. It helps numeric code, not code dominated by engine API calls. Measure before and after.
- `table.freeze` costs nothing at runtime and prevents whole classes of bugs.
