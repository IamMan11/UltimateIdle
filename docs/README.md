# UltimateIdle — เอกสารระบบ

Idle RPG: ทีม hero ตี monster เองตาม timeline ที่ server จำลอง · ผู้เล่นอัพเกรด/ใส่ของ · สถานะ: เฟส 0–3 ใน plan.md เสร็จ (ฐาน, loop หลัก, ของ, ทีม)

เอกสารแยกตามระบบ อ่านเฉพาะอันที่เกี่ยว · ทุกแถวบอกว่า code อยู่ที่ไหน (path ต้องมีจริง)

| ระบบ | อ่านที่ | code อยู่ที่ |
|---|---|---|
| **สเปกเกม + สถาปัตยกรรม** | [design.md](./design.md) | — |
| **ขั้นตอนการทำ + วิธีทำงานต่อขั้น** | [plan.md](./plan.md) | — |
| ข้อมูลผู้เล่น: โหลด/เซฟผ่าน ProfileStore, `PlayerData.Data(player)`, migrate ตาม `SchemaVersion`, hook `OnLoaded/OnReleasing` | — (ดู CLAUDE.md § Player data) | `src/server/Data/PlayerData.luau` |
| Remote ทั้งหมด (Red) + ตัวตรวจรูปแบบ | — | `src/shared/Net.luau` · rate limit `src/server/Util/RateLimit.luau` |
| Sync state → client: snapshot เมื่อ client ขอ + delta รวมต่อเฟรม, notice (toast) | — | `src/server/Systems/Replication/` · ฝั่ง client `src/client/State/` |
| เงิน Gold/Ruby: `Add/Spend/Has` | — | `src/server/Systems/Currency/` |
| Hero: เลือกตัวแรก, ซื้อ, xp/level, ใส่/ถอดของ (wear cap), จัดทีม/แถว (`SetTeam`), เปลี่ยนอาชีพ (`Advance`), stat cache | design §3 §4 §6 | `src/server/Systems/Hero/` · สูตร `src/shared/Formula/` · config `Config/Classes.luau` `Config/Formation.luau` |
| สกิล hero: ติดตัว 1 + ใช้เอง 2 ต่อ class ใช้อัตโนมัติใน sim, event `Skill` ใน timeline | design §6 | `src/shared/Config/Skills.luau` · `src/shared/Formula/Skills.luau` · `Sim.luau` |
| Skill tree (ซื้อ/เปิดปิด node) + โบนัส level ส่วนตัว → modifier ก้อนเดียว (cache) | design §6 | `src/server/Systems/SkillTree/` · `src/server/Systems/Modifiers/` · `src/shared/Formula/Mods.luau` · config `Config/SkillTree.luau` `Config/Account.luau` |
| Level ส่วนตัว (cap ต่อ rebirth, ตารางปลด Farm/trade) | design §6 | `src/server/Systems/Account/` · `src/shared/Config/Account.luau` |
| แต้ม rebirth (เฟส 3 แค่ใช้/เพิ่ม) | design §6 | `src/server/Systems/Rebirth/` |
| ด่าน: sim ล้วน (timeline buffer) → ส่ง client → จ่ายเมื่อจบ · Progress/Farm | design §2 | `src/server/Systems/Stage/` (`Sim.luau`) · codec `src/shared/Timeline.luau` · config `src/shared/Config/Stages.luau` |
| Lobby + 6 lane สร้างด้วยโค้ด, จองช่องต่อผู้เล่น (attribute `Lane`) | design §8 | `src/server/Systems/World/` · ตำแหน่ง `src/shared/Config/World.luau` |
| เล่น timeline ฝั่ง client (pool rig R6 เรียบ), กล้อง lane 2D/3D / เดิน | design §8 | `src/client/Battle/` |
| กระเป๋า (Gear/Stacks, ความจุ 500 ไม่นับที่ใส่) | design §4 | `src/server/Systems/Inventory/` |
| Drop/กล่อง/ก้อน Farm/salvage · เปิดกล่องอัตโนมัติ (timer ต่อผู้เล่น) | design §4 | `src/server/Systems/Loot/` · `src/server/Systems/Box/` · อัตรา `src/server/Secret/` |
| Tag + ค้นหา `@tag` | design §4 | `src/shared/Tags.luau` |
| Offline 20% + AFK rejoin | design §6 | `src/server/Systems/Offline/` · client `src/client/Afk.luau` |
| ตั้งค่า (auto-salvage, skip wave, เปิดกล่องอัตโนมัติ) | — | `src/server/Systems/Settings/` |
| คำสั่ง dev (Studio เท่านั้น) | — | `src/server/Systems/Dev/` · ปุ่ม `src/client/UI/Dev/` |
| UI: HUD, หน้า Heroes (Gear/Skills+เปลี่ยนอาชีพ)/Team (ลากวาง)/Skill Tree/Bag/Boxes/Settings, เลือก hero ตัวแรก | — (ดู CLAUDE.md § UI theme) | `src/client/UI/` |
| **สไตล์ภาพ (โมเดล + VFX)** — อ่านก่อนทำ asset ใหม่ทุกครั้ง | [art-style.md](./art-style.md) | — |
| อาการพัง → ไฟล์เจ้าของ | [debug-map.md](./debug-map.md) | — |
| ความจำข้าม session | [STATE.md](./STATE.md) | — |

## โครงสร้างโฟลเดอร์ (`src/`)

ไฟล์ใหญ่แตกเป็นโฟลเดอร์ที่มี `init.luau` · บรรทัดแรกของทุกไฟล์บอกว่าไฟล์นั้นทำอะไร

```
src/shared/      (ReplicatedStorage.Shared)   Net · Types · Format · Freeze · Tags · Timeline · Config/ · Formula/ · Text/
src/server/      (ServerScriptService.Server) Data/ · Util/ (RateLimit Guard Rng) · Secret/ · Systems/
src/client/      (StarterPlayer.StarterPlayerScripts.Client)  State/ · Battle/ · UI/ (Core/ + 1 โฟลเดอร์ต่อหน้า) · Afk
```

## กติกาของเอกสาร

- 1 ระบบ = 1 ไฟล์ · บอก "อะไรมีอยู่ อยู่ที่ไหน ทำงานยังไง" ไม่ใช่ประวัติการแก้ (อันนั้นไป STATE.md)
- ตัวเลขเกมอยู่ใน `src/shared/Config/` — เอกสารอ้างชื่อ config ไม่ copy ตัวเลขมา (จะเก่า)
- แก้โค้ดแล้วพฤติกรรมเปลี่ยน → แก้เอกสารระบบนั้นใน commit เดียวกัน
