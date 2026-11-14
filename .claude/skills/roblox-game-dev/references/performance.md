# Performance

## 1. The workflow

```
Identify a real symptom  →  Measure  →  Find the root cause
  →  Change ONE thing  →  Measure again  →  Keep or revert
```

Never claim an optimization works without a before/after number when measurement is possible. "Micro-optimization" applied to code that runs 12 times per round is wasted effort and added risk.

## 2. Tools

| Tool | Opens with | Shows |
| --- | --- | --- |
| MicroProfiler | Ctrl+F6 (Studio) / F6 in client | Per-frame CPU breakdown by label; the ground truth for frame cost |
| Developer Console | F9 | Errors, log, memory by category, network traffic, script activity |
| Script Performance (Studio) | View tab | Per-script CPU share |
| Performance Stats / `--!` Stats service | F9 → Memory | Instance count, physics parts, render, Lua heap |
| `debug.profilebegin("Label")` / `debug.profileend()` | in code | Custom MicroProfiler labels — add these around your own systems |
| `os.clock()` deltas | in code | Coarse timing of a specific call |

Client and server have separate MicroProfiler sessions. A "lag" complaint is nearly always one of: server script CPU, client render, client script CPU, physics, or network — identify which before optimizing.

## 3. Frame budget

At 60 FPS the entire frame is **16.67 ms**. Rendering, physics, replication, and all your Luau share it. A system that takes 2 ms per frame has eaten 12% of the budget on its own.

Order-of-magnitude intuition:

- A `Heartbeat` handler iterating 10,000 parts: measure it; it will not be free.
- `workspace:GetDescendants()` on a large place: tens of thousands of instances, allocating a table each call. Never in a loop.
- Raycasts are cheap individually, expensive in bulk — batch, throttle, and use `RaycastParams` with a whitelist (`FilterType = Enum.RaycastFilterType.Include`) to cut work.
- `:FindFirstChild` is a name lookup; fine occasionally, avoid in a per-frame inner loop — cache the reference.

## 4. RunService phases

| Event | When | Use for |
| --- | --- | --- |
| `PreRender` (client) | Before rendering, after camera input | Camera manipulation, UI that must not lag a frame behind |
| `PreSimulation` | Before physics step | Applying forces, moving things physics will react to |
| `PostSimulation` | After physics step | Reading physics results |
| `Heartbeat` | End of frame | General gameplay ticks, server logic |
| `Stepped` / `RenderStepped` | legacy names | Prefer the Pre/Post names |
| `RunService:BindToRenderStep(name, priority, fn)` | client | Ordered render-time work with explicit priority; `UnbindFromRenderStep` to stop |

`PreRender`/`BindToRenderStep` run every rendered frame and block rendering. Use them only for things that genuinely must be frame-synchronized.

**Most gameplay does not need a frame loop at all.** Ask: can this be an event? a timer at 5 Hz? computed on demand? Prefer:

```lua
-- instead of checking every frame whether the round should end
local endsAt = os.clock() + duration
task.delay(duration, endRound)
-- and a 1 Hz tick for the visible countdown
```

## 5. Batching and time-slicing

When you must process many items, spread the work:

```lua
local index = 1
RunService.Heartbeat:Connect(function()
	local budget = os.clock() + 0.002        -- 2 ms slice
	while index <= #items and os.clock() < budget do
		process(items[index])
		index += 1
	end
	if index > #items then index = 1 end
end)
```

This turns a 30 ms stall into an invisible background cost. Use it for NPC ticks, zone checks, world generation, and save serialization.

## 6. Spatial queries

Linear scans over every object per query are O(n·m) and kill mid-size games.

- `workspace:GetPartBoundsInBox` / `GetPartBoundsInRadius` / `GetPartsInPart` with `OverlapParams` — engine-side, much faster than scripted distance loops.
- Collision groups (`PhysicsService:RegisterCollisionGroup`, `part.CollisionGroup`) to make the engine skip work entirely.
- A grid/spatial hash keyed by `math.floor(pos.X / cellSize)` covers most needs in ~40 lines.
- Octree only for large 3D spreads with frequent nearest-neighbour queries.
- Zones: prefer a part + `GetPartBoundsInPart` on a throttle, or a tag-driven zone library, over per-frame magnitude checks per player per zone.

## 7. Instances

Instance count is a first-order cost: memory, replication, streaming, and render.

- Prefer one mesh over 50 parts for decoration. Use `MeshPart`, and `PackagedInstance`/models for reuse.
- **Pool** frequently spawned short-lived objects (bullets, hit effects, coins): keep a stack of parked instances parented to `nil` (or a hidden folder), reset and re-parent instead of `Instance.new`/`Destroy`. Only worth it above roughly "several per second".
- `Debris:AddItem(part, 3)` for simple timed cleanup.
- Parent last: set all properties, then set `.Parent`. Each property change on a parented, replicated instance costs a replication message.
- `Destroy()`, not `:Remove()`; nil out your references or the instance stays in memory.
- Avoid deep hierarchies you walk repeatedly — flatten and index.

## 8. Memory

Symptoms of a leak: server memory climbing across rounds, client memory climbing across respawns.

Usual causes:

1. Connections never disconnected (especially per-character or per-UI connections re-made every respawn).
2. Tables keyed by `Player` or `Instance` never cleared on `PlayerRemoving` / `Destroying`.
3. Cached instances that were `Destroy()`ed but still referenced.
4. `task.delay` chains that re-schedule forever.
5. Cloning UI or models per respawn without destroying the old.

Check with Developer Console → Memory, which breaks down by category (Instances, LuaHeap, PhysicsParts, GraphicsTexture…). A growing `LuaHeap` with stable instance count means table/closure retention.

## 9. Streaming

`workspace.StreamingEnabled` lets the client load only nearby regions — essential for large maps, and it changes what client code may assume.

- Client code must handle Instances **not existing yet** and **disappearing**. Use `CollectionService` added/removed signals, `ChildAdded`, and `WaitForChild` with a sensible timeout — not `workspace.Map.Tower.Door` at the top of a script.
- `ModelStreamingMode`: `Atomic` (whole model streams together — use for anything that must arrive complete), `Persistent` (always loaded for everyone), `PersistentPerPlayer` (`Player:AddPersistentModel`), `Nonatomic`, `Default`.
- `StreamingIntegrityMode` controls what happens when the player outruns streaming.
- `Player:RequestStreamAroundAsync(position)` before teleporting a player so the destination is loaded.
- Server always has the full DataModel — streaming affects clients only.

## 10. Physics

- Anchor everything that doesn't need to move. Unanchored parts cost simulation every step, always.
- Reduce assembly count; weld/`WeldConstraint` groups so the solver treats them as one body.
- `CollisionFidelity` on MeshParts: `Box` and `Hull` are far cheaper than `PreciseConvexDecomposition`. Use precise only where gameplay needs it.
- `CanCollide = false` and `CanQuery = false` / `CanTouch = false` on decorative parts removes them from collision, raycast, and touch work.
- `Touched` events are expensive and unreliable for fast movement — prefer raycasts or region queries for hit detection.
- Network ownership affects where physics is simulated; see `networking.md`.

## 11. Rendering (client)

- Part count, transparency layers, and particle count dominate. Overlapping transparent surfaces are expensive.
- `Lighting.Technology` (Future/ShadowMap/Voxel) has a large cost gradient; test on low-end mobile.
- Limit simultaneous `ParticleEmitter`s and their `Rate` × `Lifetime` product.
- UI: deep `ScreenGui` trees with many `Frame`s cost layout every frame when animated. Reuse rows, don't rebuild lists per frame.
- `LODs`: `MeshPart.RenderFidelity = Enum.RenderFidelity.Automatic` or `Performance`.

## 12. Parallel Luau

For genuinely CPU-heavy, parallelizable work: pathfinding for many NPCs, procedural generation, large batch raycasts, physics-adjacent math.

```lua
-- Script under an Actor
local RunService = game:GetService("RunService")

RunService.PreSimulation:Connect(function()
	task.desynchronize()          -- now in parallel phase: reads OK, writes restricted
	local result = heavyComputation()
	task.synchronize()            -- back to serial phase before touching the DataModel
	applyResult(result)
end)
```

Rules:

- Code must live under an `Actor` instance. Each Actor is a unit of parallelism.
- In the parallel phase you may **read** most of the DataModel but not mutate it; writes must happen after `task.synchronize()`.
- `SharedTable` is the cross-Actor shared data structure; plain tables are not shared between Actors.
- Actor messaging: `Actor:SendMessage` / `BindToMessage`(`Parallel`).
- Do not parallelize work dominated by engine API calls — the synchronization cost will exceed the gain. Measure.

## 13. Things that are usually *not* the problem

Loop style (`ipairs` vs generalized iteration), local vs global microbenchmarks, string concatenation outside hot loops, `#` operator cost, function call overhead. Chasing these while a `GetDescendants()` sits in a Heartbeat handler is how performance work goes wrong.
