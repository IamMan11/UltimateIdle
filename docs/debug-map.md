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
| ไม่มีอะไรเล่นในด่าน / ด่านไม่เริ่ม | team ว่าง (`Hero.GetTeam`) · `server/Systems/Stage/init.luau` startLevel · client `Battle/init.luau` (attribute `Lane`) | — |
| ด่านแพ้ timeout 180 วิ ทั้งที่ไม่ตาย | `Sim.luau` ระยะตี (`MELEE_SLACK`) กับ Range ของ monster | `shared/Config/Monsters.luau` |
| Toast/notice ไม่ขึ้นตอนเข้าเกม | `Replication.Notify` คิวก่อน snapshot | — |
| สกิล hero ไม่ออก / ไม่ขึ้นชื่อสกิลบนหัว | `shared/Formula/Skills.luau` (level ปลด) · `Sim.luau` `tryCast` (เงื่อนไขต่อ kind) · client `Battle/init.luau` `Code.Skill` → `Rig.Flash` | `shared/Config/Skills.luau` |
| โบนัส skill tree / level ส่วนตัวไม่มีผล | `shared/Formula/Mods.luau` · cache `server/Systems/Modifiers/` (เจ้าของ input ต้องเรียก `MarkDirty`) | `shared/Config/SkillTree.luau` · `Config/Account.luau` |
| เปิดกล่องอัตโนมัติไม่ทำงาน | `Box.Refresh` (ต้องปลด node + `Settings.AutoOpenBoxes` + มีที่ว่าง) | `server/Systems/Box/init.luau` |
| ของสวมไม่ได้ทั้งที่ level ถึง | wear cap: `Config/Rebirth.luau` `WearCaps` ตาม `Advancement` | `Hero.WearCap` |
| ของไม่ drop / ถูกย่อยหมด | `Settings.AutoSalvage` · ความจุ `Inventory.FreeSpace` · `server/Secret/DropTables.luau` | — |
| แก้/ใส่/ย่อยของไม่ได้ "That item is in an open trade" | lock ค้าง: `Inventory.SetLocks` ล้างตอนจบ trade (`Trade` `release`) | `server/Systems/Trade/init.luau` |
| Trade ยืนยันไม่ได้ / ขึ้น TradePolicy | `ConfirmAt` (หน่วงหลังแก้ข้อเสนอ) · PolicyService cache `policy[player]` · `Config/Account.luau` Unlocks.Trade | `Config/Trade.luau` |
| ซื้อ Robux แล้วไม่ได้ของ / ได้ซ้ำ | `server/Systems/Shop/init.luau` `handleReceipt` (`Purchases.Receipts`, `PlayerData.WaitSaved`) · product id ใน `Config/Shop.luau` | `references/monetization-and-liveops.md` |
| x2 gold/xp ไม่มีผล | `Shop.Owns` (account cache + `Purchases.Owned`) · Stage `finishLevel` / `Offline.payOffline` | `Config/Shop.luau` PassId |
| Quest/pass ไม่ขยับ หรือรีเซ็ตผิดเวลา | ผู้เรียก `Quest.Progress` (Stage/Enhance/Enchant/Box) · `shared/Period.luau` (UTC) | `Config/Quests.luau` CapByPeriod |
| ดูด่านคนอื่นไม่ขึ้น / ค้างภาพเก่า | server `server/Systems/Spectate/` (`watching`, `latest`, `Spectate.Publish` จาก Stage) · client `State.SetWatch` → `Net.LaneTimeline` → `client/Battle/init.luau` `playWatched` | `client/Battle/Playback.luau` |
| คลิกด่านแล้วไม่สลับมุม/ไม่ดูคนนั้น | `client/Battle/init.luau` `laneAt` (raycast เฉพาะ `Workspace.Arena`, ชื่อ `LaneN`) · กดค้าง/ลาก = ไม่นับคลิก (`CLICK_SECONDS/PIXELS`) | `Battle/Camera.luau` |
| `[Anomaly]` ใน log | `server/Systems/Analytics/` (`checkEarn`, `onTrip`) · เกณฑ์ `shared/Config/Analytics.luau` · ที่มาเงิน = arg `source` ของ `Currency.Add/Spend` | — |
| UI ใหญ่/เล็กผิด, ปุ่มทับกันบนมือถือ | `client/UI/Core/Device.luau` (`Scale/Compact/Tight`) · `UIScale` ใน `App.luau` · `Settings.UiScale` | `HUD.luau` (compact grid, `touchWalk`) |
| Tutorial ไม่ขยับ | step ปัจจุบัน `Config/Tutorial.luau` `Event` · ผู้แจ้ง `Tutorial.Event` (Hero equip, SkillTree buy) / `Quest.OnProgress` (ClearLevel, OpenBox, Enhance) | `server/Systems/Tutorial/` |
| รางวัลรายวัน/โค้ด ไม่ได้ | `server/Systems/Daily/` (`Daily.Day` = Period key UTC) · `server/Systems/Codes/` + `server/Secret/Codes.luau` (key ตัวใหญ่ไม่มีช่องว่าง) · กล่องเต็ม = `Rewards.CanGrant` | — |
