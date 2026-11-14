# Rigging & Animation — Blender → Game

## 1. โครงกระดูก

- Root ที่ (0,0,0) บนพื้น rotation 0 scale 1 · **ไม่มี weight บน root** · root ถือ root-motion เท่านั้น
- ลำดับ: Root → Hips/Pelvis → Spine01–03 → Chest → Neck → Head · ขา/แขนแยกออกจาก Hips/Chest
- Spine: mobile ≥ 3 · แนะนำ 4–5
- จำนวน bone: mobile 30–50 (hard limit ~75 ต่อ mesh) · PC 75–120 · Roblox R15 = 15 part + Motor6D (custom rig ใช้ Bone ได้แต่คิดแบบ mobile)
- **Influence ต่อ vertex ≤ 4** (Roblox บังคับ 4 · PC ได้ถึง 8) · Blender: Automatic Weights → Limit Total 4 → Clean 0.01 → Normalize
- Twist bone: forearm/thigh ≥ 1 ต่อท่อน (50%) · realistic 2 (33/66%) · Copy Rotation local, Mix=Add, แกนบิดเท่านั้น influence = ตำแหน่ง
- Clavicle → Shoulder → ShoulderHelper (30% ของ shoulder rot) · clavicle ยก 15–20° เมื่อแขน 90°
- Pole target: บนระนาบแขน/ขา ห่าง ~1.5× ความยาวท่อนบน · หลังศอก / หน้าเข่า
- Bone orientation: แกนหลักชี้ไปลูก · แกนรองชี้ทิศงอ · roll สม่ำเสมอ (Recalculate Roll → Global +Z แล้วแก้มือ) · ซ้ายขวา mirror กันจริง — พลาดข้อนี้ = retarget พัง
- ชื่อ bone convention เดียวทั้งเกม (`Spine1/LeftArm/LeftForeArm` หรือ Blender `.L/.R`) เพื่อ retarget/mirror
- **Rest pose = bind pose** (A หรือ T เลือกอย่างเดียวทั้งโปรเจกต์ รวมนิ้ว) · apply armature transform ก่อน bind
- ทำโครงให้ครบ (helper/twist ด้วย) **ก่อน** skin · เปลี่ยนทีหลัง = weight พัง
- **ห้าม scale joint** · squash/stretch ทำบน helper bone แกนเดียว
- Joint limit ใน DCC ไม่ถูก export → ทำใน engine

## 2. Weight painting

- Normalize ✓ · ผลรวม = 1 · ไม่มี vert น้ำหนัก 0
- Smooth brush 0.1–0.2 · แต่ละ bone คุม ≥ 3–4 vert (ไม่งั้นลบ bone) · ไม่มี weight island
- ท่าทดสอบบังคับ: แขน 45° / 90° / 180° · forearm twist 180° · ย่อเข่าสุด · บิด+ก้มลำตัว · บิด 45° · กางขา/เตะ · ศอก-เข่า 90°
- ลำดับแก้: weight → helper bone → corrective shape key (สุดท้าย ≤ 10–20 ตัว · driver 0°→0, 45°→0.5, 90°→1)
- ใบหน้า: bone สำหรับกราม/คิ้ว/แก้ม + shape key สีหน้า · จำนวน shape: mobile 15–25 · PC 40–60 · เปลือกตาบน/ล่าง 70/30
- **ห้าม**แก้ topology หลังมี shape key

## 3. Animation — ทั่วไป

- FPS: ทำที่ 30 fps สำหรับเกม (60 สำหรับ hero/combat ที่ต้องละเอียด) · Roblox Animation Editor ค่าเริ่มต้น 30 fps (สูงสุด 60)
- 12 principles ที่มีผลกับเกมมากสุด: **anticipation** (ง้าง 2–6 เฟรม@30) · **follow-through/overlap** (ผม/ผ้า/อาวุธ ช้ากว่าตัว 1–3 เฟรม) · **ease in/out** · **squash/stretch** (stylized ≤ 10–20%) · arc · secondary action
- Loop: เฟรมแรก = เฟรมสุดท้าย (ก๊อปคีย์) · เดิน: paste-flipped ครึ่งหลัง · ทดสอบ seam **หลัง** compression ใน engine
- Locomotion clip ที่จะ blend กัน: เท้าซ้าย/ขวาลงที่ normalized time เดียวกัน (sync marker) · จุด blend ความเร็ว 0 Idle / 0.3 WalkSlow / 0.6 Walk / 1.0 Run / 1.5 Sprint
- เท้าไถล: ปรับ playback = ความเร็วจริง / ความเร็วคลิป · foot IK เป็นทางสุดท้าย
- Root motion ใช้กับ: ปีน กระโดดข้าม hit-react cutscene · in-place ใช้กับ: การควบคุมที่ต้องตอบสนอง ความเร็วแปรผัน เกมออนไลน์ (server เป็นเจ้าของตำแหน่ง → root motion เป็นแค่ภาพ) · loop root-motion ต้องกลับมา delta 0 ที่เฟรมสุดท้าย
- Blend/crossfade ≥ 0.1 s ปกติ 0.15 s · **ไม่มี 0** · weight ของ layer/IK ramp เสมอไม่ snap
- Additive layer (หายใจ มอง สะดุ้ง) ≤ 2–3 ชั้น · reference pose ต้องตรงกับ base ไม่งั้น "ระเบิด"
- Event (ดาเมจ/เสียงเท้า) ใช้ **ช่วงเวลา** (normalized 0.3–0.5 หรือเฟรม 10–12) ไม่ใช่เฟรมเดียว · ยิงครั้งเดียวต่อ state
- Compression error: bone หลัก 0.5° · นิ้ว/มือ 0.1° · ตรวจ drift ที่ loop seam

## 4. Attack timing (action/survivor game)

ตัวอย่างโจมตี 26 เฟรม @30fps:

| ช่วง | เฟรม | ยกเลิกได้ไหม |
|---|---|---|
| Windup (anticipation) | 0–5 | dodge ได้ |
| Active (hitbox เปิด) | 6–15 | ไม่ได้ — commit |
| Recovery | 16–25 | ต่อคอมโบได้ |
| Free | 26+ | ทุก state |

- buffer input ระหว่างโจมตี · ท่าที่ยกเลิกไม่ได้ = การตัดสินใจเชิงออกแบบ ไม่ใช่บั๊ก
- Auto-attack (แนว survivor): animation สั้น ≤ 0.3 s · hit frame ตรงกับ VFX/SFX ±1 เฟรม · ศัตรูมี telegraph (windup) ≥ 0.4 s ก่อน hitbox เปิดถ้าเลี่ยงได้
- hit-react: 4–8 เฟรม · ไม่ขัด action ของผู้เล่น (additive upper-body) · ศัตรูตาย: ragdoll หรือ clip ≤ 1 s แล้ว despawn/fade

## 5. State machine (ถ้าทำเองใน engine)

- Hierarchical: Locomotion / Combat เป็น super-state · Any→Death สูงสุด · Any→HitReact รองลงมา · Any-state transition ห้าม transition to self และ reset trigger ตอนเข้า
- ≤ 3–5 transition ออกต่อ state · > 50 state ชั้นเดียว = ต้องแตก · ทุก state มี exit ชัด
- Layer: 0 base · 1 upper-body override (mask spine ขึ้นไป) · 2 additive · 3 IK
- IK budget/ตัว: เท้า 2 chain × 3 iter (~0.1 ms) · มือ ~0.1 ms · look-at ~0.02 ms · full-body 1–2 ms (เลี่ยง) · LOD: full 0–10 m · เท้าอย่างเดียว 10–25 m · ปิด > 25 m
- Roblox: ใช้ `Animator:LoadAnimation` (ไม่ใช่ Humanoid) · `AnimationPriority` Core < Idle < Movement < Action < Action2–4 · ตั้ง `Looped` ใน asset ไม่ใช่โค้ด · weight fade ด้วย `:Play(fadeTime)` ≥ 0.1

## 6. Export (Blender → FBX)

- Action ละ 1 ไฟล์ หรือ 1 ไฟล์ต่อตัวละครแต่ Bake Animation ✓ / NLA Strips ✗ / All Actions ตามที่ engine ต้องการ · Roblox: **1 animation track ต่อไฟล์**
- Add Leaf Bones ✗ · Primary Y / Secondary X · Apply Transform ✓ · armature scale 1 rot 0
- Roblox custom rig: root bone ที่ 0,0,0 · ทุก bone scale 1 rot 0 (ตามสเปค) · ไม่มี influence บน root · mesh ≤ 20k tri/ชิ้น

## 7. Sharp edges

1. Bind ≠ rest pose → mesh เลื่อนจากโครง
2. > 4 influence หรือ weight < 0.01 โดน cull ตอน export → แหลม/ฉีก
3. เกิน ~75 bone → พังเฉพาะบางเครื่อง
4. Root ไม่อยู่ origin → ไถล/วาร์ป/retarget เพี้ยน
5. ไม่มี twist bone → forearm บิดเป็นเกลียว
6. Bone roll มั่ว → IK พลิก mirror พัง
7. Scale joint → shear
8. แก้ mesh หลังมี shape key → ระเบิด
9. Locomotion clip เฟสเท้าไม่ตรง → ลอย
10. Event เฟรมเดียวโดนข้ามที่ FPS ต่ำ
11. ไม่มี anticipation → ท่าโจมตี "ไร้น้ำหนัก"

## 8. Checklist

- [ ] Root ที่ origin · bone ≤ limit แพลตฟอร์ม · influence ≤ 4 · normalized · clean 0.01 · ไม่มี vert 0
- [ ] Rest = bind · roll ถูก · twist/helper ครบก่อน skin · ชื่อ bone ตาม convention
- [ ] ท่าทดสอบทั้ง 9 ผ่าน
- [ ] 30 fps (หรือ 60 ตามที่ตกลง) · loop first=last · root delta 0 · seam ผ่านหลัง compression
- [ ] anticipation ≥ 2 เฟรม · follow-through บนส่วนรอง · hit frame ตรง VFX/SFX
- [ ] Attack: windup/active/recovery กำหนดเป็นเฟรม · event เป็นช่วง
- [ ] Blend ≥ 0.1 s ทุก transition · additive reference pose ถูก
- [ ] Export: action แยก · Bake ✓ NLA ✗ · Leaf Bones ✗ · Roblox 1 track/ไฟล์
- [ ] ทดสอบใน engine ที่ 30 fps lock และบนมือถือ
