# STATE — ความจำข้ามเซสชัน

ไฟล์นี้คือสิ่งที่ session ก่อนทิ้งไว้ให้ session ถัดไป: งานค้าง · บั๊กที่แก้แล้วยังพัง · สิ่งที่เรียนรู้ · ทางตัน
**อ่านก่อนเริ่มทุก session · เขียนกลับก่อนจบ** — บันทึก pattern ("X ทำให้ Y แก้ด้วย Z") ไม่ใช่เหตุการณ์
ไม่ใช่เอกสารระบบ (อันนั้นอยู่ `docs/README.md`) และไม่ใช่ที่เก็บกติกา (อันนั้นอยู่ `CLAUDE.md`)

ทุกข้อติดที่มา: `(SAID)` = ผู้ใช้บอก ยังไม่ตรวจ · `(SEEN)` = ตรวจในโค้ด/รันแล้ว — ยกระดับ SAID → SEEN เมื่อตรวจแล้ว ไม่ยกเอง
ข้อที่พิสูจน์แล้วว่าใช้ได้ทุกโปรเจกต์ → ย้ายไป `.claude/skills/roblox-game-dev/references/field-notes.md` ของกลาง (E:\ClaudeShared) (หรือ reference ของ game-assets)

## งานค้าง

| งาน | ถึงไหนแล้ว | ขั้นต่อไป | อัปเดต |
|---|---|---|---|
| เปิด DataStore จริง | publish แล้ว (placeId 108236200953937) แต่ Studio API access ยังปิด → ProfileStore รัน mock (SEEN) | Game Settings → Security → Enable Studio Access to API Services แล้ว Play ซ้ำ 2 รอบ: hero ที่เลือก + Gold ต้องยังอยู่รอบที่ 2 (LogInTimes ถูกลบใน schema v1) | 2026-10-31 |
| สร้างเกมตามแผน | เฟส 0–3 เสร็จ ทดสอบใน Studio แล้ว (SEEN) | เฟส 4 ขั้น 4.1 (Rebirth: ย้าย cap/WearCaps/AccountLevelCap ที่อยู่ `Config/Rebirth` ให้ขยายต่อขั้น · `Systems/Rebirth` มีแค่ Points) | 2026-11-14 |
| ลบไฟล์เก่า | `src/shared/Hello.luau` ย้ายไป `_to_delete/` (ไม่มีสิทธิ์ลบ) (SEEN) | ผู้ใช้ลบโฟลเดอร์ `_to_delete/` เอง | 2026-11-14 |
| commit แรก | ยังไม่มี commit (SEEN) | ผู้ใช้รัน `git add .` + `git commit` เอง (git ใน device_bash ค้าง lock ถ้าไม่มีสิทธิ์ลบ) | 2026-10-31 |

## Strikes — บั๊กเดิมที่แก้แล้วยังพัง

แก้พลาด 1 ครั้ง = 1 strike · ครบ 2 ให้กลับไปอ่าน reference + โค้ดจริงก่อนลองใหม่ · ครบ 3 หยุดเดา ถามคำถามเดียวที่เฉพาะเจาะจง
แก้ได้แล้วย้ายไป Learned patterns แล้วลบแถว

| ปัญหา | ครั้งที่ | ลองอะไร | ผล |
|---|---|---|---|
| | | | |

## Learned patterns

- ProfileStore ไม่มี API access → ไม่คืน nil แต่สลับเป็น mock เอง พิมพ์ `Roblox API services unavailable - data will not be saved` → เช็คบรรทัดนี้แทนการรอโดน kick (SEEN)
- type `ProfileStore.Profile<Data>` ไม่ตรงกับค่าที่ `StartSessionAsync` คืนใน strict (`Data & JSONAcceptable`) → ใช้ `typeof(assert(PlayerStore:StartSessionAsync("", {})))` แทน (SEEN, luau-lsp 1.70.1)
- selene `[config] x = { severity = ... }` ไม่ใช่ syntax จริง · ระดับ lint ตั้งใน `[lints]` · ยกเว้นไฟล์ด้วย `exclude = [...]` (SEEN)

- `string.gsub` คืน 2 ค่า: ซ้อนเป็น arg แรกได้ (ถูกตัดเหลือค่าเดียว) แต่อย่าวางเป็น arg สุดท้ายของ call อื่น (SEEN)
- ใน VM ของ device_bash ไม่มี stylua/selene/luau → โหลด release จาก GitHub ลง cloud container แล้ว stage ไฟล์ไปตรวจ: `luau` รันเทส pure module ได้, `luau-analyze --mode=strict` ตรวจ type ได้ถ้าไม่ require Roblox instance (SEEN)

- device_bash VM โหลด binary จาก GitHub ได้: stylua/selene/luau-lsp/rojo (รุ่นตาม rokit.toml) + `globalTypes.None.d.luau` ลง `$HOME/bin` แล้วรันบนโฟลเดอร์จริงได้เลย ไม่ต้อง stage (SEEN) · โหลด lune ถูก auto-mode ปฏิเสธ → ทดสอบ pure module ใน Studio แทน
- Rojo ของผู้ใช้ sync โฟลเดอร์ D:\UltimateIdle เข้า Studio "Place1" อยู่แล้ว → แก้ไฟล์แล้ว Stop/Play ใหม่ได้ผลทันที (SEEN)
- `execute_luau` ใน **Edit** require module ได้ของเก่าที่ cache ไว้ (เช่น `Formula.Mods` = nil ทั้งที่ Rojo sync แล้ว) → ทดสอบ pure module ใน Play (Server) แทน (SEEN)
- `execute_luau` ใน Server/Client require module ได้ instance ใหม่ (cache แยก) → อ่าน state ของระบบที่รันอยู่ไม่ได้ (PlayerData.Data = nil) · ตรวจผลทาง GUI/Workspace หรือ attribute แทน · ใช้รัน Sim/Formula แบบ pure ได้ (SEEN)
- คลิก UI ด้วย `user_mouse_input` ต้องใช้ `instance_path` (พิกัด x/y จาก screenshot คลาดเคลื่อน) · path React = ชื่อ key ของ child เช่น `LocalPlayer.PlayerGui.Main.Frame.Page.Window.Content.…` (SEEN)
- Red: event ที่ server ยิงก่อน client ตั้ง listener หายไป (ไม่มีคิว) → client ส่ง `RequestSnapshot` หลังตั้ง listener, ระบบอื่นยิงซ้ำผ่าน `Replication.OnSynced` (SEEN)
- React-lua `useState(nil :: T?)` ทำให้ setter รับแค่ nil ใน strict → ใช้ `Widgets.useOptional(nil :: T?)` (SEEN)
- Table ที่ type `{[string]: number}`: `x[k] = if c then v else nil` ไม่ผ่าน strict → เขียน if/else แยก (SEEN)
- stylua ลบ `;` นำหน้า `(expr)[k] = v` → parse พัง · ใช้ `local t: any = data; t[k] = v` (SEEN)
- Sim: monster ระยะไกลหยุดไกลเกินระยะตีของ hero ประชิด → level ค้าง timeout · ระยะตี hero = Range + ContactGap + `MELEE_SLACK` (SEEN)
- React drag: เก็บ drag ใน ref (`dragRef`) ให้ handler อ่าน/เขียน · state ไว้วาดเท่านั้น · ถ้าใช้ state ใน closure ตรงๆ InputChanged ที่มาช้าหลังปล่อยปุ่มจะชุบ drag กลับ ghost ค้าง (SEEN, หน้า Team)
- ทดสอบลากใน Studio: `user_mouse_input` mouseButtonDown → moveTo (instance_path) → mouseButtonUp ใน call เดียวกันได้ · call ใหม่ต้อง moveTo ก่อน mouseButtonUp (SEEN)
- เช็ก effect ชั่วคราวบน client (ชื่อสกิลบนหัว) ด้วย poll `ClientBattle` ≥20 วิ — 10 วิอาจพลาดเพราะ cooldown (SEEN)
- Balance รอบแรก (hero เดี่ยว ไม่มีของ): ~L100 ใน 1.5 ชม. ติดเพดาน hero L150 ที่ด่าน ~155 (SEEN, sim ใน Studio)

## Dead ends — ลองแล้วไม่ได้ผล อย่าลองซ้ำ

- 

## Regression runs — เช็กหลังแก้ shared code

- `stylua src/` และ `selene src/` → ผ่าน
- smoke boot: Play 10 วิ → ไม่มี error (ขั้นตอน `.claude/skills/roblox-game-dev/references/smoke-test.md` — รันเมื่อผู้ใช้สั่งเท่านั้น)
- prefix log ของระบบเรา (ใช้ให้คะแนน WARN ใน smoke): `[PlayerData]` `[Currency]` `[Inventory]` `[RateLimit]` `[World]` `[Battle]` `[Offline]`
- tool รัน: `rojo sourcemap default.project.json --output /tmp/sm.json` → `luau-lsp analyze --sourcemap=/tmp/sm.json --definitions=$HOME/bin/globalTypes.d.luau --base-luaurc=.luaurc --ignore="Packages/**" --ignore="**/ProfileStore.luau" src/` ต้องว่าง

## Session log

- 2026-10-31: ตั้ง PlayerData (src/server/Data) + ProfileStore vendored, .vscode/settings.json, selene.toml, roblox.yml gitignored · stylua/selene/luau-lsp ผ่าน · Play: โหลดโปรไฟล์ได้ (mock) PASS
- 2026-11-14: ตกลงสเปกเกมกับเจ้าของ เขียน docs/design.md + docs/plan.md · ยังไม่แตะ src/
- 2026-11-14: ขั้น 0.1 — Types.luau + Format.luau · stylua/selene/luau-analyze ผ่าน · `Format.Number(1.5e12) == "1.5T"` PASS (รันด้วย luau CLI) · ช่องสวมใส่ = 10 (เจ้าของยืนยัน แก้เลข 11 ใน design/plan แล้ว)
- 2026-11-14: เฟส 0–2 (0.2–2.7) ครบ · stylua/selene/luau-lsp strict ผ่าน 0 error · Studio Play: เลือก hero → ด่านเล่น/จ่าย gold+gear, Bag ค้นหา @tag + salvage confirm, Heroes ใส่ของ/ซื้อ hero, Boxes เปิด/แปลง, Farm + skip wave + กล้อง 3D PASS · offline/AFK ยังไม่ได้ทดสอบจริง
- 2026-11-14: เฟส 3 (3.1–3.7) ครบ · stylua/selene/luau-lsp strict 0 error · Studio Play PASS: ซื้อ node (confirm), Squad I → ทีม 2 ช่อง (ลากวาง + เกินช่อง = toast), เปลี่ยนอาชีพ 2 ขั้น (wear cap 60→110→150), sim ยิงสกิล (PowerStrike/Fireball/Meteor/ShieldWall/MassHeal) + ชื่อสกิลขึ้นบนหัว, กล่องเปิดอัตโนมัติทุก 20 วิ, cap กล่อง 25→35 · ยังไม่ทดสอบ: Resurrect ในด่านจริง, toggle Berserk ผ่าน UI, กระเป๋าเต็มแล้ว auto-open หยุด/กลับมา · `Settings.AutoOpenBoxes` = สวิตช์ auto-open · `SkillOff` = node toggle ทั่วไป
- 2026-11-14: เจ้าของตัดสิน 4 ข้อ → ทำแล้ว: skip wave เฉพาะ level ที่เคยผ่าน · ออกจาก Farm กลางรอบ = ได้ก้อนของรอบที่จบล่าสุด (`LastFarmRound`) · กล่องแยก stack ตาม kind:rebirth:ช่วง level 25 (schema v2) แปลง class ได้จาก Normal และ Boss · ข้อความภาษาอังกฤษเท่านั้น · Studio PASS (กล่องแยกช่วง, แปลง Boss→Mage, ป้าย skip รอผ่าน level)
