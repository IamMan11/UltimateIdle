# Documentation Lookup & API Currency

Roblox ships engine updates roughly weekly. APIs are added, renamed, and deprecated continuously. **Look things up rather than recalling them.**

## 1. Machine-readable documentation endpoints

Roblox publishes agent-friendly documentation:

| URL | Contents |
| --- | --- |
| `https://create.roblox.com/docs/llms.txt` | Index of the whole documentation tree, with a "For Code Agents" quick-reference table |
| `https://create.roblox.com/docs/llms-full.txt` | The full documentation as one text file (very large — prefer the index plus a specific page) |
| `https://create.roblox.com/docs/reference/engine/llms.txt` | Index of the engine API reference (classes, datatypes, enums) |
| `https://create.roblox.com/docs/en-us/{path}.md` | Any documentation page as markdown, e.g. `.../en-us/scripting/security/security-tactics.md` |

Workflow: fetch the index once, find the path, fetch that one page as `.md`. Do not pull the full dump into context.

High-value pages to reach for:

- `cloud-services/data-stores/error-codes-and-limits` — current DataStore limits
- `scripting/security/security-tactics` — official security guidance
- `scripting/multithreading` — Parallel Luau
- `workspace/streaming` — instance streaming
- `production/monetization/...` — current product types, fees, and rules
- `reference/engine/classes/{ClassName}` — properties, methods, events, and deprecation notices for any class

## 2. Other authoritative sources

- **Luau language**: `luau.org` / `github.com/luau-lang/luau` — the language spec, RFCs, and release notes. Note that the Luau release used by Roblox Studio can lag the standalone releases.
- **DevForum announcements** (`devforum.roblox.com`, Announcements category) — where deprecations, removals, and beta features are announced before the docs catch up.
- **Roblox GitHub org** — `Roblox/studio-rust-mcp-server`, `Roblox/jest-roblox`, and other first-party tooling.
- **Community tooling**: `rojo-rbx/rojo`, `rojo-rbx/rokit`, `UpliftGames/wally`, `JohnnyMorganz/luau-lsp`, `JohnnyMorganz/StyLua`, `Kampfkarren/selene`.

Do not treat star counts as quality. Check: last commit date, open-issue responsiveness, whether it exports Luau types, and whether it is used by a game you can name.

## 3. Deprecation map

Old code and old tutorials are full of these. Replace on sight:

| Deprecated | Current |
| --- | --- |
| `wait()`, `spawn()`, `delay()` | `task.wait()`, `task.spawn()`, `task.delay()` |
| `tick()` | `os.clock()` for durations, `os.time()`/`DateTime` for wall clock |
| `Humanoid:LoadAnimation()` | `Animator:LoadAnimation()` |
| `BodyVelocity`, `BodyPosition`, `BodyGyro`, `BodyThrust`, `RocketPropulsion` | `LinearVelocity`, `AlignPosition`, `AlignOrientation`, `VectorForce` |
| `Part.Velocity`, `RotVelocity` | `AssemblyLinearVelocity`, `AssemblyAngularVelocity` |
| Legacy chat (`Chat` service, custom chat via `Players.Chatted` replication) | `TextChatService` |
| `Chat:FilterStringAsync` / `Chat:FilterStringForBroadcast` | `TextService:FilterStringAsync` + `TextFilterResult` methods |
| `Instance:Remove()` | `Instance:Destroy()` |
| `Mouse` object for gameplay input | `UserInputService` / `ContextActionService` |
| `Player:GetMouse():KeyDown` | `UserInputService.InputBegan` |
| `RunService.Stepped` / `RenderStepped` naming | `PreSimulation` / `PreRender` |
| `Workspace:FindPartsInRegion3*` | `workspace:GetPartBoundsInBox` / `InRadius` / `GetPartsInPart` |
| `Ray.new` + `workspace:FindPartOnRay` | `workspace:Raycast` with `RaycastParams` |
| `LoadLibrary` | removed |
| `game.Players.LocalPlayer` on the server | doesn't exist — server has no LocalPlayer |
| `Model.PrimaryPart` + `SetPrimaryPartCFrame` | `Model:PivotTo()` / `GetPivot()` |
| `CollectionService:GetTags` style tag scripts per-instance | `Instance:AddTag/HasTag/GetTags` + tag-bound components |

## 4. How to state uncertainty

When you are not sure an API is current:

> "`X:DoThing()` was the API for this; it may have changed — let me check the current reference." → then check.

Never:

- invent a method, property, or enum member that "sounds right";
- give a code sample using an API you have not verified when the task depends on it working;
- claim something is deprecated without a source;
- quote specific limits, fees, or percentages from memory when a number matters — look them up.

If lookup is unavailable in the current session, say so explicitly and mark the uncertain parts of the answer rather than guessing silently.

## 5. Version-sensitive areas

These change often enough that recalled knowledge goes stale fastest:

- DataStore limits and budgets, and the per-experience storage model
- Monetization product types, fees, and policy restrictions
- The chat and text-filtering APIs
- Luau type-solver behaviour (old vs new solver)
- The audio API (classic `Sound` vs the newer `AudioPlayer`/`Wire` graph)
- Avatar/UGC and body-type rules
- Studio beta features and their graduation status
- Open Cloud endpoint shapes and scopes
