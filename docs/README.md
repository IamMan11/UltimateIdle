# UltimateIdle — เอกสารระบบ

Idle RPG: ทีม hero ตี monster เองตาม timeline ที่ server จำลอง · ผู้เล่นอัพเกรด/ใส่ของ · สถานะ: เฟส 0–6 ใน plan.md เสร็จ · เฟส 7 เสร็จยกเว้น 7.3 balance (รอข้อมูลเล่นจริง) · leaderboard + raid/challenge/event/boss map ยังไม่ทำ (เจ้าของสั่งข้าม)

เอกสารแยกตามระบบ อ่านเฉพาะอันที่เกี่ยว · ทุกแถวบอกว่า code อยู่ที่ไหน (path ต้องมีจริง)

| ระบบ | อ่านที่ | code อยู่ที่ |
|---|---|---|
| **สเปกเกม + สถาปัตยกรรม** | [design.md](./design.md) | — |
| **ขั้นตอนการทำ + วิธีทำงานต่อขั้น** | [plan.md](./plan.md) | — |
| ข้อมูลผู้เล่น: โหลด/เซฟผ่าน ProfileStore, `PlayerData.Data(player)`, migrate ตาม `SchemaVersion`, hook `OnLoaded/OnReleasing` | — (ดู CLAUDE.md § Player data) | `src/server/Data/PlayerData.luau` |
| Remote ทั้งหมด (Red) + ตัวตรวจรูปแบบ | — | `src/shared/Net.luau` · rate limit `src/server/Util/RateLimit.luau` |
| Sync state → client: snapshot เมื่อ client ขอ + delta รวมต่อเฟรม, notice (toast) | — | `src/server/Systems/Replication/` · ฝั่ง client `src/client/State/` |
| เงิน Gold/Ruby: `Add/Spend/Has` (ทุกครั้งส่ง `source` = key ใน `Config/Analytics.TransactionTypes`) | — | `src/server/Systems/Currency/` |
| Analytics: economy รวมชุดส่งทุก `FlushSeconds` + ตอนออก · progression ทุก 10 level · onboarding funnel (tutorial) · custom (Rebirth, Code_*, TutorialSkipped) · **log ผิดปกติ** `[Anomaly]` (gold/ruby เร็วเกิน, gold ก้อนใหญ่, gold จาก trade, rate limit บ่อย) | — | `src/server/Systems/Analytics/` · เกณฑ์ `src/shared/Config/Analytics.luau` · hook `RateLimit.OnTrip` |
| ดูด่านคนอื่น: client ส่ง `WatchLane(userId)` → server ส่ง timeline ปัจจุบัน + level ถัดไปของคนนั้นให้เฉพาะคนที่ดู (`LaneTimeline`) · คลิกฉาก = สลับ 2D/3D · ปุ่ม Watch บน HUD วนทีละคน | design §6 §8 | `src/server/Systems/Spectate/` · client `src/client/Battle/` (`Playback.luau` = เล่น 1 ด่าน) |
| Tutorial 5 ขั้น (ผ่านด้วย event ฝั่ง server, รางวัลครั้งเดียวต่อบัญชี `Rewarded`, ข้าม/เล่นใหม่) · banner บน HUD + ไฮไลต์ปุ่มหน้า | — | `src/server/Systems/Tutorial/` · `Config/Tutorial.luau` · ข้อความ `Text.Tutorial` |
| รางวัลรายวัน 7 วัน (UTC, ขาดวัน = เริ่มวัน 1) `ClaimDaily` | — | `src/server/Systems/Daily/` · `Config/Daily.luau` · หน้า `src/client/UI/Daily/` |
| โค้ด `RedeemCode` (ใช้ได้ครั้งเดียวต่อบัญชี, หมดอายุได้) — รายการโค้ดอยู่ฝั่ง server เท่านั้น | — | `src/server/Systems/Codes/` · `src/server/Secret/Codes.luau` · ช่องกรอกในหน้า Settings |
| มือถือ/ขนาดจอ: `UIScale` เดียวจาก viewport × `Settings.UiScale` · HUD แบบ grid (compact) · ปิด thumbstick ตอนดูด่าน · จำนวน monster ที่วาดต่อด่าน (`Config/World.MaxMonsters*`, `LowDetail`) | — | `src/client/UI/Core/Device.luau` · `App.luau` · `HUD.luau` · `src/client/Battle/` |
| Hero: เลือกตัวแรก, ซื้อ, xp/level, ใส่/ถอดของ (wear cap), จัดทีม/แถว (`SetTeam`), เปลี่ยนอาชีพ (`Advance`), stat cache | design §3 §4 §6 | `src/server/Systems/Hero/` · สูตร `src/shared/Formula/` · config `Config/Classes.luau` `Config/Formation.luau` |
| สกิล hero: ติดตัว 1 + ใช้เอง 2 ต่อ class ใช้อัตโนมัติใน sim, event `Skill` ใน timeline | design §6 | `src/shared/Config/Skills.luau` · `src/shared/Formula/Skills.luau` · `Sim.luau` |
| Skill tree (ซื้อ/เปิดปิด node) + โบนัส level ส่วนตัว → modifier ก้อนเดียว (cache) | design §6 | `src/server/Systems/SkillTree/` · `src/server/Systems/Modifiers/` · `src/shared/Formula/Mods.luau` · config `Config/SkillTree.luau` `Config/Account.luau` |
| Level ส่วนตัว (cap ต่อ rebirth, ตารางปลด Farm/trade) | design §6 | `src/server/Systems/Account/` · `src/shared/Config/Account.luau` |
| Rebirth: กด rebirth (ไม่ reset, ให้แต้ม+ของ, level ใหม่เริ่มที่ level เดิม) · เลือก rebirth ที่เล่น (`SetPlayRebirth`) · แต้ม · cap/ความยาก/โบนัสต่อขั้น | design §6 | `src/server/Systems/Rebirth/` · `src/shared/Config/Rebirth.luau` · API ด่าน `Stage.SetPlayRebirth/SeedRebirth` |
| เสริมพลัง: ตีบวก (`Enhance`) · ช่องเสริม (`MergeSocket` `UseSocketCore` `SetSocketKind` `InsertSocket` `RemoveInsert`) · enchant (`Enchant`) · แก้ของผ่าน `Inventory.SetPlus/AddSocket/SetSocket/SetEnchants` | design §5 | `src/server/Systems/Enhance/` `Socket/` `Enchant/` · ราคา `src/shared/Formula/Forge.luau` · ผลต่อ stat `src/shared/Formula/Gear.luau` · config `Config/Enhance.luau` `Config/Inserts.luau` `Config/Enchant.luau` · อัตรา `Secret/EnhanceRates.luau` `Secret/EnchantPools.luau` |
| Trade: ขอ/รับ → ข้อเสนอ (ของล็อกใน Inventory, กล่องจองใน Box) → Ready ทั้งคู่ → Confirm หลังหน่วง (แก้ข้อเสนอ = ล้างทั้งคู่) → ตรวจซ้ำ → สลับไม่มี yield (ของได้ uid ใหม่) → log `[Trade]` · ข้อเสนอฝั่งละ ≤ `MaxSlots` ช่อง (gear + ชนิดวัตถุดิบ + ชนิดกล่อง = grid 3×3) · ต้องถึง level ส่วนตัว + PolicyService | design §6 | `src/server/Systems/Trade/` · ค่าคงที่ `Config/Trade.luau` · lock/โอนของ `Inventory.SetLocks/TakeForTrade/Adopt` · จองกล่อง `Box.SetReserved/Take` · หน้า `src/client/UI/Trade/` |
| Robux + ร้าน: x2 gold/xp (`Shop.GoldMult/XpMult` ใช้ทั้งออนไลน์และ offline) · ซื้อ/gift gamepass · premium pass · `ProcessReceipt` ตัวเดียวของเกม (dedupe `Purchases.Receipts` + รอเซฟ) · ร้านรายเดือน (โควตาต่อเดือน UTC) | design §6 | `src/server/Systems/Shop/` · ID/ราคา/ของ `Config/Shop.luau` · ราคา gold ตามด่าน `Formula/Economy.luau` · ข้อความโปรไฟล์ `PlayerData.MessageAsync/OnMessage` · หน้า `src/client/UI/Shop/` |
| Quest รายวัน/สัปดาห์/เดือน: `Quest.Progress(player, kind, n)` จาก Stage/Enhance/Enchant/Box · รีเซ็ตตามรอบ UTC เมื่อถูกแตะ · `ClaimQuest(id)` ให้ Ruby + แต้ม pass (id = ชื่อรอบ `Daily`/`Weekly`/`Monthly` = รับทุกอันที่เสร็จในรอบนั้น) | design §6 | `src/server/Systems/Quest/` · `Config/Quests.luau` · รอบเวลา `src/shared/Period.luau` · หน้า `src/client/UI/Quests/` |
| Battle pass: ฤดู = เดือน UTC · แต้มจาก quest (`Quest.OnClaimed`) · สายฟรี/พรีเมียม `ClaimPass` (tier 0 = รับทั้งหมด) · รางวัลผ่าน `Rewards` | design §6 | `src/server/Systems/BattlePass/` · `Config/BattlePass.luau` · แปลงรางวัล `src/server/Systems/Rewards/` · หน้า `src/client/UI/BattlePass/` |
| ด่าน: sim ล้วน (timeline buffer) → ส่ง client → จ่ายเมื่อจบ · Progress/Farm | design §2 | `src/server/Systems/Stage/` (`Sim.luau`) · codec `src/shared/Timeline.luau` · config `src/shared/Config/Stages.luau` |
| Lobby สร้างด้วยโค้ด (server), จองช่องด่านต่อผู้เล่น (attribute `Lane`) · ด่านอยู่ไกลจาก lobby (`World.LaneOrigins`, Z −6000) ไม่มี part ฝั่ง server | design §8 | `src/server/Systems/World/` · ตำแหน่ง `src/shared/Config/World.luau` |
| เล่น timeline ฝั่ง client (pool rig R6 เรียบ, ด่านตัวเอง + ด่านที่ดูอยู่), กล้อง lane 2D/3D / เดิน · ฉาก (พื้น ทางเดิน backdrop การ์ด 2D prop 3D) สร้างฝั่ง client `Scenery.luau` ค่าใน `Config/Scenery.luau` · โหมด lane = avatar ถูก freeze, โหมดเดิน = ฉาก+unit ถูกถอดจาก Workspace | design §8 | `src/client/Battle/` |
| กระเป๋า (Gear/Stacks, ความจุ 500 ไม่นับที่ใส่) | design §4 | `src/server/Systems/Inventory/` |
| Drop/กล่อง/ก้อน Farm/salvage · เปิดกล่องอัตโนมัติ (timer ต่อผู้เล่น) | design §4 | `src/server/Systems/Loot/` · `src/server/Systems/Box/` · อัตรา `src/server/Secret/` |
| Tag + ค้นหา `@tag` | design §4 | `src/shared/Tags.luau` |
| Offline 20% + AFK rejoin | design §6 | `src/server/Systems/Offline/` · client `src/client/Afk.luau` |
| ตั้งค่า (auto-salvage, skip wave, เปิดกล่องอัตโนมัติ, ขนาด UI, low detail) | — | `src/server/Systems/Settings/` |
| คำสั่ง dev (Studio เท่านั้น): gold xp level box gear mats points ruby quest passpts pass receipt | — | `src/server/Systems/Dev/` · ปุ่ม `src/client/UI/Dev/` |
| UI: HUD, หน้าต่าง Team แบบลอย ลาก/ปรับขนาด/จำตำแหน่งได้ (ซ้าย: preview class + แถบ class + ช่องของ 10 ช่อง · กลาง: level path/สกิล/เปลี่ยนอาชีพ หรือ picker ของ · ขวา: preview ทีม + ช่องแถว)/Skill Tree/Inventory แบบลอย (ซ้าย: grid ช่องกระเป๋า 8×7 แบ่งหน้า + search/filter · ขวา: แท็บ Sockets รวมของ / Enhance / Power = enchant)/Boxes (เปิดจากกล่องใน Inventory → More)/Rebirth/Quests/Battle Pass/Gamepass shop (แท็บ Gamepass + ช่อง potion placeholder / Monthly shop / Gift)/Trade/Daily/Settings (ค้นหา + กลุ่ม)/Codes, เลือก hero ตัวแรก | — (ดู CLAUDE.md § UI theme) | `src/client/UI/` |
| **สไตล์ภาพ (โมเดล + VFX)** — อ่านก่อนทำ asset ใหม่ทุกครั้ง | [art-style.md](./art-style.md) | — |
| อาการพัง → ไฟล์เจ้าของ | [debug-map.md](./debug-map.md) | — |
| ความจำข้าม session | [STATE.md](./STATE.md) | — |

## โครงสร้างโฟลเดอร์ (`src/`)

ไฟล์ใหญ่แตกเป็นโฟลเดอร์ที่มี `init.luau` · บรรทัดแรกของทุกไฟล์บอกว่าไฟล์นั้นทำอะไร

```
src/shared/      (ReplicatedStorage.Shared)   Net · Types · Format · Freeze · Tags · Timeline · Period · Config/ · Formula/ · Text/ (Economy = ข้อความเฟส 6)
src/server/      (ServerScriptService.Server) Data/ · Util/ (RateLimit Guard Rng) · Secret/ · Systems/
src/client/      (StarterPlayer.StarterPlayerScripts.Client)  State/ · Battle/ · UI/ (Core/ + 1 โฟลเดอร์ต่อหน้า) · Afk
```

## กติกาของเอกสาร

- 1 ระบบ = 1 ไฟล์ · บอก "อะไรมีอยู่ อยู่ที่ไหน ทำงานยังไง" ไม่ใช่ประวัติการแก้ (อันนั้นไป STATE.md)
- ตัวเลขเกมอยู่ใน `src/shared/Config/` — เอกสารอ้างชื่อ config ไม่ copy ตัวเลขมา (จะเก่า)
- แก้โค้ดแล้วพฤติกรรมเปลี่ยน → แก้เอกสารระบบนั้นใน commit เดียวกัน
