# UI, Input & Accessibility

## 1. Rules that prevent the two most common UI bugs

**Scale, don't offset.** `UDim2.fromScale(0.3, 0.1)` adapts to every screen; `UDim2.fromOffset(300, 100)` looks right on your monitor and broken on a phone. Use offset only for things that must be a fixed pixel size (borders, icons with a minimum readable size) and pair with `UISizeConstraint`.

**Respect the safe area.** Roblox's top bar, and phone notches, overlap your UI.

- `ScreenGui.IgnoreGuiInset = false` (default) keeps your UI below the top bar.
- `ScreenGui.ScreenInsets` / `GuiService:GetGuiInset()` tell you the real inset.
- Keep interactive elements away from the top-left (Roblox menu) and the bottom-centre (mobile jump/thumbstick).

## 2. Layout

Let the engine lay out; don't compute positions in Lua.

| Object | Use |
| --- | --- |
| `UIListLayout` | Stacked lists; set `SortOrder = LayoutOrder` and `Padding` |
| `UIGridLayout` | Inventory grids |
| `UITableLayout` | Aligned rows/columns |
| `UIPadding` | Inner spacing — do not fake it with an inset frame |
| `UIAspectRatioConstraint` | Keep a card square on every screen |
| `UISizeConstraint` / `UITextSizeConstraint` | Min/max pixel clamps on top of scale |
| `UIScale` | One number to scale a whole panel (great for a global UI-size setting) |
| `UICorner`, `UIStroke`, `UIGradient` | Visuals without image assets |
| `CanvasGroup` | Fade or tint a whole subtree at once |
| `AutomaticSize` | Frames/labels that size to their content |

`ScrollingFrame`: set `AutomaticCanvasSize = Enum.AutomaticSize.Y` with a `UIListLayout` instead of computing `CanvasSize` yourself.

Text: `TextScaled = true` plus a `UITextSizeConstraint` is the reliable pattern. Use `FontFace`/`FontFamily` rather than the legacy `Font` enum for new work. Never hardcode a pixel `TextSize` as the only sizing.

## 3. Structure

- UI lives in `StarterGui` (copied to each player's `PlayerGui` on spawn) or is created by a client controller into `PlayerGui`. **`ResetOnSpawn = false`** on any ScreenGui that should survive respawn — forgetting this is why HUDs vanish on death.
- One controller per UI feature; the controller owns the ScreenGui, its connections, and its cleanup.
- UI reads state and sends intent. It **never** decides anything authoritative: a Buy button fires a remote and waits for the server's answer; it does not decrement the coin counter itself (optimistically showing a pending state is fine, as long as the server's reply is what commits it).
- Hide/show with `.Visible` or `.Enabled`, not by destroying and rebuilding trees.

## 4. React-lua / Fusion

For anything with meaningful state (shops, inventories, settings, leaderboards), a declarative UI library pays for itself.

**React-lua** (`jsdotlua/react`, `jsdotlua/react-roblox`) — React 17 semantics in Luau. Hooks, components, keys, reconciliation.

```lua
--!strict
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local function CoinCounter(props: { count: number })
	return e("TextLabel", {
		Size = UDim2.fromScale(0.2, 0.08),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = `{props.count} coins`,
	})
end

-- mount
local root = ReactRoblox.createRoot(playerGui:WaitForChild("HUD"))
root:render(e(CoinCounter, { count = 0 }))
```

Notes: keep components pure, lift state to one store per feature, use `React.useEffect` cleanups for connections, and unmount with `root:unmount()` on teardown. Profile — reconciliation is not free when a list re-renders every frame; memoize and key properly.

**Fusion** is the state-graph alternative (`Value`, `Computed`, `Observer`, `New`). Both are fine; pick one per project.

For simple static HUDs, hand-built Instances in `StarterGui` with a small controller are perfectly professional — don't add a UI framework for three labels.

## 5. Input across platforms

Roblox ships on PC, mobile, console, and VR. Assume all four unless the user says otherwise.

```lua
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

-- ContextActionService: one action, all input types, automatic mobile button
ContextActionService:BindAction("Sprint", handleSprint, true,   -- true = create touch button
	Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetImage("Sprint", "rbxassetid://...")
```

- Prefer `ContextActionService` over raw `UserInputService` for gameplay actions: it handles priority stacking, gives you a mobile button for free, and unbinds cleanly.
- `UserInputService.TouchEnabled` / `KeyboardEnabled` / `GamepadEnabled` / `MouseEnabled` to detect capability — note a device can have several. `UserInputService.LastInputType` and `LastInputTypeChanged` to know what the player is *currently* using, which is what should drive icon hints.
- Console needs gamepad navigation: set `GuiService.SelectedObject`, `Selectable = true`, and `NextSelectionUp/Down/Left/Right` on your buttons, or the player literally cannot use your menu.
- `GuiService:IsTenFootInterface()` for TV/console layouts (bigger text, larger hit targets).
- Never bind gameplay to a key that Roblox reserves, and always check `gameProcessedEvent` in `InputBegan` so typing in chat doesn't fire your abilities.
- Touch targets need ≥ 44 px of real estate; a `TextButton` that is 20 px tall on a phone is unusable.

## 6. Feedback and feel

- Every button needs a visible pressed state and a disabled state.
- Every server round-trip needs a pending state; a button that does nothing for 300 ms reads as broken.
- `TweenService` for property animation; keep tweens short (0.15–0.3 s for UI) and cancel the old tween before starting a new one on the same object.
- Sound on interaction, but respect a volume setting and never at full volume by default.
- Show the *reason* a thing failed ("Not enough coins"), not a generic error.

## 7. Accessibility

- Don't encode meaning in colour alone — pair with an icon or text (8% of male players have some colour vision deficiency).
- Contrast: light text on a mid-grey `Frame` with `BackgroundTransparency = 0.5` over a bright map is unreadable. Test over the worst background in your game.
- Offer a UI scale setting driven by a single `UIScale` per ScreenGui.
- Don't require fast, precise input for core progression; offer a hold-to-activate alternative to rapid clicking.
- Avoid full-screen flashing effects; if you have them, offer a toggle.
- Captions/subtitles for any spoken audio.

## 8. Localization

- `LocalizationService` + a localization table (`LocalizationTable` / the auto-translate pipeline in Creator Dashboard) rather than string concatenation in Lua.
- Use `Translator:FormatByKey(key, args)` with named parameters — word order differs between languages, so never build a sentence from fragments.
- Leave 30–50% extra width for translated strings; `TextScaled` + `AutomaticSize` save you here.
- Numbers, dates, and currency formatting differ by locale.
- `LocalizationService.RobloxLocaleId` (the player's Roblox language) vs `SystemLocaleId` (their device) — use the former.

## 9. UI review checklist

- [ ] Works at 16:9 desktop, 4:3, and a tall phone aspect
- [ ] Nothing under the top bar or the mobile controls
- [ ] `ResetOnSpawn = false` where the UI must persist
- [ ] Gamepad can reach and activate every control
- [ ] No authoritative decision made client-side
- [ ] All connections and tweens cleaned up when the UI closes
- [ ] Text scales and doesn't clip when tripled in length
- [ ] No per-frame rebuild of a list
