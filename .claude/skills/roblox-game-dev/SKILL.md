---
name: roblox-game-dev
description: Senior Roblox game engineering for any genre — Luau, DataModel architecture, client/server authority, remotes, DataStore/ProfileStore persistence, anti-exploit security, performance profiling, UI, monetization, moderation compliance, testing, and live ops. Use whenever the task involves Roblox, Luau, Roblox Studio, Rojo/Wally/Rokit projects, RemoteEvents, DataStores, or reviewing Roblox code. Do NOT use for Unity, Unreal, Godot, Love2D, or non-Roblox Lua.
---

# Roblox Game Development

Act as a senior Roblox gameplay engineer. Produce code that is **correct, server-authoritative, performant, testable, and maintainable** — never a snippet dump.

This file is a router. Read only the reference file(s) the task needs.

## 0. Before writing any code

Answer these four questions out loud (briefly) at the start of any implementation task:

1. **Where does it run?** Server / client / shared.
2. **Who owns the state?** Exactly one owner per piece of mutable state.
3. **What crosses the network?** Which remote, what payload, validated how.
4. **How is it cleaned up?** Every connection, task, and Instance has a death.

If a request is ambiguous about genre, scale, or existing architecture, ask **one** question and proceed with a stated assumption rather than blocking.

## 1. Non-negotiables

These hold unless the user explicitly overrides them:

| Rule | Why |
| --- | --- |
| Server decides anything that affects fairness, economy, or progression | The client is fully controlled by the player |
| Every remote argument is type-checked, range-checked, and ownership-checked on the server | Exploiters call remotes with arbitrary arguments at arbitrary rates |
| Every `Connect` has a matching `Disconnect` path | Leaked connections are the #1 cause of Roblox memory growth |
| Re-validate state after every yield | The world can change during `task.wait`, `:GetAsync`, `:InvokeServer` |
| No per-frame loop unless frame timing is genuinely required | Frame budget at 60 FPS is 16.67 ms for the *whole game* |
| Never `pcall` and discard the error | Silent failure is worse than a crash |
| Player-facing free text must be filtered server-side before it reaches another player | Platform policy, not a suggestion |
| `--!strict` on new files; `any` needs a comment justifying it | The type checker catches the bugs reviews miss |

## 2. Routing table

Read the file that matches the task. Do not read all of them.

| Task involves | Read |
| --- | --- |
| Luau syntax, types, tables, metatables, task scheduler, modern language features | `references/luau-language.md` |
| Project layout, DataModel placement, services/controllers, components, lifecycle, dependency direction | `references/architecture.md` |
| RemoteEvent/RemoteFunction design, payload schemas, rate limits, replication, cross-server, teleports | `references/networking.md` |
| Saving player data, DataStore limits, session locking, ProfileStore, migrations, MemoryStore | `references/data-persistence.md` |
| Anti-exploit, threat modelling, validation layers, bans, moderation, text filtering, policy compliance | `references/security.md` |
| Profiling, frame budget, memory, streaming, instance count, Parallel Luau, physics cost | `references/performance.md` |
| ScreenGui, scaling, mobile/gamepad/console input, React-lua, accessibility, localization | `references/ui-ux.md` |
| Parts, physics constraints, network ownership, characters, animation, audio, lighting, VFX, terrain, streaming | `references/world-and-content.md` |
| Game passes, developer products, `ProcessReceipt`, subscriptions, analytics, funnels, A/B, live ops | `references/monetization-and-liveops.md` |
| Rojo, Wally, Rokit, luau-lsp, StyLua, selene, unit tests, CI, Studio MCP, debugging workflow | `references/testing-and-tooling.md` |
| Obby, tycoon, simulator, round-based PvP, RPG, horror, racing, tower defense, UGC-heavy | `references/genre-blueprints.md` |
| Checking whether an API is current, deprecated, or renamed | `references/docs-lookup.md` |
| Running a smoke test in Studio (Play → console → grade), regression runs — **only when the user asks** | `references/smoke-test.md` |
| Known engine/tool quirks already hit in real work (R6 Motor6D axes, Animate script, luau-lsp, ZIndex, MeshPart alpha, Studio MCP, Cowork bridge) | `references/field-notes.md` |

## 2.5 Something is broken: symptom → where to look

Start at the owner, not at the symptom's screen.

- If the project has `docs/debug-map.md` (symptom → owner file → doc), read it first. It is project-specific and lives in the repo, not in this skill.
- No map yet → trace from the symptom's layer (server / client / replication / lifecycle / API / logic) to the module that **owns** the state, then add the row to `docs/debug-map.md` once the cause is found, so the next session starts there.
- Generic first stops: console prefix of the failing system · the remote's validator on the server · the config that holds the number · the profile template for missing/reset data.

## 3. Freshness discipline

Roblox ships engine updates weekly. Anything in this skill may have moved.

- **Before using an API you are not certain about, look it up.** `references/docs-lookup.md` has the machine-readable doc endpoints.
- State confidence honestly: "this is the current API as of the docs I checked" vs "this was true historically, verify".
- Never invent a method name, property, or enum value. If unsure, say so and look it up.
- Prefer the engine's own service over a hand-rolled replacement (`CollectionService`, `TweenService`, `PathfindingService`, `Debris`, `TextChatService`).

## 4. Output contract

When implementing a feature, deliver in this order:

1. **Ownership decision** — server/client/shared, and where each file lives.
2. **File/Explorer layout** — a tree, using the project's real paths.
3. **Complete modules** — no `-- TODO: implement`, no elided bodies.
4. **Setup steps** — Instances to create, attributes/tags to add, Studio settings.
5. **Security notes** — what the server validates and why.
6. **Performance notes** — only where there is a real cost, with the magnitude.
7. **Test plan** — concrete steps: what to click, what to expect, how to verify with 2 players.

When reviewing code, classify every finding:

- **Blocker** — exploitable, loses player data, or crashes. Fix before ship.
- **Correctness** — wrong under some input or timing. Fix soon.
- **Advisory** — style, structure, or speculative optimization. Optional.

Do not report an advisory as a blocker. Do not report a finding you have not traced to a concrete failure case: state the inputs and the wrong outcome.

When debugging:

1. Reproduce conceptually; name the layer (server / client / replication / lifecycle / API / logic).
2. Find the root cause before proposing a fix.
3. Fix the smallest structural thing that removes the cause.
4. Explain why it works, and check for the same bug elsewhere.

## 4.5 Session memory, strikes, refresh

- **`docs/STATE.md` is the memory across sessions.** Read it at the start of every session and resume what it says. Before ending, write back what the next session needs: patterns ("X causes Y, fix with Z") under Learned patterns, what failed under Dead ends, the unfinished work table — not a diary of events.
- **Circuit breaker.** Every failed fix at the same bug is a strike; log it in STATE.md (problem, attempt, result). Strike 2: before trying again, re-read the reference for that subsystem and the real code path, not your memory of it. Strike 3: stop guessing — re-read STATE.md, trace the data flow in the source, then ask the user ONE specific question stating what is known and what was tried. Fixed: move the lesson to Learned patterns and clear the row.
- **Refresh triggers.** Before writing code, re-read the CLAUDE.md rules you are about to touch (require paths, strict types, data only in the config folder). Every ~15 tool calls, re-check STATE.md and section 1 of this file. Feeling sure without having just checked is the signal to check.
- **Docs follow the code.** After touching `CLAUDE.md`, `docs/` or any SKILL.md, every path they mention must still exist — a dead path is a bug in the docs (run the repo's doc checker if it has one). After touching a generator, regenerate and confirm the generated file matches.
- **SAID vs SEEN.** A fact the user stated but you have not verified in the code is `(SAID)`; one you read in the source or saw in a run is `(SEEN)`. Tag STATE.md entries and new doc claims; never upgrade SAID to SEEN without having looked. Design decisions stay SAID until the code exists.

## 5. Scaling the solution to the project

Match architecture to project size. Over-engineering is a defect.

| Project | Appropriate |
| --- | --- |
| Prototype / one mechanic | A few scripts, direct `require`, no framework |
| Small game (1–3 systems) | Module-per-system, one bootstrap per side, plain signals |
| Mid (4–10 systems) | Service/controller split, shared types, component pattern via tags, package manager |
| Large / live | Feature folders, DI-friendly boundaries, tests, analytics, staged rollout, monitoring |

Do **not** introduce an ECS, event bus, DI container, reactive framework, or Promise wrapper unless the task demonstrably needs it. Justify every dependency in one sentence.

## 6. Project-local rules win

If the repository has an `AGENTS.md`, `CLAUDE.md`, `.luaurc`, `stylua.toml`, or `selene.toml`, those define the actual conventions (indentation, quotes, strictness, folder mapping, allowed packages). **Read them and follow them over any default in this skill.** This skill supplies engineering judgment; the repo supplies house rules.

## 6.5 Effects that pile up — server marks, client draws

For effect-heavy games (survivor, bullet-hell, big waves): any effect that sits on a world object and can exist on many objects at once (burning, status marks, ground zones…) follows this pattern. If the project documents its own system for it (e.g. a local-fx page under docs), read that first.

- Server sends **state, never visual instances**: a CollectionService tag + one attribute on the target. Damage stays server-side.
- Client draws two layers: a **light** layer (particles) on every object, a **heavy** layer (mesh, skinned) only on the nearest/on-screen ones within a per-kind quota.
- Heavy parts come from a pool: reused, never Clone/Destroy per hit — a borrowed part is reset to its template first; clone and build budgets per tick prevent spikes.
- Per-frame client work goes through one scheduler connection per phase (connected only while jobs exist), throttled by hz, and skips off-screen objects. Tagged objects are tracked by one shared tag watcher, not hand-rolled CollectionService loops in every file.
- Per-frame animation (Bone / Motor6D.Transform) runs under a fixed budget: nearest N every tick, the rest round-robin.
- Never cap by "over the limit = no visual at all" — the light layer always shows.

## 7. Anti-patterns to flag on sight

`while true do` gameplay loops where an event exists · `Heartbeat` used as a general update loop · currency or damage decided by a LocalScript · `RemoteFunction` invoked on a client from the server · unvalidated remote arguments · `wait()` / `spawn()` / `delay()` (use `task.*`) · `Humanoid:LoadAnimation` (use `Animator`) · `BodyVelocity` / `BodyPosition` (use constraints) · server logic or secrets in `ReplicatedStorage` · one 3000-line `MainScript` · `pcall` with the result thrown away · `GetDescendants()` inside a loop · `SetAsync` for player data without session locking or `UpdateAsync` · a global mutable table shared by every system · circular `require` chains · `:WaitForChild()` with a huge arbitrary timeout used to paper over ordering bugs · server cloning heavy VFX (meshes, skinned flames, emitter stacks) onto every hit target (server marks, client draws — §6.5).
