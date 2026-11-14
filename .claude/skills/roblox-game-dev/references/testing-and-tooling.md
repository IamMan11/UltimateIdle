# Tooling, Testing & Workflow

## 1. The external-editor toolchain

| Tool | Role |
| --- | --- |
| **Rokit** (or Aftman/Foreman) | Pins tool versions per project in `rokit.toml`; `rokit install` reproduces the toolchain |
| **Rojo** | Maps filesystem → Roblox Instances; `rojo serve` live-syncs into Studio, `rojo build` produces a place file |
| **Wally** | Package manager; `wally.toml` + `wally.lock`, installs into `Packages/` and `ServerPackages/` |
| **wally-package-types** | Copies `export type` declarations into installed packages so the type checker can see them |
| **luau-lsp** | Language server: types, autocomplete, go-to-definition; needs a sourcemap |
| **StyLua** | Formatter; configured by `stylua.toml` |
| **selene** | Linter; `selene.toml` + a generated `roblox.yml` standard library |

Typical loop:

```bash
rokit install                                    # once, and after rokit.toml changes
wally install                                    # after wally.toml changes
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
rojo serve                                       # leave running; connect from the Studio plugin
# ... edit ...
stylua src/ && selene src/                       # before declaring done
rojo build -o Game.rbxlx                         # place file for CI or backup
```

Gotchas worth knowing:

- `wally install` **deletes and recreates** `Packages/` — file watchers (luau-lsp, Rojo) can hold stale paths and crash with canonicalize/not-found errors. Reload the editor window after installing.
- File extension decides the Instance class: `Foo.luau` → ModuleScript, `Foo.server.luau` → Script, `Foo.client.luau` → LocalScript, `init.luau` in a folder → that folder becomes the ModuleScript. A misnamed file syncs but never runs, with **no error**.
- Anything not mapped in `default.project.json` is left alone by Rojo — that's how a hand-built map in Studio survives syncing. Don't add `Workspace`/`Lighting` to the project file unless you intend Rojo to own them.
- Commit `wally.toml`, `wally.lock`, `rokit.toml`, `default.project.json`, `.luaurc`, `stylua.toml`, `selene.toml`. Gitignore `Packages/`, `ServerPackages/`, `sourcemap.json`, build artifacts.
- `.luaurc` sets `languageMode` and can define `aliases` for require paths.

Alternative stacks: **roblox-ts** (TypeScript → Luau, strong types, npm ecosystem, extra compile step) and **Lune** (standalone Luau runtime for scripts and CI tasks). Both are real production choices; neither is required.

## 2. Testing

Roblox code is testable if you keep logic out of Instances. The rule: **pure functions and modules that take their dependencies as arguments**. A damage formula that reads `workspace` is untestable; one that takes `(attackerStats, defenderStats)` is trivially testable.

**Jest Lua** (`jsdotlua/jest-lua`) is the current mainstream test framework — Jest semantics, `describe`/`it`/`expect`, mocks, snapshots. **TestEZ** is the older BDD framework still found in many repos; it is effectively frozen but works.

```lua
-- src/shared/combat/Damage.spec.luau
return function()
	local Damage = require(script.Parent.Damage)

	describe("computeDamage", function()
		it("applies the crit multiplier", function()
			expect(Damage.compute({ base = 10, crit = true, critMult = 2 })).to.equal(20)
		end)

		it("never returns negative damage", function()
			expect(Damage.compute({ base = 10, armor = 999 })).to.equal(0)
		end)
	end)
end
```

Run tests headlessly in CI by building a test place with Rojo and running it via `run-in-roblox`, or by keeping engine-free logic runnable under Lune. Test what has rules: damage formulas, economy math, inventory operations, state machines, serialization/migration. Do not try to unit-test rendering or physics — test those by playing.

**Always also do a two-client playtest.** In Studio: Test → Players → 2, Start. Many bugs (replication order, per-player state, network ownership) only appear with a second client. Test as a fresh player with no saved data, and as a returning player with old-schema data.

## 3. Debugging

- **Output window** — errors include a script path and line; click to jump. Enable "Log Mode" for timestamps.
- **Developer Console (F9)** in a live game — separate server and client tabs, memory, and network views. This is how you debug something that only reproduces live.
- **Breakpoints and the debugger** work in Studio: conditional breakpoints, watches, the call stack, and stepping. Far better than `print` for logic bugs.
- `warn()` for recoverable problems, `error()` for contract violations. Prefix logs with the system name: `[InventoryService]`.
- `debug.traceback()` inside a handler to find who called you.
- Structured logging beats `print(x)`: `warn(\`[Combat] {player.Name} dealt {dmg} to {target.Name}\`)`.
- Common "it works in Studio but not live": Studio API access setting, different budgets, single-player vs multi-player assumptions, `RunService:IsStudio()` branches left in, assets not published, streaming off in Studio.

## 4. Studio MCP

Roblox ships an official Studio MCP server (`Roblox/studio-rust-mcp-server`) that lets an agent read the game tree, search scripts, inspect instances, run Luau in Studio, and start/stop play tests. When those tools are available:

- **Read before you write.** Inspect the existing hierarchy and scripts rather than assuming a layout.
- Verify after each change: run the snippet, read the console output.
- Treat play-mode state as disposable — changes made during play are discarded, and some operations cannot be undone. Confirm before destructive edits.
- Prefer few, well-chosen calls over exploratory spam; each one costs latency.

## 5. Version control

- Git works normally because the source is files. Branch per feature.
- The place file (`.rbxl`) is binary and does not merge — either keep the map in Studio and code in Git (the common split), or use `.rbxlx`/`.rbxmx` for text-diffable models when a map must be reviewed.
- CI: `rokit install` → `wally install` → `selene src/` → `stylua --check src/` → `rojo build` → (optionally) run tests → publish with Open Cloud on a tag.
- Code review checklist for Roblox specifically: server/client placement, remote validation, cleanup paths, no secrets in replicated containers, no per-frame loop added without reason, data migration included when the schema changed.

## 6. Definition of done

A change is done when: it works with two clients, `stylua` and `selene` pass, the type checker is clean (no new `any`), connections are cleaned up, the server validates anything the client sent, data changes have a migration, and there is a written test plan someone else could follow.
