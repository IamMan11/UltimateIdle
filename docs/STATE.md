# STATE — ความจำข้ามเซสชัน

ไฟล์นี้คือสิ่งที่ session ก่อนทิ้งไว้ให้ session ถัดไป: งานค้าง · บั๊กที่แก้แล้วยังพัง · สิ่งที่เรียนรู้ · ทางตัน
**อ่านก่อนเริ่มทุก session · เขียนกลับก่อนจบ** — บันทึก pattern ("X ทำให้ Y แก้ด้วย Z") ไม่ใช่เหตุการณ์
ไม่ใช่เอกสารระบบ (อันนั้นอยู่ `docs/README.md`) และไม่ใช่ที่เก็บกติกา (อันนั้นอยู่ `CLAUDE.md`)

ทุกข้อติดที่มา: `(SAID)` = ผู้ใช้บอก ยังไม่ตรวจ · `(SEEN)` = ตรวจในโค้ด/รันแล้ว — ยกระดับ SAID → SEEN เมื่อตรวจแล้ว ไม่ยกเอง
ข้อที่พิสูจน์แล้วว่าใช้ได้ทุกโปรเจกต์ → ย้ายไป `.claude/skills/roblox-game-dev/references/field-notes.md` ของกลาง (E:\ClaudeShared) (หรือ reference ของ game-assets)

## งานค้าง

| งาน | ถึงไหนแล้ว | ขั้นต่อไป | อัปเดต |
|---|---|---|---|
| เปิด DataStore จริง | publish แล้ว (placeId 108236200953937) แต่ Studio API access ยังปิด → ProfileStore รัน mock (SEEN) | Game Settings → Security → Enable Studio Access to API Services แล้ว Play ซ้ำ 2 รอบ: LogInTimes ต้องขึ้นจาก 1 เป็น 2 | 2026-10-31 |
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

## Dead ends — ลองแล้วไม่ได้ผล อย่าลองซ้ำ

- 

## Regression runs — เช็กหลังแก้ shared code

- `stylua src/` และ `selene src/` → ผ่าน
- smoke boot: Play 10 วิ → ไม่มี error (ขั้นตอน `.claude/skills/roblox-game-dev/references/smoke-test.md` — รันเมื่อผู้ใช้สั่งเท่านั้น)
- prefix log ของระบบเรา (ใช้ให้คะแนน WARN ใน smoke): `[PlayerData]`

## Session log

- 2026-10-31: ตั้ง PlayerData (src/server/Data) + ProfileStore vendored, .vscode/settings.json, selene.toml, roblox.yml gitignored · stylua/selene/luau-lsp ผ่าน · Play: โหลดโปรไฟล์ได้ (mock) PASS
