# World, Characters, Animation, Audio & Environment

## 1. Parts and CFrame

- `CFrame` = position + rotation. `part.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)`. Order matters: `A * B` applies B in A's local space.
- `CFrame.lookAt(from, to)`, `cf:ToWorldSpace(offset)`, `cf:ToObjectSpace(other)`, `cf:PointToObjectSpace(v3)` — learn these four and most positioning problems disappear.
- Moving a **model**: `model:PivotTo(cframe)` (and `model:GetPivot()`), never a loop over its parts.
- Setting `.Position` on a welded part breaks the weld's intent; move the root and let constraints follow.
- `part.Massless`, `part.CustomPhysicalProperties`, `AssemblyLinearVelocity` for physics tuning.

## 2. Physics and constraints

Legacy `BodyVelocity`/`BodyPosition`/`BodyGyro` are deprecated. Use constraints:

| Want | Use |
| --- | --- |
| Move at a velocity | `LinearVelocity` |
| Move to a position | `AlignPosition` (set `Mode`, `MaxForce`, `Responsiveness`) |
| Face a direction | `AlignOrientation` |
| Rotate at a rate | `AngularVelocity` |
| Attach rigidly | `WeldConstraint` (or `Motor6D` for animated joints) |
| Rope/spring/rod | `RopeConstraint`, `SpringConstraint`, `RodConstraint` |
| Vehicles | `VehicleSeat` + `CylindricalConstraint`/`HingeConstraint` |

Constraints need `Attachment`s. Collision groups (`PhysicsService:RegisterCollisionGroup(name)`, `PhysicsService:CollisionGroupSetCollidable(a, b, false)`, `part.CollisionGroup = name`) are how you stop players colliding with each other, projectiles hitting their owner, and NPCs shoving the map.

Raycasting:

```lua
local params = RaycastParams.new()
params.FilterDescendantsInstances = { character }
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.CollisionGroup = "Projectiles"

local result = workspace:Raycast(origin, direction * 500, params)
if result then
	-- result.Instance, result.Position, result.Normal, result.Material, result.Distance
end
```

Also: `workspace:Blockcast` / `Spherecast` / `Shapecast` for volume sweeps, `GetPartBoundsInRadius`/`InBox`/`GetPartsInPart` with `OverlapParams` for area queries. Prefer these to `Touched` for hit detection — `Touched` misses fast-moving parts and fires excessively for slow ones.

## 3. Characters

- `Players.CharacterAutoLoads`, `player:LoadCharacter()`, `player.CharacterAdded` / `CharacterRemoving`, `player.CharacterAppearanceLoaded`.
- Always guard: `local char = player.Character or player.CharacterAdded:Wait()`, then `char:WaitForChild("Humanoid")`.
- `Humanoid` properties you will touch: `WalkSpeed`, `JumpPower`/`JumpHeight` (depends on `UseJumpPower`), `MaxHealth`/`Health`, `HipHeight`, `PlatformStand`, `AutoRotate`, `Sit`.
- `Humanoid.Died`, `HealthChanged`, `StateChanged`, `Humanoid:GetState()`, `SetStateEnabled` (e.g. disable `FallingDown`/`Ragdoll` states you don't want).
- **Damage is server-side.** `Humanoid:TakeDamage(n)` on the server; the client only plays the hit effect.
- R15 vs R6 changes rig structure and animation compatibility. Decide per experience in game settings; don't assume limb names.
- Custom character controllers (replacing `Humanoid` movement with your own physics) give precise feel but you take on collision, stairs, slopes, and animation state yourself. Worth it for platformers and racing; overkill otherwise.
- `StarterCharacterScripts` for per-life scripts; `StarterPlayerScripts` for scripts that must survive death.
- Appearance: `Players:GetHumanoidDescriptionFromUserId`, `humanoid:ApplyDescription(desc)` for custom looks; `HumanoidDescription` is also how you make NPCs look like avatars.

## 4. Animation

- Author in the Studio Animation Editor or import FBX; publish to get an asset id.
- **Load through `Animator`, never `Humanoid:LoadAnimation`** (deprecated):

```lua
local animator = humanoid:FindFirstChildOfClass("Animator")
local track = animator:LoadAnimation(animationInstance)
track.Priority = Enum.AnimationPriority.Action
track.Looped = false
track:Play(0.1)                 -- fade time
track:AdjustSpeed(1.2)
track:GetMarkerReachedSignal("Hit"):Connect(onHit)
track.Stopped:Wait()
```

- Priority order: `Core` < `Idle` < `Movement` < `Action` < `Action2..4`. A too-low priority is why "my animation doesn't play" — the default walk overrides it.
- Animation **markers** (keyframe markers) are the correct way to sync gameplay (damage frame, footstep, VFX) to animation, rather than `task.wait(0.35)`.
- Load tracks once and reuse; loading per swing leaks and stutters. There is a cap on simultaneously loaded tracks per Animator — reuse rather than accumulate.
- Animations play on the client that owns the character and replicate; play them on the client for responsiveness, but never let the client's animation decide damage.
- Third-party animations must be owned by the same creator/group as the experience to load.

## 5. NPCs and pathfinding

```lua
local PathfindingService = game:GetService("PathfindingService")
local path = PathfindingService:CreatePath({
	AgentRadius = 2, AgentHeight = 5, AgentCanJump = true,
	Costs = { Water = 20, Danger = math.huge },
})
local ok = pcall(function() path:ComputeAsync(startPos, targetPos) end)
if ok and path.Status == Enum.PathStatus.Success then
	for _, waypoint in path:GetWaypoints() do
		if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
		humanoid:MoveTo(waypoint.Position)
		humanoid.MoveToFinished:Wait()
	end
end
path.Blocked:Connect(recompute)
```

- `ComputeAsync` yields and is not free — throttle recomputation (every 0.5–1 s, or on `Blocked`), and stagger NPCs so they don't all recompute on the same frame.
- Use `PathfindingModifier` + `Costs` to steer NPCs away from hazards.
- For many NPCs, time-slice updates (see `performance.md`) and use a simple state machine per NPC (`Idle`/`Patrol`/`Chase`/`Attack`) rather than per-frame decision trees.
- NPC logic runs on the **server**. Anchor or set network ownership to `nil` for NPC parts so clients can't push them around.

## 6. Audio

- Classic API: `Sound` parented to a part (3D positional) or to `SoundService`/`PlayerGui` (2D). `SoundGroup` for bus mixing and a master volume setting. `Sound.RollOffMode`/`RollOffMinDistance`/`MaxDistance` for falloff.
- Preload with `ContentProvider:PreloadAsync({sound})` for sounds that must not be late.
- Newer audio API (`AudioPlayer`, `AudioEmitter`, `AudioListener`, `AudioFader`, `AudioDeviceOutput`, wired with `Wire` instances) enables real routing, effects chains, and per-listener mixing. Use it when you need mixing graphs; the classic `Sound` API remains fine for simple playback.
- Play SFX on the **client** for responsiveness (a remote or a replicated attribute triggers it); play only genuinely shared, positional world audio from the server.
- Respect a player volume setting; never start music at volume 1.
- Audio assets must be owned/licensed by you; check the audio privacy rules for long uploads.
- `TextChatService` and voice chat are covered in `security.md`.

## 7. Lighting and atmosphere

- `Lighting.Technology`: `Future` (best quality, most expensive), `ShadowMap`, `Voxel`, `Legacy`. Pick per performance target and test on mobile.
- `Atmosphere`, `Sky`, `Clouds` (`workspace.Terrain.Clouds`), and post-processing (`BloomEffect`, `ColorCorrectionEffect`, `SunRaysEffect`, `DepthOfFieldEffect`, `BlurEffect`) are the mood toolkit.
- `Lighting.ClockTime`/`TimeOfDay`, `GeographicLatitude`, `Ambient`/`OutdoorAmbient`, `Brightness`, `ExposureCompensation`.
- Tween `ColorCorrection` and `Atmosphere` for day/night and event moods; do it on the client so each player can have a different state where gameplay allows.
- `Highlight` for outlining objects (cheap, replaces old SelectionBox hacks) — but cap the number active at once.
- Light sources (`PointLight`, `SpotLight`, `SurfaceLight`) with shadows are expensive; limit count and `Shadows = false` for decorative ones.

## 8. VFX

- `ParticleEmitter` (`Rate`, `Lifetime`, `Speed`, `Transparency`/`Size` as `NumberSequence`s) — emit bursts with `:Emit(n)` rather than toggling `Enabled`.
- `Beam` and `Trail` for projectiles, links, and motion.
- Play VFX on the client. The server tells clients "an explosion happened at X"; each client spawns its own particles. Never replicate particle instances per hit.
- Pool and reuse emitter parts.

## 9. Terrain

- `workspace.Terrain:FillBlock/FillBall/FillRegion`, `ReplaceMaterial`, `SetMaterialColor`, `ReadVoxels`/`WriteVoxels` for procedural generation.
- Terrain is memory-heavy and streams; generate in chunks and time-slice.
- `Terrain.WaterWaveSize`/`WaterColor` etc. for water look; water affects raycasts unless `IgnoreWater`.

## 10. Assets and the content pipeline

- `rbxassetid://` for uploaded assets; `AssetService` for runtime asset operations, `ContentProvider:PreloadAsync` for pre-caching (call it on a splash screen, not mid-gameplay — it yields).
- `AssetService:CreateEditableImage` / `CreateEditableMesh` for runtime-generated visuals (with memory budgets — check current limits).
- Packages (right-click → Convert to Package) version a model across places.
- Keep source art out of the place file; the Rojo project holds code, Studio holds the map, unless you commit `.rbxmx` model files deliberately.
- Moderation: uploaded images/audio/meshes are reviewed; plan for a delay and a rejection path.
