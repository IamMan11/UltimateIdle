# Plan — ขั้นตอนการทำ

สเปกอยู่ [design.md](./design.md) · ทำทีละขั้น ติ๊ก `[x]` เมื่อเสร็จ

## วิธีทำงานต่อ 1 ขั้น (ประหยัด token)

1. เปิดแชตใหม่ต่อ 1 ขั้น (หรือ 2–3 ขั้นเล็กที่ติดกัน) สั่งว่า `ทำขั้น X.Y ตาม docs/plan.md`
2. อ่านเท่านี้: `CLAUDE.md` · `docs/STATE.md` · ขั้นนั้นในไฟล์นี้ · หัวข้อของ `design.md` ที่ขั้นนั้นอ้าง · reference ของ skill ที่ตรงงาน 1 ไฟล์ · ไฟล์โค้ดที่จะแก้
3. ห้ามอ่าน `Packages/` และ `src/server/Data/ProfileStore.luau` (ใหญ่ ไม่ต้องแก้) · ห้ามอ่าน design.md ทั้งไฟล์ถ้าไม่จำเป็น
4. จบขั้น: `stylua src/` → `selene src/` → ติ๊กขั้นในไฟล์นี้ → เขียน `docs/STATE.md` (pattern/งานค้าง) → เพิ่มแถวระบบใน `docs/README.md` ถ้ามีระบบใหม่
5. **ข้ามไปก่อน ไม่ต้องรอ:** อะไรที่ต้องจัดการนอกโค้ด (ID จากหน้า Creator, ตั้งค่า Studio) หรือต้องทดสอบด้วยผู้เล่น 2 คน → เขียนโค้ดให้ครบ ใส่ค่าแทนใน Config แล้วจดลงหัวข้อ "ค้างทำภายนอก/ทดสอบ 2 คน" ท้ายไฟล์นี้ ติ๊กขั้นได้โดยหมายเหตุว่ายังไม่ได้ทดสอบส่วนนั้น
6. เจออะไรที่เปลี่ยนวิธีเล่น → หยุดถาม 1 คำถาม · ตัวเลข balance คิดเอง

## เฟส 0 — ฐาน

- [x] **0.1 Types + Format** — `src/shared/Types.luau` (GearItem, HeroState, ProfileData) · `src/shared/Format.luau` (ตัวเลข suffix, เวลา) · เสร็จเมื่อ: `Format.Number(1.5e12) == "1.5T"`
- [x] **0.2 Schema v1** — แก้ `src/server/Data/PlayerData.luau`: `PROFILE_TEMPLATE` ใหม่ (SchemaVersion, Gold, Ruby, AccountXp, AccountLevel, Heroes, Team, Gear, Stacks, Boxes, Stage{Mode,Level,MaxLevel}, Rebirth, SkillTree, Purchases, LastSeen, OfflineRate, NextUid, Settings) · แก้ `Types.luau` ให้ตรง: เพิ่ม `Ruby`, `GearItem.Rebirth`, `Stage.Rebirth` (rebirth ที่กำลังเล่น) + `Stage.ByRebirth` (Level/MaxLevel แยกต่อ rebirth), `SkillOff` (node ที่ปิดไว้), `Settings` (กรอง auto-salvage, เปิดกล่องอัตโนมัติ) + ฟังก์ชัน migrate · ลบ Cash/Level เดิมได้ (ยังไม่มีผู้เล่นจริง — STATE.md) · เสร็จเมื่อ: Play แล้วโหลดได้ ไม่มี error
- [x] **0.3 Util** — `src/server/Util/RateLimit.luau` · `Guard.luau` (ตัวตรวจชนิด/ช่วงค่า) · `Rng.luau` (สุ่มฝั่ง server, seed ได้)
- [x] **0.4 Net** — `src/shared/Net.luau` ด้วย Red: `StateSnapshot`, `StateDelta` (server→client) + โครงสำหรับ event ของระบบถัดไป · อ่าน `references/networking.md`
- [x] **0.5 Replication** — `src/server/Systems/Replication/`: ส่ง snapshot เมื่อ profile พร้อม · API `Replication.Set(player, path, value)` สะสม delta แล้ว flush รวมชุด
- [x] **0.6 Currency** — `src/server/Systems/Currency/`: `Add/Spend/Has` ตาม id เงินตรา (Gold, Ruby) (ตรวจ inf/NaN/ค่าติดลบ) แจ้ง Replication
- [x] **0.7 Client State + UI shell** — `src/client/State/` (เก็บ snapshot, apply delta, subscribe) · `src/client/UI/Core/` (App, Theme โทนเทาเรียบ, HUD แสดง gold) · อ่าน `references/ui-ux.md`
- [x] **0.8 ตรวจรวม** — คำสั่ง dev ฝั่ง server (เฉพาะ Studio) เพิ่ม gold → HUD เปลี่ยน · อัปเดต `docs/README.md` + `CLAUDE.md` (แทน `<ProjectName>`, เติม UI theme)

## เฟส 1 — Loop หลัก

- [x] **1.1 Config** — `Config/Heroes` (4 class) · `Monsters` · `Stages` (สูตรความยากต่อ level) · `Formation` · `src/shared/Formula/` (stat, ดาเมจ, xp) — design §2 §3
- [x] **1.2 Sim** — `Systems/Stage/Sim.luau`: pure function `(ทีม, level, seed, skipWave) → timeline + ผลลัพธ์` ไม่แตะ Instance · มี wave ซ้อน, แถว, ฟื้น 60 วิ
- [x] **1.3 Stage runner** — วน level ต่อผู้เล่นด้วยตัวจับเวลา · ให้ gold/xp · โหมด Progress (ถอย/ขึ้น) · ส่ง timeline
- [x] **1.4 Hero** — เลือกตัวแรก · level/xp (หารตามจำนวนตัว) · level ส่วนตัว · ซื้อ hero ด้วย gold · cache stat
- [x] **1.5 Client Battle** — lobby เรียบ + พื้นที่ด่าน 6 ช่องรอบ lobby (สร้างด้วยโค้ด ไม่แตะ Workspace ใน project.json) · จองช่องต่อผู้เล่นฝั่ง server · pool โมเดล R6 เรียบ · เล่น timeline · กล้องโหมดเดิน/ดูด่าน (2D/3D) — design §8
- [x] **1.6 HUD** — level/wave, gold/xp, ปุ่ม skip wave, ปุ่มสลับกล้องเดิน/ดูด่าน, หน้าเลือก hero ตัวแรก
- [x] **1.7 Offline + AFK** — บันทึกอัตราเฉลี่ยตอนออก · จ่าย 20% ตอนเข้า · rejoin ที่ 19:30
- [x] **1.8 โหมด Farm (เฉพาะ gold/xp)** — ปลดที่ level 200 · สลับโหมด · ก้อน item มาในขั้น 2.6

## เฟส 2 — ของ (design §4)

- [x] **2.1 Config ของ** — `Config/Items` (ของสวมใส่: baseId, ช่อง, class, tier, rebirth ที่หาได้, stat ฐาน, tags) · `Config/Materials` (ของ stack ได้ + tags) · `Config/Tiers` (ช่วง/เพดาน gear score) · `src/server/Secret/DropTables.luau` (ต่อ rebirth: ทุก tier มีโอกาสทุกด่าน) · `src/shared/Tags.luau` (tag อัตโนมัติจาก tier/ช่อง/class/rebirth + ตัวจับคู่คำค้น `@tag`) · เสร็จเมื่อ: เทสต์ `Tags.Match` ผ่าน
- [x] **2.2 Inventory** — `Systems/Inventory/`: `CreateGear/RemoveGear/AddStack/SpendStack/HasSpace` · uid จาก `NextUid` · ความจุ 500 ไม่นับที่สวม · delta ต่อชิ้น · ระบบอื่นห้ามแก้ `Gear/Stacks` ตรงๆ
- [x] **2.3 สวมใส่** — remote `Equip/Unequip` (ตรวจเจ้าของ, ช่องตรงชนิด, level hero ≥ level ของ) · ไม่ตรง class → ค่าปรับ stat + ปิดความสามารถอาวุธ (ใน `Formula`) · ทำ stat cache ของ hero ให้ dirty
- [x] **2.4 Drop + salvage** — Stage เรียกสุ่มของตอนจบ level (level ของ = min(level ด่าน, cap ของ rebirth ที่เล่น)) · auto-salvage ตามตัวกรองใน `Settings` → gold + วัตถุดิบ · remote ย่อยเอง/ย่อยหลายชิ้น
- [x] **2.5 กล่อง** — `Systems/Box/`: รับกล่อง (เต็ม 25 = หาย) · เปิดเอง/เปิดทั้งหมด (ตรวจที่ว่าง) · แปลง 5→1 กล่อง class (ถือ 10) · เปิดกล่อง class เลือก class + จำนวน · ตารางของกล่องใน `Secret/`
- [x] **2.6 ก้อนรางวัล Farm** — คำนวณรวมจาก level 1..N-1 (จำนวนคาดหวังต่อชนิด สุ่มครั้งเดียว) รวมของจากกล่อง · เกินความจุ → salvage · ต่อเข้ากับขั้น 1.8
- [x] **2.7 UI** — กระเป๋า (virtual list, ช่องค้นหา ชื่อ + `@tag`, เรียง/กรอง) · หน้า hero + 10 ช่องสวมใส่ · หน้ากล่อง · ตั้งค่า auto-salvage · อ่าน `.claude/skills/ui-modal/SKILL.md` ก่อนทำหน้าต่าง

## เฟส 3 — ทีม (design §3 §6)

- [x] **3.1 สกิล hero** — `Config/Skills` (ติดตัว 1 + ใช้เอง 2 ต่อ class, cooldown, ปลดตาม level hero) · เพิ่มใน `Sim` (ใช้อัตโนมัติ, สกิลชุบของ healer) · timeline มี event สกิลให้ client เล่น
- [x] **3.2 ทีม + แถว** — remote `SetTeam` (ตรวจจำนวนช่องที่ปลด, hero เป็นของเรา, แถวละ ≤4) · โบนัสตำแหน่ง/คู่ที่เข้ากันใน `Config/Formation` · มีผล level ถัดไป
- [x] **3.3 Skill tree** — `Config/SkillTree` (3 สาย, node มี: ราคา gold/item/แต้ม rebirth, node ก่อนหน้า, ผล, เปิดปิดได้ไหม) · `Systems/SkillTree/`: `Buy` (ไม่มี reset) · `Toggle` เฉพาะ node ที่เปิดปิดได้ · รวมผลเป็น modifier ก้อนเดียวที่ cache ไว้ · node ชุดแรก: ช่องทีม 2–4, % offline, ความจุกล่อง, เปิดกล่องอัตโนมัติ
- [x] **3.4 เปิดกล่องอัตโนมัติ** — ทำงานตาม cooldown จาก skill tree ด้วยตัวจับเวลาต่อผู้เล่น (ไม่ใช่ loop ต่อเฟรม) · หยุดเมื่อกระเป๋าเต็ม
- [x] **3.5 เปลี่ยนอาชีพ** — `Config/Classes` (2 ขั้นต่อ class: เงื่อนไข level hero + gold + item, cap ของสวมใส่ที่เพิ่ม, สกิลที่แรงขึ้น) · remote `Advance`
- [x] **3.6 Level ส่วนตัว** — `Config/Account` (ตารางปลดฟีเจอร์ + โบนัส) · ย้ายเงื่อนไขปลด Farm/trade มาอ่านจากที่นี่
- [x] **3.7 UI** — หน้าจัดทีม (ลากวางแถว) · หน้า skill tree (เส้นแยกสาย, ปุ่มเปิดปิด) · หน้าสกิล/เปลี่ยนอาชีพ

## เฟส 4 — Rebirth (design §6)

- [x] **4.1 Rebirth** — `Config/Rebirth` (ต่อขั้น: level ที่ต้องผ่าน, cap ต่างๆ, ตัวคูณความยาก, ของรางวัล, แต้ม) · `Systems/Rebirth/`: `Rebirth` (ไม่ reset อะไร) · ทุกที่ที่ใช้ cap อ่านจากที่นี่
- [x] **4.2 เลือก rebirth ที่เล่น** — remote `SetPlayRebirth` (≤ ที่ปลดแล้ว) · Stage ใช้ความยาก/cap/ตาราง drop ของ rebirth ที่เลือก · level เก็บแยกต่อ rebirth (`Stage.ByRebirth`) · มีผล level ถัดไป
- [x] **4.3 UI** — หน้า rebirth (เงื่อนไข, สิ่งที่จะได้, ตัวเลือก rebirth ที่เล่น)

## เฟส 5 — เสริมพลัง (design §5)

- [x] **5.1 ตีบวก** — `Config/Enhance` (ค่าพลังต่อขั้น, ราคา, item เฉพาะของบางชิ้น) · `Secret/EnhanceRates` · remote `Enhance(uid)`: ตรวจ → หัก gold+ของ → สุ่ม → +1 หรือคงเดิม (ไม่แตก)
- [x] **5.2 เปิดช่อง** — remote `MergeSocket(mainUid, materialUid)`: baseId + tier เดียวกัน, จำนวนช่องเท่ากัน, <5 → ชิ้นหลัก +1 ช่อง ชิ้นวัตถุดิบหาย (ต้องไม่ได้สวม/ไม่มีของในช่อง) · item ข้ามขั้น
- [x] **5.3 ใส่ของในช่อง** — `Config/Inserts` (Gem/Artifact/Relic + ผล) · remote `SetSocketKind/Insert/Remove` (ถอดเสีย gold, เปลี่ยนชนิดคืนของ) · ผล Artifact เข้า `Sim` · ผล Relic เข้า modifier ทีม
- [x] **5.4 Enchant** — `Secret/EnchantPools` (trait + ช่วงค่า ต่อ tier) · remote `Enchant(uid)`: หัก item → สุ่มใหม่ทั้งชุด
- [x] **5.5 UI** — หน้าตีบวก · หน้าช่องเสริม · หน้า enchant (แสดงผลก่อน/หลัง)

## เฟส 6 — เศรษฐกิจ (design §6)

- [x] **6.1 Trade** — `Systems/Trade/`: ขอ/รับ → ใส่ของ+gold (ล็อกของ) → ยืนยัน 2 ชั้น (แก้ข้อเสนอ = ยกเลิกการยืนยัน) → ตรวจซ้ำทั้งสองฝั่ง (ยังมีของ, ที่ว่างพอ, ไม่ได้สวม, ถึง level ส่วนตัว) → สลับในจังหวะเดียวไม่มี yield → log · ยกเลิกเมื่อฝ่ายใดออก · อ่าน `references/security.md` · ทดสอบ 2 ผู้เล่น · _ยังไม่ได้ทดสอบ 2 คน (render หน้า trade ด้วย view จำลองผ่าน) · ทุก trade ต้องผ่าน PolicyService `IsPaidItemTradingAllowed` เพราะ Robux ซื้อของได้_
- [x] **6.2 Gamepass + gift** — `Systems/Shop/`: x2 gold, x2 xp (เช็กทั้งที่ซื้อเองและ `Purchases.Owned`) มีผลกับ offline · gift = developer product เลือกผู้รับใน server · `ProcessReceipt` กันซ้ำด้วย purchaseId · ต้องมี ID จากหน้า Creator ก่อน · อ่าน `references/monetization-and-liveops.md` · _ID = 0 ใน `Config/Shop.luau` · ทดสอบผ่าน dev `receipt` (dedupe + รอเซฟ) และ dev `pass` (x2) แล้ว · gift ส่งผ่าน `ProfileStore:MessageAsync` (ผู้รับออกไปแล้วก็ได้)_
- [x] **6.3 Quest** — `Config/Quests` (รายวัน/รายอาทิตย์/รายเดือน: เงื่อนไขนับ เช่น ฆ่า boss N, ผ่าน N level, ตีบวก N ครั้ง + รางวัล Ruby) · `Systems/Quest/`: ระบบอื่นแจ้งเหตุการณ์ผ่าน `Quest.Progress(player, kind, n)` · รีเซ็ตตามวัน/สัปดาห์/เดือน UTC ตรวจตอนเข้าและตอนรับรางวัล (ไม่ใช้ loop) · remote `ClaimQuest`
- [x] **6.4 Battle pass** — สายฟรี + พรีเมียม ฤดูละ 1 เดือน · `Config/BattlePass` (ขั้น, รางวัล Ruby/ของ, ความยาวฤดู) · แต้ม pass จาก quest · remote `ClaimPass`
- [x] **6.5 ร้านรายเดือน** — `Config/Shop` (ของ, ราคาเป็น Robux/gold/Ruby, โควตาต่อเดือน) · นับโควตาใน profile รีเซ็ตตามเดือน UTC
- [x] **6.6 UI** — หน้า trade · ร้าน · gift · quest · battle pass · _HUD: Quests (มีแท็บ Battle Pass) · Shop (แท็บ Passes = ซื้อ/gift) · Trade_

## เฟส 7 — เก็บงาน

- [ ] **7.1 ดูด่านคนอื่น** — ส่ง timeline ให้ทุก client · วาด 2D · คลิกเพื่อปรับมุม
- [ ] **7.2 Analytics + log ผิดปกติ** (เงินเพิ่มเร็วเกิน, remote ถูก rate limit บ่อย)
- [ ] **7.3 ปรับ balance รอบแรก** จากการเล่นจริง
- [ ] **7.4 มือถือ** — ขนาด UI, ปุ่มสัมผัส, ลดจำนวนโมเดลบนจอ
- [ ] **7.5 ทีหลังสุด** — tutorial · ตั้งค่า · leaderboard · รางวัลรายวัน · โค้ด · raid/challenge/event/boss map

## ค้างทำภายนอก / ทดสอบ 2 คน (กลับมาทำทีหลัง)

- [ ] เปิด Studio API access แล้วเช็กว่าเซฟจริงได้ (เกี่ยวกับ 0.2)
- [ ] สร้าง gamepass + developer product ในหน้า Creator แล้วใส่ ID ใน `src/shared/Config/Shop.luau` — gamepass: `Passes[].PassId` (Gold2x, Xp2x) · developer product: `Products` (GiftGold2x, GiftXp2x, PremiumPass, ShopRuby, ShopCores) · ตั้งราคาให้ตรง `RobuxPrices` (ตัวเลขที่ปุ่มแสดง) · เจ้าของกำหนดรายการ gamepass เพิ่มเติม
- [ ] ทดสอบ 2 ผู้เล่น: trade (6.1) · gift (6.2) · ดูด่านคนอื่น (7.1) · จองช่องด่านเมื่อมีหลายคน (1.5)
- [ ] ทดสอบซื้อจริงด้วย Robux (6.2, 6.4, 6.5)
- [ ] Offline (1.7): ทดสอบหลังเปิด API access — ออก แล้วเข้าใหม่ ต้องขึ้น toast "While you were away" (mock store ล้างข้อมูลทุก Play จึงทดสอบใน Studio ตอนนี้ไม่ได้)
- [ ] AFK rejoin (1.7): teleport ทำงานเฉพาะเกมที่ publish — ทดสอบในเซิร์ฟจริง (Studio แค่ print)
