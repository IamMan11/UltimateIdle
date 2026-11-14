# Real-time VFX

หลัก: **VFX คือการสื่อสาร ไม่ใช่ของประดับ** · คิดใน 3 แกน **Shape → Timing → Color** · เอฟเฟกต์ที่ถูกสุดคือเอฟเฟกต์ที่ไม่มี

## 1. Timing (ที่ 60 fps)

- สัดส่วน **anticipation 10% · action 10% · follow-through 80%** · follow-through สั้น = ดูถูก
- ฟันดาบ ~12 เฟรม (200 ms): ง้าง 0–3 (scale จาก 0) · ฟัน 3–6 (วิ่งเต็ม arc) · ตาม 6–12 (จางพร้อมยืด) ease-out
- ระเบิด: ง้าง 0–4 (แกนสว่างเล็ก ดูดเข้า) · ปะทุ 4–8 (ขยายเร็ว สว่างสุด debris เกิด screen shake peak) · ตาม 8–60+ (ควันช้ากว่าไฟ ถ่านร่วงตามแรงโน้มถ่วง แสงจาง log ไม่ใช่ linear)
- ไม่มี anticipation → เพิ่ม 2–4 เฟรม เล็ก→ใหญ่ มืด→สว่าง · **เสียงเริ่มก่อนภาพ**
- Hitstop (game feel): 2–6 เฟรม สำหรับโจมตีธรรมดา · 8–15 เฟรม สำหรับ crit/ท่าไม้ตาย · ระหว่าง hitstop หยุด spawn ใหม่ particle เดิมช้าลง
- Screen shake: amplitude 2–8 px (UI scale) หรือ 0.1–0.4 stud กล้อง · 0.1–0.25 s · decay แบบ exponential · มี slider Off/Low/Med/High · **ห้าม**เขย่า UI

## 2. Budget

- เฟรม 16.67 ms → VFX ได้ ~2 ms (sim 0.5 · render 0.8 · post 0.5 · distortion 0.2)
- Tier ต่อเอฟเฟกต์ (**ต้องตั้ง MaxParticles เสมอ** ไม่ใช่แค่ rate):

| Tier | ตัวอย่าง | Max particles | Shader | จอที่กินได้ | พร้อมกัน |
|---|---|---|---|---|---|
| 1 Hero | บอสตาย อัลติ | 10,000 (mobile 2,500) | เต็ม + distortion (PC) | 10% | 1 |
| 2 Combat | hit สกิล โปรเจกไทล์ | 500 (mobile 100–250) | ง่าย ไม่มี distortion | 2% | 10 |
| 3 Ambient | ฝุ่น ใบไม้ ไฟกอง | 100/emitter (mobile 25–50) | ต่ำสุด LOD ออกก่อน | 0.5% | หลาย |

- Spawn rate: ส่วนใหญ่ < 200/s · > 100/s ธงเหลือง · > 1000/s วิกฤต · ใช้เลขกลม 10/25/50/100
- Overdraw: PC < 4× เฉลี่ย / 8× peak · **mobile < 2× / 4×** · billboard ตัวเดียวกิน > 10% จอ = ธงแดง · particle > 5 unit ต้องหด/จางตามระยะ
- Mobile: fill rate ≈ 1/10 ของ PC · ลด particle ครึ่ง (low-end 1/4) · ตัวเล็กลง · **ไม่มี distortion** (ใช้ glow/สีแทน) · 1 texture sample · soft particle ปิด · เทส 10 นาทีบนเครื่องจริง (thermal throttle หลัง 30–60 s)
- Survivor game (ศัตรู 100+ บนจอ): hit effect ต่อศัตรูต้องเป็น tier 3 (≤ 10–20 particle, ≤ 0.3 s) · รวม effect ของดาเมจซ้ำ ๆ · ตั้ง cap รวมทั้งฉาก และ cull ที่อยู่นอกจอ

## 3. Layering recipe

**Projectile/magic** (ลำดับ = ลำดับตัดตอน LOD):
1. **Core** สว่าง additive เล็ก = ตำแหน่ง hitbox **ไม่ตัดเด็ดขาด**
2. Inner glow สีเดียวกัน saturation ต่ำ กะพริบเบา
3. Trail เกิดจาก core สืบทอดความเร็ว 0.3–0.7 จางตามระยะ
4. Distortion 2–5 px (PC เท่านั้น)
5. Ambient speck วนรอบ — ตัดก่อน

**Hit/impact**: flash additive 1–3 เฟรม → burst ตามทิศโจมตี + debris → ควัน alpha-blend ล้อม → spark/ember ร่วง · ทั้งก้อน ≤ 0.4 s ยกเว้น ควัน

**ไฟ/ระเบิด cascade**: ไฟ 30/s life 0.3–0.5 s ส้ม→แดง→ดำ additive · ควันเกิดตอนไฟตาย สืบทอดความเร็ว 50% life 2–4 s เทาเข้ม alpha ต่ำ + turbulence · ถ่าน 1–3 ต่อไฟตาย พุ่งขึ้นแล้วตก additive เล็ก

**Quality tier**: Ultra ครบ · High 1–4 · Medium 1–3 · Low 1–2 · Potato core เท่านั้น · **ออกแบบที่ Low ก่อน**

## 4. สี · blend · readability

- ออกแบบ **grayscale ก่อน**: core 100% ขาว · วงใน 70% · glow นอก 40% · เม็ดเล็ก 90% · ใส่สีทีหลัง core ยังขาว
- stack สี: ขาว (core) → สีธาตุอิ่ม (กลาง) → ขอบมืด/สีตรงข้าม 1–2 px (แยกจากทุกพื้นหลัง)
- Blend: **เปล่งแสง = additive** (core พลังงาน เลเซอร์ แกนไฟ) · **บังแสง = alpha** (ควัน ฝุ่น เศษ เลือด) · multiply = เงา/คราบ · additive ซ้อนมาก = สี่เหลี่ยมขาวหายบนพื้นสว่าง · alpha ซ้อนมาก = ขุ่น
- เทสบนพื้น **ขาว / ดำ / สีเดียวกับเอฟเฟกต์** (หิมะ ถ้ำ ป่า) และเปิด color grading จริง
- Color over lifetime บังคับ · hue variation ต่อ particle ±10°
- HDR: ดัน emission > 1.0 ให้ bloom ทำงาน แทนการเร่ง saturation
- สีต้องสื่อ gameplay คงที่ทั้งเกม: ดาเมจผู้เล่น / ศัตรู / heal / buff คนละชุด · ไม่ใช้สีเดียวกับศัตรูอันตราย

## 5. Flipbook / sprite sheet

- เฟรม ≥ 128 px สำหรับ hero · < 64 px ธงแดง · power-of-2 · pad ระหว่างเฟรมกัน bleed · premultiplied alpha
- ตัวอย่าง 8×8 = 64 เฟรม เล่น 30 fps · Roblox รองรับ 2×2 / 4×4 / 8×8 (texture จัตุรัส ≤ 1024)
- Compression: BC7 (PC) / ASTC 4×4 (mobile) · DXT5 ทำ alpha เป็นขั้น · เช็ค artifact ใน engine ไม่ใช่ image viewer
- เปิด frame blending (lerp 2 เฟรม) · สุ่มเฟรมเริ่ม · speed ±20% · lifetime ±20% กันเต้นพร้อมกัน
- Loop: เฟรม 0 ต้องต่อเนื่องกับเฟรม N−1 · เทสที่ 0.5× speed · flipbook fps × timeScale ของเกม

## 6. Motion feel

- Velocity inheritance 0.3–0.7 (ไม่ 1.0) + drag · gravity ตรงกับเกม · debris หนักตกเร็วกว่า · particle ตายเมื่อชนพื้น/น้ำ
- Local space = ติดตัว (aura, trail ตัวละคร) · World space = โปรเจกไทล์
- Noise แยก seed: spawn wander 0.5–2 Hz · turbulence 1–5 Hz (curl) · size shimmer 2–8 Hz ×0.8–1.2 · ของ organic ไม่มี noise = ดูเป็นเครื่องจักร · สุ่ม rotation + texture variant
- Loop ต่อเนื่อง: lifetime ±20% · 3 กลุ่ม spawn เหลื่อม 1/3 รอบ หรือ crossfade smoothstep · prewarm
- Soft particle fade 0.5–2 unit (ต้องมี depth · ปิดบน low-end) · distance fade ใกล้ 0–2 m ไกล 50–100 m + หดขนาด
- Time: gameplay VFX ใช้ scaled time · UI ใช้ unscaled · **ห้ามผสมใน effect เดียว** · เทส 0.25× / 0.5× / 1× / 2×
- Sort เฉพาะที่จำเป็น (< 1000) · additive ไม่ต้อง sort · particle ใหญ่ที่กินความลึกไม่มีวัน sort ถูก
- ตั้ง bounds ให้ cull นอกจอ · pool/recycle emitter · ล้างทิ้งเมื่อ parent ตาย

## 7. Roblox-specific

- `ParticleEmitter`: `Rate` + `Lifetime` → จำนวนอยู่ ≈ Rate × Lifetime · `:Emit(n)` สำหรับ burst (ต่อ hit) · `Enabled=false` + Emit ดีกว่าเปิดค้าง
- `LightEmission` 1 = additive · 0 = alpha · `LightInfluence` 0 สำหรับ energy · `Brightness` > 1 ดัน bloom
- `Texture` ≤ 1024 · flipbook ผ่าน `FlipbookLayout`/`FlipbookMode`/`FlipbookFramerate` · ใส่ `Squash`, `RotSpeed`, `Drag`, `Acceleration`, `Transparency`/`Size`/`Color` เป็น `NumberSequence` ตาม lifetime (ไม่คงที่)
- `Trail`/`Beam` สำหรับ slash/laser · ปรับ `Lifetime` ≤ 0.3 s · `WidthScale` taper · `MinLength`
- ไม่มี distortion/soft particle จริง → ใช้ `Highlight`/glow/`Bloom` post-effect · `Bloom` คุมด้วย `Lighting` ระวังทั้งฉากฟุ้ง
- สร้างบน client (`VFX` module) จาก event server เดียว ไม่ replicate instance ทีละตัว · เอฟเฟกต์ที่ติดตัว/ค้างและขึ้นพร้อมกันเยอะ = server marks, client draws (roblox-game-dev SKILL.md §6.5: tag จาก server · particle ทุกชิ้น · mesh เฉพาะใกล้กล้อง · pool · งบแอนิเมชัน) · ลบด้วย `Debris:AddItem` หรือ `task.delay` + `Destroy` · quality tier ตาม `UserSettings().GameSettings.SavedQualityLevel` / `UserInputService.TouchEnabled`

## 8. Sharp edges

Critical: overdraw spiral · effect PC ส่งขึ้นมือถือ · distortion บนมือถือ · ไม่มี MaxParticles · spawn > 1000/s
High: additive บนควัน · alpha บนพลังงาน · ออกแบบด้วยสีอย่างเดียว · sort ทุกอย่าง · ไม่มี LOD · unscaled time ใน gameplay · compression default บน flipbook นุ่ม
Medium: lifetime คงที่ (หายใจ/seam) · flipbook sync กัน · gravity ไม่ตรง · inheritance 1.0 · ไม่มี anticipation · editor กับ build ไม่เหมือนกัน

## 9. Checklist

- [ ] Tier + MaxParticles ตั้ง · rate < 200/s · mobile variant ครึ่ง/1/4 ไม่มี distortion
- [ ] Overdraw วัดแล้ว (PC < 4×/8× · mobile < 2×/4×) · ไม่มี billboard > 10% จอ
- [ ] anticipation → action → follow-through 10/10/80 · hit frame ตรง anim/SFX · hitstop/shake มีสเกลและ slider
- [ ] Blend ตรงวัสดุ · อ่านออกใน grayscale และบนพื้นขาว/ดำ/สีเดียวกัน · เปิด grading
- [ ] lifetime ±20% · เฟรมเริ่มสุ่ม · speed ±20% · blending · loop seam เทส 0.5×
- [ ] scaled time · 0.25×–2× · pause/hitstop ถูก
- [ ] inheritance 0.3–0.7 · gravity ตรง · local/world ถูก · noise บน organic · color over lifetime
- [ ] bounds/cull · sort เฉพาะที่จำเป็น · emitter ถูก destroy
- [ ] flipbook ≥ 128 px · power-of-2 · padding · BC7/ASTC
- [ ] quality tier Ultra→Potato · core ไม่ถูกตัด · fallback sprite
- [ ] เทสบนเครื่องต่ำสุดใน build จริง · มือถือ 10 นาที · ฉากที่มีศัตรู/effect สูงสุดพร้อมกัน

## 10. เขียน prompt สั่งงาน VFX (2D flipbook / 3D mesh)

prompt ที่ล้มเหลวส่วนใหญ่ใช้คำคุณศัพท์ลอย ๆ ("ไฟสวย", "slash เท่") — ให้เขียนเป็น **spec 6 ข้อ** ทุกครั้ง:

1. **ใช้ตอนไหน** — trigger · อยู่นานกี่วิ · loop หรือ one-shot · ติดตัว (follow) หรือวางในโลก
2. **รูปทรง (silhouette)** — เห็นเป็นเงาดำแล้วต้องรู้ว่าคืออะไร (โค้งพระจันทร์เสี้ยว · ลิ้นไฟ 3 แฉก · hex · วงแหวนมีฟัน)
3. **ขนาด** — เป็น stud เทียบตัว R6 (สูง 5) / รัศมีดาเมจจริง (เช่น "กว้าง 8 = 2 เท่าตัว", "รัศมี = รัศมีดาเมจ")
4. **สีแยกชั้น** — core / mid / outer เป็น hex (ใช้ชุดสีใน style doc ของโปรเจกต์ (`docs/art-style.md`) · ธาตุใหม่ = เสนอแถวใหม่ให้ผู้ใช้ยืนยันก่อน)
5. **การเคลื่อนไหวแยกช่วง** — start → peak → fade พร้อมเวลา (anticipation 10 · action 10 · follow-through 80)
6. **สไตล์ + สิ่งที่ไม่เอา** — "ตาม style doc" + ห้ามอะไร (photoreal, glow ฟุ้งทั้งจอ, วงกลมแยกเป็นจุด ฯลฯ)

### Template 2D (flipbook / texture)

```
Flipbook VFX: [ชื่อ] สำหรับ Roblox ParticleEmitter
- Layout: 4x4 (16 เฟรม) หรือ 8x8 · 1024x1024 · พื้นดำล้วน (additive) หรือ PNG โปร่งใส (alpha)
- ทุกเฟรมอยู่กลาง cell ไม่ล้นขอบ · pivot กลาง · มี padding กัน bleed
- Timeline: เฟรม 1-3 ก่อตัว · 4-10 peak · 11-16 สลาย
- Shape: ... · Color: core ... mid ... edge ...
- Style: hand-painted Albion · ขอบคม · shading 2-3 step · ไม่มี noise ละเอียด
- ห้าม: gradient นุ่มแบบ photoreal · glow ฟุ้งทั้งภาพ · ตัวหนังสือ
```
พลาดบ่อยสุด = ไม่บอก grid / ไม่สั่งห้ามล้นขอบ cell → ได้ภาพที่ตัดเป็นเฟรมไม่ได้

### Template 3D (Blender mesh → Roblox)

```
3D VFX mesh: [ชื่อ] ทำใน Blender → FxMeshes ใน Roblox
- Mesh: [ทรง เช่น ribbon โค้ง 180° · prism 6 เหลี่ยม · วงแหวน 12 เหลี่ยมมีฟัน] · low-poly faceted · ≤ 3k tri/ชุด ≤ 6 MeshPart
- origin: [พื้นใต้เท้า / กลางกระสุน หัน −Y / เหนือหัว] · fx_ref = ขนาดอ้างอิง (รัศมีหรือความกว้าง)
- group การขยับ: [ชื่อ group] หมุน FxSpin ... องศา/วิ แกน ... · เต้น FxPulse ... · ขยาย FxGrow0→FxGrow1 · ลอย FxRise
- ชั้นสี: [Core/Mid/Outer ของธาตุ] · ชิ้นวัตถุ (เหล็ก ไม้ หิน) = ไม่เรือง
- In Roblox: [กระสุน / disc บนพื้น / เอฟเฟกต์ client ครั้งเดียว / ติดตัวศัตรู (สถานะ)] · อยู่นาน ... · จาง ...
- Preview: render ฉากที่มีตัวละคร R6 จริง + มอนสเตอร์ขนาดจริง มุมเฉียงบน 25° (third-person) — start/peak/end
```

### กระบวนการที่ใช้ได้ผล

1. **เขียน prompt ตามข้างบนทีละท่า** (โจมตีปกติ · ร่างเลเวล 5 · ร่างอัปเกรด · R · สถานะบนศัตรู) — ท่าที่เห็นบ่อยสุดก่อน
2. **ทำ preview ใน Blender ก่อนลงเกม** — สคริปต์สร้างฉากละท่า วางโมเดลตัวละครจริงของเกม + กล่องมอนสเตอร์ไว้เทียบขนาด → ภาพรวมเป็น contact sheet ให้ผู้ใช้ดูทีเดียว
3. **ดู render เองก่อนส่ง** แล้วแก้สิ่งที่อ่านไม่ออก: ของบังกันในฉาก · แฟลชใหญ่จนขาวทั้งจอ · โดมทึบเกิน · ชิ้นเหล็กสีมืดจมพื้นหญ้า (ยกค่าสี/ขยาย) · หางกระสุนกว้างเกินตัวกระสุน
4. **ผู้ใช้ยืนยัน → export** (ไฟล์รวม `<ชุด>_All.fbx` + `assemble_studio.luau` และแยกทีละตัว `models/vfx/<ชื่อ>/` — SKILL.md §2.5) → **ผู้ใช้ Import 3D เอง** แล้วรัน assemble
5. **เชื่อมโค้ด**: ชั้นสีทุกชั้นที่ export ต้องมี entry ใน config สีของ mesh (ไม่มี = ขึ้นสี default เช่น Neon ขาว) · ชื่อ template ลงทะเบียนใน config VFX · ทุกจุดมี fallback เมื่อยังไม่ import (ชิ้นเรียบ)
6. **แก้ทีละตัวแปร** — "เหมือนเดิมทุกอย่าง แค่ fade เร็วขึ้น 2 เท่า" · แนบภาพ reference พร้อมบอกว่าเอาส่วนไหน/ไม่เอาส่วนไหน

## 11. รอยฟัน / คลื่นดาบ สไตล์เส้น (strand) — วิธีทำที่ใช้ได้จริง

**รูปทรง**
- รอย 1 ครั้ง = ริบบิ้นโค้งบาง 3–4 เส้นชิดกัน (ห่าง ~0.2 stud, ระนาบเดียว, เอียงเท่ากัน) + เส้นมืดรอง 1 เส้น (ตัดกับพื้นสว่าง) · `strand_bm(R, W, a0, a1, …)`: ขอบนอกรัศมี R ความกว้าง `W·prof(t)` (ปลายแหลม หางบาง → หัวหนา peak ~0.6; คลื่นดาบสมมาตร peak 0.5)
- mesh เรียบ smooth · segs ~48 ต่อเส้น · nv 3 · **UV: U = ตามเส้น 0→1 · V = ขอบนอก 0 → ขอบใน 1** → texture (ไล่สีตามขวาง + ริ้วยาวตามแนวเส้น + จางที่ปลาย U) ไม่ยืดไม่แตกแม้เส้นยาว/สั้นต่างกัน · ห้ามพัน texture ก้อนเดียวบนแผ่นกว้าง/ทรงชาม (ภาพยืด)
- เส้นวัสดุเดียวกันที่ขยับพร้อมกัน → รวมเป็น MeshPart เดียว (`strand_bm(..., bm=bm)`) ประหยัด part
- ฟันหมุน 360° = แถบเดียวยาว ~300° ระนาบนอนแนวอก (SlashHeight + 0.6) · วงใหญ่ (R ท่าพิเศษ) → **สร้างที่รัศมีจริง** อย่า scale ทั้งชิ้น (แถบจะหนาเกิน)
- Tornado = เกลียวบนผิวกรวย (`helix_bm`: ขอบบนตามเกลียว ความกว้างลาดลงตามผิวกรวย) หลายชั้นหมุนคนละความเร็ว (`FxSpin` แกน "Y") · โปร่งพอเห็นตัวละคร

**Impact (ไม่มีฝุ่น/ควัน)**: `Glow` = แถบกว้างช่วงหัว texture ก้อนแสงนุ่ม (`T_<Name>Glow`, emission สูง) โผล่ 0.03 วิ อยู่ ~0.16 วิ · `Flash` = เส้นขาวบางที่ขอบนอกช่วงหัว อยู่ ~0.09 วิ

**จังหวะ (attribute ต่อชิ้น → module เล่น mesh FX ฝั่ง client อ่านแล้วเล่น)**
- `FxTurn` / `FxTurnTime`: หมุนเข้าจาก FxTurn องศา → 0 แบบ ease-out (ฟัน 70°/0.12 วิ · ฟันหมุน 360°/0.2 วิ) = ความรู้สึก "ฟาดผ่าน" — ไม่ใช่เกิดเป็นเสี้ยวแล้วขยาย
- `FxDelay` `FxLife` `FxFadeOut`: เหลื่อมเวลาต่อเส้นเล็กน้อย (0–0.03 วิ) · จางเข้า 0.03 วิ · จางออก ~0.12 วิ
- คลื่นวงกลม: ขยาย**เชิงเส้น**ด้วยความเร็วเดียวกับวงดาเมจ (ease-out ไม่ตรงขอบดาเมจ) · หมุนช้า ~200°/วิ · จาง 40% ท้าย
- คลื่นดาบพุ่ง: กว้าง ~60% ของรอยฟัน · ไม่มีหาง · เต็มความยาว 20% แรกของระยะ แล้วหดความยาว 100% → 20% + จางถึง ~15%

**ข้อจำกัด Roblox → วิธีแก้**
- ตัดความยาว mesh / mask ด้วย shader ระหว่างเล่นไม่ได้ · scale แกนเดียว = ทรงบิด → ทำหลายความยาวทรงเดียวกันไว้ (`Var1..8`) แล้ว crossfade 2 อันที่ใกล้สุดตามระยะ
- "วาดเส้นจากฝั่งหนึ่ง" ด้วยการหั่นชิ้นใช้ part เยอะมาก → ใช้การหมุนเข้า + จาง แทน (ผู้ใช้ยอมรับแล้ว)
- MeshPart ไม่เรืองแบบ emission ใน Blender → เช็กความสว่างใน Studio จริง (Bloom ของด่าน)

**ขั้นตอนทำงานกับผู้ใช้**
1. สร้างใน Blender ด้วยสคริปต์ (exec ต่อกันเป็น lib: v3 → v2 → legendary …) ฉากมีโมเดลตัวละครจริง + กล่องมอนสเตอร์ ขนาดตามค่าจริงในเกม (อ่าน config อาวุธ/สกิลก่อน)
2. แอนิเมชันใน .blend จำลองสิ่งที่ client จะทำ (keyframe ทุกเฟรม: หมุนเข้า, Fade node ใน material, location/scale) → ผู้ใช้เปิดกด Space ดูเอง
3. render ภาพนิ่งหลายมุม (หลัง 30° · บน 60° · ต่ำ 5°) + จังหวะต่าง ๆ → contact sheet · ดูเองก่อนส่ง (ของบัง, แสงขาวล้น, เส้นหนา/บางเกิน)
4. ผู้ใช้สั่งแก้เรื่องขนาด/ระยะ → ถ้าเป็นค่าในเกม (เช่นรัศมี R) แก้ config จริงด้วย แล้วอัปเดต docs


## 12. ไฟ 3D มีกระดูก + ไฟล์ preview หลายฉาก — บทเรียนจากงานจริง

**เปลวไฟที่ "เหมือนไฟจริง" (ผู้ใช้ปฏิเสธการยืด/หดทั้งก้อน)**
- ลิ้นไฟ 1 ลิ้น = mesh 3D ทรงหยดยาว (หมุนรอบแกนโค้ง หน้าตัดเป็นลอน) + โซ่กระดูก **ข้อต่อ NB+1 ข้อ** (หัวกระดูก = ข้อที่ t = k/NB) · weight ตามตำแหน่งตามความยาว (attribute `fx_t`/`fx_id` ตอนสร้าง mesh) ผสม 2 ข้อที่ติดกัน
- ท่า: หมุน X/Z ทุกข้อ = คลื่น sine 2 ความถี่ phase เลื่อนทีละข้อ (คลื่นวิ่งจากฐานขึ้นปลาย) แอมป์โตขึ้นที่ปลาย · ปลายยืด = **เลื่อน 2 ข้อสุดท้ายตามแกนกระดูก** (Roblox Bone ย่อ/ขยายไม่ได้ ห้ามใช้ scale) · "แลบ": ยืดเร่ง 0.24 วิ → ขาดดีด → ค่อยคืน แล้วปล่อยหยดเปลวลอยขึ้น (ความเร็วต้น + แรงลอยตัว + แรงต้าน + ส่าย + หดหาย)
- **วนไร้รอยต่อ**: ความถี่ทุกตัวปัดเป็นจำนวนเต็มเท่าของ 1/LOOP · เหตุการณ์แลบจบก่อน LOOP · fcurve ใส่ CYCLES
- ผู้ใช้ชอบจังหวะช้า: คลื่นหลัก ~1.1–1.7 Hz (ลิ้นใหญ่) / 1.8–2.6 Hz (ลิ้นเล็ก) · แลบทุก 1–2 วิ · แกนในสว่าง/หรี่ช้า ~1 วิ (ไม่ใช่กะพริบ)
- สูตรท่าต้องมี **ที่เดียวต่อฝั่ง** และตรงกัน: Blender `flame_pose` ↔ Luau `pose()` ของ module ขยับ Bone · ค่าสุ่มต่อลิ้น (ความถี่ phase เวลาแลบ) export เป็น attribute ของ Bone ข้อแรก — ไม่ส่งเป็น keyframe

**ความโปร่ง 2 ชั้นซ้อน (แกน + ชั้นนอก)**
- 2 object โปร่งที่ origin เดียวกัน → engine เรียงลำดับสลับไปมา = แกน "ติด/ดับ" · แก้ด้วย Dithered/Hashed = เป็นเม็ด โดยเฉพาะตอนจาง → **ห้าม**
- ที่ใช้ได้: Blender = object เดียว 2 ช่องวัสดุ (วาดตามลำดับช่อง แกนก่อน) · Roblox = MeshPart เดียว + **texture atlas** (แกนครึ่งบน ชั้นนอกครึ่งล่าง เว้นขอบ ~0.01 กันสีซึม · ลำดับหน้า แกนก่อน) — MeshPart มีได้วัสดุเดียว import หลายวัสดุจะถูกแยกชิ้น

**ไฟล์ preview (.blend) ที่เล่นลื่น** — ครั้งแรกทำ 2,700 object / วัสดุมี keyframe 1,600 อัน → คำนวณฉากได้ ~24 fps (คอขวด CPU ไม่ใช่ GPU)
- ของซ้ำ = **Collection Instance** ของ template (instance_offset = ตำแหน่ง root) · วัสดุใช้ร่วม · จาง = keyframe custom prop `["fx_alpha"]` บน instancer → shader อ่าน **Attribute node แบบ INSTANCER** (ไม่ได้ instance = อ่านจาก object เอง) · **ห้าม copy วัสดุต่อชิ้นเพื่อทำจาง**
- กระดูก/หยดเปลวมีแค่ใน template · แยกแต่ละท่าเป็น Scene ของตัวเอง · Collection ที่ exclude ไว้ยัง instance ได้ และ armature ที่อยู่นอก scene ยัง deform ได้
- **เอฟเฟกต์ครั้งเดียวที่เกิดซ้ำเยอะ (ระเบิดเป็นร้อยจุด, hit ทุกเส้น) ห้าม copy object ต่อครั้ง** (`burst()` copy ชิ้น + keyframe = ฉากจริง 4,961 object 48 ms/เฟรม) → **Geometry Nodes 1 object ต่อชนิด**: จุดละครั้ง (attribute `t0`/`sc`/`rz`) · Instance on Points ชิ้นของ template · Scene Time คำนวณขยาย/จาง/ลอยตาม Fx* · Store Named Attribute `fx_alpha` ที่ domain Instance (วัสดุ Attribute INSTANCER อ่านได้) → ~4 ms/เฟรม
- **ทาง/รอยยาวต่อเนื่องบนพื้น ห้ามวางท่อนสั้นมาต่อกัน** (ดูเป็นชิ้น ๆ ไม่โค้ง) → mesh ชิ้นเดียวตามเส้นทาง แบ่งถี่ (~0.4 stud) · UV U = ระยะทาง/ความยาว tile + texture วนไร้รอยต่อแกน U (noise ความถี่จำนวนเต็ม / Voronoi วนขอบ) · เปิดตามเวลาด้วย mask shader (attribute ต่อ vertex = เวลาที่ผ่าน เทียบค่าที่ keyframe บน object) · ในเกมค่อยแปลงเป็นท่อน MeshPart/Beam ต่อตามทาง
- armature ทุกตัวใส่ collection ที่ซ่อนใน viewport (ไม่งั้นเห็นเส้นดำเต็มฉาก) — deform ยังทำงาน
- หลาย Scene: **compositor node group แยกต่อ scene** (`CompositorNodeRLayers.scene` ต้องชี้ scene ตัวเอง ไม่งั้นภาพ render เป็นของ scene อื่น) · render ด้วย `bpy.ops.render.render(write_still=True, scene=name)` · **render ใน call ที่สร้าง scene ใหม่ animation ของ scene นั้นยังไม่ถูกประเมิน → render แยกอีก call**
- `bmesh.ops.create_uvsphere(calc_uvs=True)` ต้องสร้าง UV layer ใน bmesh ก่อน ไม่งั้นไม่มี UV (texture ไม่ขึ้นแบบเงียบ ๆ)
- `bpy.ops.object.mode_set` หลัง `read_homefile` ต้องใช้ `context.temp_override(window, screen, view_layer, active_object, …)`
- เทสต์การขยับ: render หลายเฟรมเป็น contact sheet ดูเอง (เทียบเฟรมติดกันหา "ติด/ดับ" / เฟรมช่วงจางหาเม็ด) ก่อนส่งผู้ใช้

**ส่งเข้า Roblox**
- FBX ชุดเดียว: ชิ้นนิ่ง (bake ท่าพัก, recenter) + ชิ้น skinned (mesh รวม + armature สำเนา ชื่อกระดูกมี prefix ต่อ asset · `use_armature_deform_only` · `add_leaf_bones=False` · pose REST) · ตั้งชื่อ MeshPart = `<Asset>_<Part>` ให้ assemble หาเจอ
- assemble: เก็บ Bone ใต้ชิ้น (ถ้า import วางไว้ที่อื่น ย้ายมาโดยคงตำแหน่งเทียบชิ้นเดิม) · ใส่ attribute ท่าที่ Bone ข้อแรก · tag ชิ้น · รายงานจำนวน Bone (0 = import ใหม่ Rig Type = Custom)
- ขยายชิ้น skinned ต้องขยาย `Bone.Position` ตาม (เท่ากันทุกแกน) · ยืดแกนเดียวไม่ได้ → ทางไฟวางชุดเต็มขนาดเรียงซ้อนแทนการยืด · ระยะเลื่อนข้อใน client คูณ `Size/MeshSize`
- ภาระ: Bone.Transform ทุกเฟรมแพง → hz 30 · เฉพาะชิ้นใกล้กล้อง ≤ `maxActive`
- mesh จาก toolbox (ของคนอื่น) อ่าน geometry ไม่ได้ (`CreateEditableMeshAsync` = no permission) → สร้างทรงใหม่ใน Blender ตามภาพ

- **Roblox ซ่อนหน้าหลังเสมอ แต่ Blender (EEVEE) โชว์ 2 ด้าน** → ใน Blender ดูปกติ เข้าเกมแล้วหาย: แผ่นพื้นที่ normal ชี้ลง (ทางไฟ, วง Nova) มองจากบนไม่เห็นเลย · ริบบิ้นเกลียวเห็นครึ่งเดียวจนจาง — export ต้องทำชิ้นเปิด (มี edge non-manifold) เป็น 2 ด้าน: `bmesh.ops.duplicate` ทั้งชิ้น (vertex แยก) แล้ว `reverse_faces` ชุดสำเนา  · ชิ้นที่ตั้ง backface culling ใน Blender แล้ว (เปลว atlas) ไม่ต้อง · เช็คก่อน export: นับ face normal ขึ้น/ลง + non-manifold edge
- **skinned mesh หนัก** (เปลว burn 6,720 tris 105 กระดูก · ทางไฟ 45 กระดูก/ชุด × หลายชุด × ท่อนไฟ 150 ท่อน = เกมกระตุก) → จำกัดทั้งเกมด้วยเพดาน config (server นับ tag ใน workspace · เกิน = ทางไฟมีแต่พื้น / ไฟติดตัวเป็น particle) · client ขยับแค่ `maxActive` ชิ้นใกล้กล้อง · เอฟเฟกต์กระทบที่ยิงถี่ใส่ `max` ต่อชนิด (เล่นพร้อมกันได้กี่อัน)

**เครื่องมือ (Cowork)**
- `device_commit_files` อาจเขียน**เวอร์ชันเก่า**ของไฟล์ที่เคย Write ไว้ใน outputs → copy เป็นชื่อใหม่ทุกครั้งก่อน commit แล้ว grep ยืนยันบนเครื่อง · หรือแก้ตรงบนเครื่องด้วย python ใน device_bash (อย่าสลับสองแบบกับไฟล์เดียวกัน — ไฟล์ฝั่ง container จะเก่า)
- ห้าม `git stash` ในโฟลเดอร์ที่เชื่อมไว้ (ลบ lock ไม่ได้ → ค้าง `index.lock`) · stylua/selene/luau-lsp ไม่มีใน VM → โหลด binary รุ่นตาม `rokit.toml` แล้วรัน (roblox-game-dev `field-notes.md`)
