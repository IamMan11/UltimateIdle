# CLAUDE.md

Conventions for writing code in this project — read before touching any file.

**UltimateIdle** is an idle RPG (auto-battling hero team, gear, boxes, rebirth) written outside Studio and synced in with Rojo.
Language: **Luau** · Packages: **Wally** · Toolchain: **Rokit**


---

## How to respond

Respond in Thai. Be concise and direct.

- No preamble, no restating the question, no closing summary or offers.
- Answer first; add explanation only if needed or asked.
- Prefer short prose or tight bullets. No filler, no repeated points.
- If a request is ambiguous, ask ONE short question instead of guessing at length.
- When editing code, show only the changed parts with enough context to locate them (e.g. function name). Full file only if asked.
- Don't re-explain code the user wrote. No usage examples unless asked.
- Don't search the web or create files unless needed or asked. Don't reread files or info already in the chat.
- If the user writes "full", give a complete, detailed answer.

## Every session: read `docs/STATE.md` first

`docs/STATE.md` is the memory across sessions — unfinished work, strikes on bugs that keep failing, learned patterns, dead ends. Read it before starting, resume what it says, and write back before ending (patterns, not a diary). Three failed fixes on the same bug = stop guessing (rules in `.claude/skills/roblox-game-dev/SKILL.md` §4.5).

## Read the skill too, not just this file

`.claude/skills/roblox-game-dev/SKILL.md` **must be read before every code change**, alongside this file.

This file covers *this repo's conventions* — where each folder lands in Studio, which packages are allowed, which commands to run. SKILL.md covers *how to think like a Roblox engineer* — state ownership, network validation, cleanup, re-checking after yields, what a finished feature ships with.

SKILL.md is a router: read only the reference under `references/` that matches the task. When the two conflict, this file wins.

**UI windows:** before adding or changing any modal / popup / overlay, also read `.claude/skills/ui-modal/SKILL.md` and its `references/roblox-react.md`.

**Assets:** before making or reviewing any 3D model, rig, animation, VFX or sound — or writing specs for them — read `.claude/skills/game-assets/SKILL.md` and only the reference it routes to. Art style lives in `docs/art-style.md`.

**Debugging:** symptom → owner file map lives in `docs/debug-map.md`.

---

## Project structure

```
UltimateIdle/
├── src/
│   ├── shared/          code both sides use — ReplicatedStorage.Shared
│   │   ├── Net.luau     every remote event + validators
│   │   ├── Config/      all game data — require as ReplicatedStorage.Shared.Config.X
│   │   └── Text/        player-facing strings
│   ├── server/          ServerScriptService.Server
│   │   ├── init.server.luau   entry point — calls Start() on each system
│   │   ├── Data/              PlayerData (ProfileStore wrapper, PROFILE_TEMPLATE) · ProfileStore (vendored — do not edit)
│   │   └── Util/              RateLimit · Guard
│   └── client/          StarterPlayer.StarterPlayerScripts.Client
│       ├── init.client.luau   entry point — mounts React
│       ├── State/             client store (server state copy + event senders)
│       └── UI/                Core/ (App, Theme, shared widgets) · one folder per page
├── .claude/skills/      copied from E:\ClaudeShared — read before coding
├── docs/                system docs (start at docs/README.md) · STATE.md = cross-session memory · debug-map.md · art-style.md
├── Packages/            wally packages (generated, gitignored)
├── default.project.json folder → Roblox instance map
├── CLAUDE.md            this file · AGENTS.md = pointer here
├── wally.toml · wally.lock · rokit.toml
├── .luaurc              languageMode = strict
├── stylua.toml · selene.toml
└── sourcemap.json       Rojo sourcemap for luau-lsp (generated, gitignored)
```

### Folder modules and where code goes

- A folder with `init.luau` **is** the module. Sibling files inside it are private parts; `init.luau` re-exports what the rest of the game uses. Require the folder, never a file inside it from outside.
- Inside a folder module, siblings require each other with `script.Parent.X`; from an `init.luau`, its own children are `script.X`.
- Every file starts with a one-line comment saying what it holds — update it when the file's job changes.
- New code goes in the folder that owns the concern. Keep files under ~600 lines — split by concern when they grow past that.
- Only `src/shared/Config/` and `src/shared/Text/` hold game data and strings; server and client never define game numbers locally.

### Where each folder shows up in Studio

| In the project | In Roblox |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |
| `Packages/` | `ReplicatedStorage.Packages` |

Always write `require` paths using the right-hand column.

### The file extension decides the instance type

| Extension | Rojo creates |
|---|---|
| `Foo.server.luau` | `Script` — runs on the server |
| `Foo.client.luau` | `LocalScript` — runs on the player's machine |
| `Foo.luau` | `ModuleScript` |
| `init.luau` in a folder | the folder itself becomes a `ModuleScript` |

Get the name wrong and the file syncs but never runs — with no error. Always `.luau`, never `.lua`.

### What Rojo deliberately leaves alone

`default.project.json` does **not** map `Workspace`, `Lighting`, or `SoundService` — that keeps a hand-built map safe. **Don't add these services yourself** unless the project owner asks.

---

## Coding rules

### Formatting — per `stylua.toml`

Tabs, width 4 · lines ≤ 120 · `"double quotes"` · parentheses on every call. Don't format by hand: `stylua src/`.

### Type checking — strict mode is on

Annotate parameters and return values on public functions · no `any` to silence an error (comment why if you truly need it) · handle `nil` explicitly.

### Comments — English only, only where they help

The one-line file header, why `any` is used, invariants that break things if ignored, asset/file names the code can't show. No comments that restate the code.

### Generators

A script that writes a file under `src/` or `assets/` is a generator: docstring says what it reads and which files it writes · takes root/output as an argument · writes nothing else · deterministic (seed randomness) · exit 0 ok · 1 needs attention · 2 bad input. Generated files are never edited by hand.

### Never edit these by hand

| File/folder | Generated by |
|---|---|
| `Packages/` | `wally install` |
| `src/server/Data/ProfileStore.luau` | vendored from MadStudioRoblox/ProfileStore — replace the whole file, then re-add `--!nocheck` and `--!nolint` as lines 1–2 (strict mode otherwise reports ~100 errors in it; selene excludes it in `selene.toml`) |
| `sourcemap.json` | `rojo sourcemap` |
| `src/shared/Config/UiArt.luau` | `python3 gen_uiart.py <frames dir> <out>` in `D:\BlenderForUltimateIdle\ui\frames\` (after `pack_atlas.py` + uploading the atlas pages; ids in `atlas_ids.json`) |
| `wally.lock` | `wally install` |
| `roblox.yml` | `selene generate-roblox-std` (gitignored) |

---

## Available packages

| Name | Required from | Used for | Exports types? |
|---|---|---|---|
| `Red` | `ReplicatedStorage.Packages.Red` | client ↔ server networking | **No** |
| `React` | `ReplicatedStorage.Packages.React` | building UI | Yes |
| `ReactRoblox` | `ReplicatedStorage.Packages.ReactRoblox` | mounting React into Roblox | Yes |
| `Promise` | `ReplicatedStorage.Packages.Promise` | async handling | **No** |

A package that exports no types gives `TypeError: Unknown type` for any `Pkg.Type` you write. Check with `wally-package-types --sourcemap sourcemap.json Packages/` — never guess type names.

### UI theme

Theme: `src/client/UI/Core/Theme.luau` — botanical paper sheets + black leather / antique gold plates (`Wood` = leather, `Outline`, `OnDark` / `OnDarkSub` = text on leather, `Gold` = gilt text, `Panel` sheet, `PanelAlt` card, `Bg` well, `Hover` selected · `Stroke`, `Text`, `Subtext`, `Accent` · `Button`, `Confirm`, `Danger`, `Disabled`, `OnLight`, `Backdrop`, `Bar`, `BarBack` · `ArtTint`, `DangerTint` = multiplied over frame art), fonts `Font`/`FontBold` (Michroma, body) and `FontTitle` (Grenze Gotisch, headings) with `Theme.Body(size)` / `Theme.Title(size)` for every raw `TextSize` (sizes are written against the old font), z layers `ZHud` 1 · `ZPage` 3 · `ZModal` 6 · `ZTooltip` 8 · `ZToast` 10 · `ZDev` 20.
Frame art: `src/client/UI/Core/Art.luau` draws pieces from `src/shared/Config/UiArt.luau` (generated — atlas page ids + 9-slice edges; source + generators in `D:\BlenderForUltimateIdle\ui\frames\`). `Art.Back({ piece = "PaperCompactSharp" })` as a child of a transparent container = its background (card `PaperCompactSharp`, panel `PaperNotchInfo`, well/slot `SlotPaper`, selected `BtnPaperHover` / `SlotSelected`, dark plate `PlateChamfer` / `TitleBarSlim`, window `MainWindow`). Rules: the container's own text must be empty (move text into a child TextLabel with ZIndex 2), no UIListLayout/UIGridLayout beside the art (wrap the content), pass the container's UIPadding as `padding`. `Widgets.Label` / Button labels shrink long single-line text (`Widgets.Shrink`) instead of cutting it.
Widgets: `src/client/UI/Core/Widgets.luau` (`Label`, `Button`, `Bar`, `TextInput`, `Stepper`, `Window` = page/modal shell with backdrop + Esc, `useStore`, `useOptional`) · `VirtualList.luau` for long lists · `Confirm.luau` for yes/no.
Hover tooltip: give a slot `[React.Event.MouseEnter] = Tip.Enter(Tip.Gear(item, wearer))` + `[React.Event.MouseLeave] = Tip.Leave` (`Core/Tip.luau`; also `Tip.Material`/`Box`/`Socket`/`Snapshot`), or `Widgets.Button` prop `tip`. The card is drawn once at the root by `Core/Tooltip.luau`. Click = `Tip.Pin` (card stays), `Tip.Double(key)` = double click, `Tip.Press` + `Tip.SetTarget` = drag gear between windows. Team ↔ Inventory link (Team hero/slot in `State.Ui.TeamHero/TeamSlot`, equip from the bag) lives in `Core/Equip.luau`. Resizing a `FloatWindow` scales the whole window by min(width, height) against `defaultSize` (layout never gets smaller than `defaultSize`); prop `zoom` = opening size (`Config.Game.WindowZoom` for Team + Inventory).
Rule: every color comes from Theme; never hard-code a Color3 in a UI file. Pages read `State.Data`, send intent through `State.Send.*`.

### Player data — ProfileStore only

**Never call `DataStoreService` directly.** Everything goes through `PlayerData` (`require(ServerScriptService.Server.Data.PlayerData)`, store name `"PlayerData"` — never rename it) (ProfileStore handles session locking). `PlayerData.Get()` can return `nil` — check every time. Add a field = edit `PROFILE_TEMPLATE` (`:Reconcile()` backfills). **Never remove a field or change its type** once there are real players — ask first.

---

## Commands

| When | Command |
|---|---|
| Before writing code | `rojo serve` (leave it running) |
| **Before calling anything done** | `stylua src/` then `selene src/` |
| After editing `wally.toml` | `wally install` → `rojo sourcemap default.project.json --output sourcemap.json` → `wally-package-types --sourcemap sourcemap.json Packages/` → **Reload Window** |
| Fresh clone / new machine | `rokit install` → `wally install` → `selene generate-roblox-std` |
| Building a place file | `rojo build -o UltimateIdle.rbxlx` |

---

## Common errors

| Symptom | Actual cause |
|---|---|
| `Unknown type 'X.Y'` | that package exports no types, or `wally-package-types` hasn't been run |
| `Failed to update sourcemap … cannot find the path` | `wally install` deleted `Packages/` while luau-lsp watched it → **Reload Window** |
| `$path that could not be turned into a Roblox Instance` | `default.project.json` points at a folder that doesn't exist yet → `wally install` first |
| Code syncs but never runs | wrong extension — must be `.server.luau` or `.client.luau` |
| selene flags a Roblox API that really exists | `roblox.yml` missing or stale → `selene generate-roblox-std` |

---

## Ask before doing

- Adding a new package to `wally.toml`
- Editing `default.project.json`, especially adding a new service
- Changing `languageMode` in `.luaurc`
- Removing a field or changing its type in `PROFILE_TEMPLATE`
- Editing `.gitignore` — `wally.toml`, `wally.lock`, `rokit.toml` must stay committed
