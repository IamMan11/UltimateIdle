# Genre Blueprints

Each blueprint lists the systems, the authority split, and the failure modes that specifically bite that genre. Use them as a starting architecture, not a template to copy.

## Round-based / PvP arena

**Systems**: match state machine, team assignment, spawn management, scoring, combat, spectator, intermission shop.

**State machine** (server-owned, one place):

```
Waiting (< minPlayers) → Intermission (countdown) → Loading (teleport/reset)
  → Playing (win condition polled or event-driven) → Ending (results, 5s) → Waiting
```

Drive it with one `phase` value, an `endsAt` timestamp, and a signal; replicate `phase` + `endsAt` as attributes and let each client render its own countdown. Never replicate a per-second tick.

**Authority**: server owns phase, score, damage, spawn position, and the win check. Client owns UI, hit effects, and camera.

**Failure modes**: players joining mid-round with no state (send a full snapshot on join); a phase transition that assumes players still exist; the round never ending because the win condition can't be met when everyone leaves (add a timeout and a "not enough players" abort); rewards granted twice because the end-of-round handler ran on both a timer and an event.

## Simulator (click/collect → upgrade → prestige)

**Systems**: currency, per-click/passive income, upgrade tree, pets/multipliers, zones with gates, rebirth, leaderboards, gamepass multipliers.

**Core loop math matters more than the code**: define income(t), cost(n) for upgrade n, and the intended time-to-next-upgrade curve in a spreadsheet before writing anything. Exponential costs with exponential income is what keeps the loop alive.

**Authority**: the server owns the currency and applies income; the client sends "I clicked" at a rate-limited cap. Client-side displayed currency is a *prediction* reconciled from the server.

**Failure modes**: numbers exceeding float precision (past ~2^53 integers lose precision — use a big-number representation with mantissa+exponent and format for display); currency inflation from an unguarded multiplier stack; save size growing with an unbounded pet inventory; click remotes as the top exploit target (rate-limit hard, and validate per-click gain server-side).

## Tycoon

**Systems**: plot assignment, purchasable buttons, dropper→conveyor→collector chain, plot persistence, plot reset on leave.

**Authority**: server owns the plot and what is built. Store owned-button ids on the profile; on join, assign a free plot and rebuild from the saved id list. Never persist Instances.

**Failure modes**: dropper parts accumulating without a cap (cap per plot and `Debris` them); plots not released when a player leaves; two players assigned the same plot on a race; the whole plot streamed away from a nearby player (`ModelStreamingMode = Atomic` or `PersistentPerPlayer`).

Performance: droppers are the classic instance-churn disaster. Pool the parts, cap concurrent drops, and consider simulating income abstractly while only *showing* a few parts.

## Obby / platformer

**Systems**: checkpoints, stage progression, kill bricks, moving platforms, skip-stage product, per-stage leaderboard.

**Authority**: server owns the current stage and respawns the player at it. A client that teleports past stages must not be credited — validate that the player actually touched the checkpoint server-side, and consider a "must have visited stage n-1" rule.

**Failure modes**: `Touched` missing at high speed (use a region check or a larger trigger); moving platforms fighting network ownership (anchor and move by CFrame, or set ownership deliberately); respawn placing the player inside geometry; checkpoint spam from a player standing on the trigger (debounce per player per checkpoint).

## RPG / progression

**Systems**: stats, inventory + equipment, quests, dialogue, loot tables, enemies, skill trees, parties.

**Data**: this is the genre where profile size and migrations matter most. Store item ids + counts + a small property table, not full item definitions (those live in `shared/config`). Version the schema from day one.

**Authority**: everything that changes a stat, drops loot, or completes a quest is server-side. Loot tables live in `ServerStorage`.

**Failure modes**: item duplication across a trade or a server hop (do trades as an atomic server-side swap with both profiles session-locked, and never via two independent grants); quest state desync between UI and server; unbounded inventory; a skill tree whose respec refunds more than it cost.

## Horror / co-op survival

**Systems**: AI stalker, sanity/stamina, flashlight and darkness, objective chain, doors/keys, jumpscares, proximity voice or chat.

**Authority**: the monster's position and attacks are server-owned — a client that knows where the monster is can wallhack, so consider only replicating the monster when it should be perceivable (streaming, or a server-controlled "visible" state), and drive audio cues from the server.

**Failure modes**: the whole map loaded and readable from the client (map knowledge is the genre's main exploit); framerate collapse from many dynamic lights and shadows; AI pathfinding recomputed every frame; jump scares that break on low-end devices because the asset wasn't preloaded.

## Racing / vehicles

**Systems**: vehicle physics, checkpoints and lap counting, countdown, position ranking, respawn, track selection.

**Authority**: the driving client owns the vehicle's physics (network ownership) for feel — so lap times and checkpoint order must be validated server-side (sequential checkpoints, minimum plausible lap time, position sampling).

**Failure modes**: teleport-to-finish exploits (enforce checkpoint order and a min lap time); vehicles exploding on spawn from overlapping parts; ownership not transferred on driver change; `VehicleSeat` behaviour differing between server and owning client.

## Tower defense / wave

**Systems**: wave scheduler, path, tower placement grid, targeting, projectiles, economy, upgrade.

**Authority**: server owns enemy positions, health, tower placement legality, and damage. Clients render smoothly by interpolating between server updates rather than receiving per-frame positions.

**Failure modes**: N towers × M enemies distance checks every frame (partition the grid; tower targeting only needs to re-evaluate a few times per second); one projectile Instance per shot (pool, or don't create an Instance at all — resolve the hit instantly server-side and play a client-side visual); placement validated only on the client.

## UGC-heavy / social (building, roleplay, hangout)

**Systems**: building/placement, saving player creations, text/name input, moderation, plot ownership, visiting.

**Authority + compliance**: every piece of player-authored text goes through `FilterStringAsync` (see `security.md`). Player-built structures must be validated server-side for bounds, part count, and material legality — an unbounded builder is a server-crash vector.

**Failure modes**: saving Instances instead of a compact description; part-count explosions; players building inside each other's plots; offensive builds with no report/moderation path; save size exceeding the 4 MB key limit.

## Cross-genre defaults

Whatever the genre, these exist in every shipped game: a data/profile service, a currency service with a single authoritative balance, a remote layer with validation and rate limits, an analytics layer, a settings menu (audio, UI scale, graphics hints), a mobile-usable control scheme, and a way to see what's going wrong in production.
