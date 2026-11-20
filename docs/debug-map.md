# Debug map — อาการ → ไฟล์เจ้าของ

เริ่มที่เจ้าของ state ไม่ใช่หน้าจอที่เห็นอาการ · path ใต้ `src/` · เพิ่มแถวทุกครั้งที่หาสาเหตุเจอ (session ถัดไปจะเริ่มถูกที่)
อ่านโดย `.claude/skills/roblox-game-dev/SKILL.md` §2.5

| อาการ | ดูก่อน | แล้วค่อย |
|---|---|---|
| Data ไม่ save / รีเซ็ต | `server/Data/PlayerData.luau` (`PROFILE_TEMPLATE`, session ProfileStore) | ห้ามใช้ DataStoreService ตรง |
| Client event ถูกเมิน / error "bad …" | `shared/Net.luau` validator ของ event นั้น · handler ฝั่ง server | `.claude/skills/roblox-game-dev/references/networking.md` |
| UI window / modal เพี้ยน (layer, Esc, focus) | `client/UI/Core/` · state ใน client store | `.claude/skills/ui-modal/references/roblox-react.md` |
| ข้อความผิด / hard-code | `shared/Text/` เท่านั้น | — |
| ตัวเลขผิด | `shared/Config/` (สูตร/ค่า) | balance = แก้ค่าจริง ไม่ใช่ตัวคูณรวม |
| UI ไม่อัปเดตหลังซื้อ/ได้ของ | system เจ้าของเรียก `Replication.Set` ไหม · `client/State/init.luau` applyDelta | `server/Systems/Replication/` |
| level ไม่เดินหน้า / ค้าง level เดิมทั้งที่ชนะ | level ถูก pin: `data.Stage.ByRebirth[r].Pin` (ตั้งจากแผง level ใน HUD → `Net.SetStageLevel` → `server/Systems/Stage` `setLevel`; 0 = เลิก pin) · `startLevel` ใช้ `Pin or Level` · `finishLevel` ข้ามการขยับ Level เมื่อ `run.Pinned` | `client/UI/Core/LevelPanel.luau` |
| ปุ่ม HUD เปิดผิดหน้า/ผิดแท็บ | `client/UI/Core/HUD.luau` (`side` / `bottom`: `Id` = page, `Tab` = แท็บ) · `State.ToggleWindow` + `Ui.PageTabs[id]` (Quests, Shop อ่านแท็บจากตรงนี้) | Battle pass เป็นหน้าเดี่ยว `BattlePass` · Skill Tree เปิดจากหน้า Team เท่านั้น · Shop รายเดือน = แท็บในหน้า Gamepass |
| หน้าต่างซ้อนผิดลำดับ / คลิกแล้วไม่ขึ้นบน / Esc ปิดผิดอัน / ขนาด-ที่ไม่จำ | `State.Ui.Windows` (ล่าง → บน) + `OpenWindow/CloseWindow/ToggleWindow/RaiseWindow` · `App.luau` (ZIndex = ลำดับใน stack, InputBegan → `WindowStack.Hit`) · `Core/FloatWindow.luau` (Esc เฉพาะตัวบนสุดและไม่มี Confirm, `fit` = ย่อ/ขยายเนื้อหา layout ตายตัว) | ที่/ขนาดเซฟเฉพาะ id ใน `Config/Game.luau` `Windows` (server ปฏิเสธ id อื่น) |
| ไม่มีอะไรเล่นในด่าน / ด่านไม่เริ่ม | team ว่าง (`Hero.GetTeam`) · `server/Systems/Stage/init.luau` startLevel · client `Battle/init.luau` (attribute `Lane`) | — |
| ด่านแพ้ timeout 180 วิ ทั้งที่ไม่ตาย | `Sim.luau` ระยะตี (`MELEE_SLACK`) กับ Range ของ monster | `shared/Config/Monsters.luau` |
| Toast/notice ไม่ขึ้นตอนเข้าเกม | `Replication.Notify` คิวก่อน snapshot | — |
| สกิล hero ไม่ออก / ไม่ขึ้นชื่อสกิลบนหัว | `shared/Formula/Skills.luau` (level ปลด) · `Sim.luau` `tryCast` (เงื่อนไขต่อ kind) · client `Battle/init.luau` `Code.Skill` → `Rig.Flash` | `shared/Config/Skills.luau` |
| โบนัส skill tree / level ส่วนตัวไม่มีผล | `shared/Formula/Mods.luau` · cache `server/Systems/Modifiers/` (เจ้าของ input ต้องเรียก `MarkDirty`) | `shared/Config/SkillTree.luau` · `Config/Account.luau` |
| เปิดกล่องอัตโนมัติไม่ทำงาน | `Box.Refresh` (ต้องปลด node + `Settings.AutoOpenBoxes` + มีที่ว่าง) | `server/Systems/Box/init.luau` |
| ของสวมไม่ได้ทั้งที่ level ถึง | wear cap: `Config/Rebirth.luau` `WearCaps` ตาม `Advancement` | `Hero.WearCap` |
| ของไม่ drop / ถูกย่อยหมด | `Settings.AutoSalvageOn` + `AutoSalvage` (tier) + `SalvageItems` (base) → `Loot.Grant` · ความจุ `Inventory.FreeSpace` · `server/Secret/DropTables.luau` | — |
| แก้/ใส่/ย่อยของไม่ได้ "That item is in an open trade" | lock ค้าง: `Inventory.SetLocks` ล้างตอนจบ trade (`Trade` `release`) | `server/Systems/Trade/init.luau` |
| Trade ยืนยันไม่ได้ / ขึ้น TradePolicy | `ConfirmAt` (หน่วงหลังแก้ข้อเสนอ) · PolicyService cache `policy[player]` · `Config/Account.luau` Unlocks.Trade | `Config/Trade.luau` |
| ซื้อ Robux แล้วไม่ได้ของ / ได้ซ้ำ | `server/Systems/Shop/init.luau` `handleReceipt` (`Purchases.Receipts`, `PlayerData.WaitSaved`) · product id ใน `Config/Shop.luau` | `references/monetization-and-liveops.md` |
| x2 gold/xp ไม่มีผล | `Shop.Owns` (account cache + `Purchases.Owned`) · Stage `finishLevel` / `Offline.payOffline` | `Config/Shop.luau` PassId |
| Quest/pass ไม่ขยับ หรือรีเซ็ตผิดเวลา | ผู้เรียก `Quest.Progress` (Stage/Enhance/Enchant/Box) · `shared/Period.luau` (UTC) | `Config/Quests.luau` CapByPeriod |
| ดูด่านคนอื่นไม่ขึ้น / ค้างภาพเก่า | server `server/Systems/Spectate/` (`watching`, `latest`, `Spectate.Publish` จาก Stage) · client `State.SetWatch` → `Net.LaneTimeline` → `client/Battle/init.luau` `playWatched` | `client/Battle/Playback.luau` |
| คลิกฉากแล้วไม่สลับ 2D/3D | `client/Battle/init.luau` `onClick` (เฉพาะโหมด Lane, คลิกที่ไม่โดน UI) · กดค้าง/ลาก = ไม่นับคลิก (`CLICK_SECONDS/PIXELS`) | `Battle/Camera.luau` |
| ฉากไม่ขึ้น / เห็นฉากจาก lobby / avatar ยังเดินได้ตอนดูด่าน | `client/Battle/Camera.luau` `apply` (`onStage` → `Scenery.Show`, `Rig.SetVisible`, `setFrozen`) · attribute `Lane` | `client/Battle/Scenery.luau` · `shared/Config/Scenery.luau` · `Config/World.luau` `LaneOrigins` |
| `[Anomaly]` ใน log | `server/Systems/Analytics/` (`checkEarn`, `onTrip`) · เกณฑ์ `shared/Config/Analytics.luau` · ที่มาเงิน = arg `source` ของ `Currency.Add/Spend` | — |
| UI ใหญ่/เล็กผิด, ปุ่มทับกันบนมือถือ | `client/UI/Core/Device.luau` (`Scale/Compact/Tight`) · `UIScale` ใน `App.luau` · `Settings.UiScale` | `HUD.luau` (compact grid, `touchWalk`) |
| Tutorial ไม่ขยับ | step ปัจจุบัน `Config/Tutorial.luau` `Event` · ผู้แจ้ง `Tutorial.Event` (Hero equip, SkillTree buy) / `Quest.OnProgress` (ClearLevel, OpenBox, Enhance) | `server/Systems/Tutorial/` |
| รางวัลรายวัน/โค้ด ไม่ได้ | `server/Systems/Daily/` (`Daily.Day` = Period key UTC) · `server/Systems/Codes/` + `server/Secret/Codes.luau` (key ตัวใหญ่ไม่มีช่องว่าง) · กล่องเต็ม = `Rewards.CanGrant` | — |
| หน้าต่าง Team ลาก/ปรับขนาดไม่ได้ · ไม่จำตำแหน่ง · เปิดมาหลุดจอ | `client/UI/Core/FloatWindow.luau` (rect = สัดส่วนจอ, `begin` + effect ตอน `dragging`) · `State.SetWindow` → `Net.SetWindow` → `server/Systems/Settings` `setWindow` (id ต้องอยู่ใน `Config/Game.luau` `Windows`) · ค่าเก็บที่ `Settings.Windows` | ปุ่ม Reset window = `{0.5, 0.5, 0, 0}` |
| preview โมเดลในหน้า Team ว่าง / กล้องผิด | `client/UI/Core/ModelView.luau` (clone จาก `ReplicatedStorage.HeroModels.<class>`, เท้า = ล่างสุดของ part ที่มองเห็น, template หันหน้า −Z) | `UI/Team/HeroPanel.luau` · `Formation.luau` (`VIEW`, `FACE_LANE`) |
| Skill Tree เปิดไม่ขึ้น / node วางผิดที่ / กดแล้วไม่ซื้อ | `State.OpenWindow("Tree")` (id `Tree` ใน `Ui.Windows`) · `App.luau` `window()` · `client/UI/Tree/init.luau` (`DIRECTIONS` = ทิศของแต่ละ branch จาก Start, `click`) | ตำแหน่งในกิ่ง = `Row`/`Col` ใน `shared/Config/SkillTree.luau` |
| จำนวนช่องกระเป๋าผิด / ของไม่ drop เพราะ "เต็ม" ทั้งที่ gear น้อย | ช่อง = gear ที่ไม่ได้ใส่ + ช่องวัตถุดิบ + กอง box: `shared/Formula/Bag.luau` (`Used`, `MaxStack`) = `server/Systems/Inventory` `Count` · `MaxStack` ต่อชนิดใน `shared/Config/Materials.luau` · ตัวคูณ `Mods.StackPct` (effect `StackPct` ใน skill tree) | วัตถุดิบ/กล่องไม่เคยถูกปฏิเสธ เกิน capacity ได้ มีแต่ gear ที่เข้าไม่ได้ |
| ล็อกของ / salvage ไม่ไป / เมนูคลิกขวา | ล็อก = `GearItem.Locked` เขียนโดย `Inventory.SetGearLock` (remote `LockGear`) · salvage ข้ามของล็อก: `server/Systems/Loot` `salvage` · เมนู + โหมด Lock/Salvage + mark: state ใน `client/UI/Inventory/Grid.luau` (`menuKey` `mode` `marked`) | ชิ้น Use ของ merge: `Formula.Forge.CanMerge` ปฏิเสธของล็อก |
| เปลี่ยนอาชีพไม่ได้ / สายผิด / stat สายไม่ขึ้น | `server/Systems/Hero` `advance` (สายใช้เฉพาะขั้นแรก) · โบนัส: `shared/Config/Classes.luau` `Paths` → `Classes.Totals(adv, path)` → `Formula.Stats.Hero` / `Formula.Skills` | modal: `client/UI/Team/JobChange.luau` เปิดด้วย `State.OpenJobChange` · ชื่อ: `Text` ADVANCEMENT |
| หน้า Inventory: ของใน grid ผิด / กดของแล้วแท็บขวาไม่เปลี่ยน | `client/UI/Inventory/Entries.luau` (สร้างรายการต่อช่อง + filter) · `Grid.luau` · ชิ้นที่เลือก = `State.Ui.ForgeUid` (Keep), ชิ้น Use = state ใน `Inventory/init.luau` (`onGear`) · กรองของซ้ำ (ปุ่ม + ช่อง Use) = `finding` → prop `mergeFor` ของ Grid · Upgrade: ของในช่อง In = `upPicked` + `UpgradePick.luau`, กรอง = prop `insertsFor` | แท็บ: `SocketsTab` / `EnhanceTab` / `PowerTab` · `SocketRows.luau` |
| ตัวละคร/มอนเป็นบล็อกเทา · ลอย/จมพื้น · หันผิดทาง | `client/Battle/Rig.luau` `template` (ชื่อโฟลเดอร์ + ชื่อ model = Id) · `fromTemplate` (feet จาก part ที่มองเห็น, `PivotOffset`) | template ใน `ReplicatedStorage.HeroModels` / `MonsterModels` |
| ฉากยังเป็น placeholder / ชิ้นฉากหาย | `client/Battle/Scenery.luau` `build` → `fromKit` · ชื่อชิ้นใน `shared/Config/Scenery.luau` `Kit` | `ReplicatedStorage.StageKits.Meadow` |
| monster ไม่ขยับท่า / ท่าผิดจังหวะ / แขนขาหลุด | `client/Battle/Rig.luau` `animFor` (ชื่อข้อ = ชื่อ Part1 ของ Motor6D หรือชื่อ Bone) · `Rig.Animate` · `Playback.place` (ลำดับเลือก clip, `AttackAt/HurtAt/DiedAt`) | ข้อมูล `shared/Config/MonsterAnims.luau` (generated — แก้ที่ `anims/build_anims.py`) |
