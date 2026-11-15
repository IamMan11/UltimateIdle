# Asset Plan — ด่าน 1 (ทุ่งหญ้า) · hero · monster · boss · VFX · icon

แผนงาน asset ที่เหลือ เรียงตามลำดับทำ · อัปเดตสถานะที่ไฟล์นี้ทุกครั้งที่จบขั้น (ติ๊ก `[x]`) · งานค้างสั้น ๆ อยู่ `docs/STATE.md` · สไตล์ที่ยืนยันแล้วอยู่ `docs/art-style.md`
อัปเดตล่าสุด: 2026-11-15

## 0. เริ่ม session ใหม่ต้องทำอะไรก่อน

1. ขอสิทธิ์โฟลเดอร์ `D:\UltimateIdle` และ `D:\BlenderForUltimateIdle` (ไม่ต้องขอ `D:\blendermodel\models` — ดูข้อห้ามด้านล่าง)
2. อ่าน `CLAUDE.md` → `docs/STATE.md` → `docs/art-style.md` → ไฟล์นี้ → `.claude/skills/game-assets/SKILL.md` (+ reference ที่ตรงงาน)
3. Blender: ถ้า Blender MCP ต่อไม่ได้ ใช้ `pip install bpy --break-system-packages` ใน cloud container (ได้ 5.3) แล้วรันสคริปต์ build ที่นั่น → `device_commit_files` กลับเครื่อง

## กติกาที่ผู้ใช้ย้ำ (ห้ามพลาดซ้ำ)

- **ห้ามลอกโมเดลโปรเจกต์เก่า** (`D:\blendermodel\models`) — ห้าม append mesh/texture มาเปลี่ยนสีหรือเติมชิ้น · ทุกตัวออกแบบใหม่จากศูนย์ (ชุด ผม หน้า อาวุธ)
- สไตล์: stylized กึ่งสมจริง ไม่สมจริงจัด · สเปกต่ำ · หญ้าบาง · หินขรุขระลายแตกจาง · hero = R6 บล็อกซ้อนชั้น + หน้า 2D
- **ทำต้นแบบ 1 ชิ้น/ชุดเล็ก → ส่งภาพให้ยืนยัน → ค่อยทำชุดเต็ม** ทุกหมวด (monster, boss, VFX, icon) · ดู render เองก่อนส่งทุกครั้ง
- ห้ามมี **model ซ้อน** (หน้า coplanar ทับกัน) — สคริปต์ hero มีตัวตรวจ `coplanar()` + ตัวดันชิ้นทับ 0.02 อัตโนมัติ ต้องได้ `OVERLAPS 0` · ทำแบบเดียวกันกับ monster ที่สร้างจากกล่อง
- หน้าตัวละครต้องตรงบุคลิก (Warrior = หนักแน่น ดุ ไม่ใช่หน้าเศร้า)
- บอกจุดที่ยังไม่เรียบร้อยตรง ๆ ทุกครั้งที่ส่งงาน

## สถานะตอนนี้

| หมวด | สถานะ | ไฟล์ |
|---|---|---|
| ฉากทุ่งหญ้า | **v2 low-poly 2026-11-15** (ผู้ใช้ไม่เอาแบบเดิม): 18 ชิ้น 4.7k tri · ทางเดินดิน · clump/thicket · อยู่ในเกมแล้ว รอผู้ใช้ดู · (เดิม:) ต้นแบบยืนยันแล้ว (รอบ 3) · **ชุดจริง (kit) เสร็จ 2026-11-15 รอผู้ใช้ดู**: `stage01_meadow\kit\` 17 ชิ้น 19k tri · ยังไม่ import | `D:\BlenderForUltimateIdle\stage01_meadow\` |
| Slime (ต้นแบบ) | ยืนยันแล้ว — ยังไม่มีกระดูก/แอนิเมชัน ยังไม่ export | ไฟล์เดียวกับฉาก |
| Hero 4 class v3 | **ผ่านแล้ว 2026-11-15** (รอบเก็บงาน) · โล่ Warrior ทำใหม่ตามภาพอ้างอิงของผู้ใช้ (โล่เหล็กทรง kite กางเขนแดง ถือมือซ้าย ขนาดเท่าลำตัว) — โล่ใหม่รอผู้ใช้ดู · tri 3.4k–5.0k · ยังไม่ export | `D:\BlenderForUltimateIdle\heroes\` (`build_heroes.py <out>`) |
| Goblin · Orc · Wolf | โมเดลรอบแรก **ผู้ใช้โอเคแล้ว 2026-11-15** · ยังไม่ rig/export · tri 1.9k / 2.4k / 1.4k | `D:\BlenderForUltimateIdle\monsters\` |
| Boss: มนุษย์หมาป่า · Orc leader · Dirt golem | โมเดลรอบแรก **ผู้ใช้โอเคแล้ว 2026-11-15** · ยังไม่ rig/export · tri 2.5k / 3.5k / 2.6k · สเกล 1.45 / 1.6 / 1.75 | โฟลเดอร์เดียวกัน |
| VFX โจมตี (4 class + monster + boss) | ยังไม่เริ่ม — ตกลงแล้วว่า mesh 3D + particle | — |
| Icon ปุ่ม 32px pixel art | รอบแรก 16 อัน **ผู้ใช้โอเคแล้ว 2026-11-15** (`preview\icons_sheet.png`) · **อัปโหลด + ต่อ UI แล้ว 2026-11-15** | `D:\BlenderForUltimateIdle\icons\` (`build_icons.py <out>`) |
| นำเข้า Roblox + ต่อโค้ด | ยังไม่เริ่ม (โค้ดเกมยังใช้ placeholder) | — |

## ขั้นตอนที่เหลือ (ทำตามลำดับ)

### 1. Hero — ปิดงาน
- [x] 1.1 ผู้ใช้ยืนยันรอบเก็บงานแล้ว · เหลือให้ดูโล่ใหม่ของ Warrior (`heroes\preview\warrior_front.png`)
- [x] 1.2 render ตรวจรอบตัว 8 มุม + บน/ล่าง ท่ากางแขน ครบ 4 ตัว (`heroes\preview\<hero>_turnaround.png` · `_tools\turnaround.py`) — เจอ+แก้ 1 จุด: เพชรที่เข่า Warrior หน้าซ้อนแผ่นต้นขา (render ดำ) · ที่เหลือไม่เจอชิ้นซ้อน/ลอย
- [x] 1.3 exporter (เสร็จ 2026-11-15: copy แล้ว + แก้ 1 จุด = ชิ้นเรืองของ class เป็น Neon · FBX import กลับใน Blender ได้ครบ 9 ชิ้น + atlas ฝัง · **ยังไม่ได้ลองใน Studio**): ผู้ใช้อนุญาตให้ใช้ `D:\blendermodel\models\_tools\export_roblox.py` ถ้ายังใช้ได้และไม่มีปัญหา (ขอสิทธิ์โฟลเดอร์นั้นเฉพาะเพื่ออ่าน tool — **ห้ามแตะโมเดล**) · copy มาไว้ `D:\BlenderForUltimateIdle\_tools\` แล้วทดสอบกับ Warrior ก่อน · ใช้ไม่ได้ค่อยเขียนใหม่
- [x] 1.4 (ไฟล์รวมเสร็จ 2026-11-15: `heroes\Heroes_All.fbx` 37 mesh 16.8k tri + `heroes\assemble_studio.luau` ผ่าน `_tools\combine_heroes.py` · รอบเก็บงาน: วงแสงหนังสือ Healer ลงมาชิดหน้ากระดาษ · หัวรองเท้า Warrior ชิดกัน) (แยกทีละตัวเสร็จ: `models\heroes\<Warrior|Mage|Archer|Healer>\` ผ่าน `_tools\split_heroes.py` · README เขียนแล้ว · **เหลือ `Heroes_All.fbx` + assemble รวม — ทำหลัง 1.5 ผ่านกับ Warrior**) export: FBX ต่อตัว + ไฟล์รวม + json + `assemble.luau` (ชิ้น R6 6 ชิ้น + อาวุธ/ผ้าคลุม/ชิ้นเรือง แยก · `roblox_piece`/`roblox_part`/`roblox_glow`) · เขียน `README.md` ของโฟลเดอร์ asset (สเกล แกน origin Custom Properties)
- [x] 1.5 (**import แล้ว 2026-11-15** ผ่าน Open Cloud: hero 4 → `ServerStorage.ClassModels` · monster/boss 6 + Slime → `ReplicatedStorage.MonsterModels` · ฉาก → `ReplicatedStorage.StageKits.Meadow` · ตัวอย่างวางที่ `Workspace.StageDemo` (x=3000) · ต้นทางที่ import เก็บใน `ServerStorage._Imported` · ขนาด/texture/vertex color/ทิศ ตรง · ยังไม่มี animation ยังไม่ต่อโค้ด) (เดิม: Import 3D `models\heroes\Warrior\Warrior.fbx` Rig=None ลง Workspace → รัน `assemble.luau` → เช็กขนาดชิ้น/สี atlas/ทิศหน้า · assemble วางชิ้นแบบ Anchored ยังไม่ weld และเก็บที่ `ServerStorage.ClassModels` — ปรับตอน 1.7) import Studio (3D Importer) → ประกอบเป็น template R6 · ตรวจขนาด/หน้า/สี atlas ในเกมจริงที่ระยะกล้องเล่น
- [ ] 1.6 (**ผู้ใช้จะทำ animation ของ hero เอง 2026-11-15 — ท่าที่ผมทำ "ยังไม่ดี" อย่าเอาเข้าเกม** · ข้อมูลเดิมยังอยู่ใน `anims\Anims.json` เผื่ออ้างอิง) (ข้อมูลเสร็จ 2026-11-15: `anims\build_anims.py` → `Anims.json` + `build_keyframes.luau` (สร้าง KeyframeSequence ใน Studio, marker `Hit`) · hero: Idle Walk Attack Hit Death Cast Revive · ภาพตรวจ `anims\preview\` · **เหลือ: รันใน Studio + publish เอา id** · assemble ของ hero weld ชิ้นเข้ากับ part R6 แล้ว) แอนิเมชัน R6 ต่อ class: idle · walk · attack (ตรงจังหวะ hit ใน Sim) · skill cast · death/revive
- [x] 1.7 (ต่อแล้ว 2026-11-15 ไม่มี animation: `client/Battle/Rig.luau` ใช้ template จาก `ReplicatedStorage.HeroModels` / `MonsterModels` ตาม kind `H_<Class>` / `M_<Id>` · ไม่มี template = บล็อกเดิม (เช่น SkeletonArcher) · ฉาก: `Scenery.luau` `fromKit` + `Config/Scenery.luau` `Kit` · lint/type 0 error · Play: เท้าแตะพื้นทุกตัว) ต่อโค้ด: หาจุดที่ client สร้างตัว hero (อ่าน `docs/README.md` + `docs/debug-map.md` ก่อน) → ใช้ template ตาม `Heroes.luau` Id (`Warrior` `Mage` `Archer` `Healer`) · **ผู้ใช้ให้คงชื่อ `Archer` แบบเดิม** → โมเดล/ไฟล์ที่ชื่อ Ranger ให้ map เข้า class `Archer` (จะ rename ไฟล์เป็น Archer ตอน export ก็ได้)

### 2. ฉากทุ่งหญ้า — ทำของจริง
- [x] 2.1 (`build_meadow_kit.py <out>`: พื้น 4 tile 160×120 stud 2.4k tri/ชิ้น ต่อกันสนิทตามแกน X · เนินไกล 2 ชิ้น 640 tri · หิน 6 แบบ A–F 1280/320 tri · พื้นเรียบช่วง |y| < 22) แยกสคริปต์จาก `build_meadow_proto.py` เป็นชุดจริง: พื้นแบ่ง tile (≤ 20k tri/ชิ้น เป้า ≤ 5k) · หิน 19 ก้อน → เลือก 5–6 แบบใช้ซ้ำ · เนินไกลเป็นฉากหลัง
- [x] 2.2 (หิน: atlas เดียว 1024 `T_Meadow_Rocks_D/N/R` 6 ก้อนใช้ร่วม · **พื้น/เนิน/หญ้าใช้ vertex color แทน texture** — ไม่มีรอยต่อ tile ไม่กิน texture memory; ถ้าใน Studio สีไม่ขึ้นค่อย bake) bake texture (BaseColor + Normal + Roughness, 512–1024) สำหรับพื้น/หิน · 1 material/1 UV ต่อชิ้น
- [x] 2.3 (patch 8×8: Tall A/B 756 tri · Short 420 (lane) · Sparse 330 · Flowers 180 · ต้องตั้ง `DoubleSided = true` · demo ใช้ 175 patch รอบ lane กว้าง 200 stud ≈ 110k tri → เต็ม 640 stud ต้องวางเฉพาะช่วงที่กล้องเห็น + LowDetail ลดเหลือ Sparse) หญ้า: **ผู้ใช้เลือกกอ mesh รายละเอียดต่ำ** ("แค่หญ้า ไม่ต้องละเอียดจนกินทรัพยากร") → กอละ ≤ 15 tri · รวมหลายกอเป็น patch mesh เดียว (เช่น patch 8×8 stud ใช้ซ้ำ) ไม่วางทีละกอ · CanCollide/CanQuery/CastShadow ปิด · หนาแน่นเฉพาะใกล้ lane
- [ ] 2.4 ท้องฟ้า/แสง: ตั้ง Sky + Atmosphere + Lighting ใน Studio ให้ใกล้ภาพต้นแบบ (ไม่แก้ `default.project.json`) · จดค่าลง `art-style.md` §Lighting
- [ ] 2.5 import + วางตาม `src/shared/Config/Scenery.luau` / `Stages.luau` (อ่าน config ก่อน ว่าฉากเลื่อน/tile ยังไง) · ตรวจ lane เห็นเท้า · 720p · Device Emulator

### 3. Slime — ทำของจริง
- [x] 3.1 (`monsters\build_slime.py` → `models\monsters\Slime\` · 812 tri · กระดูก Root>Base>Body>Top) แยกเป็น `monsters\slime\` · rig 3–4 กระดูก (root · body · top) · ห้าม keyframe scale กระดูก (ยืด = เลื่อนตำแหน่ง)
- [x] 3.2 (Idle Move Attack(hit f9) Hit Death อยู่ใน `Slime.fbx` · ภาพตรวจ `anim_sheet.png`) แอนิเมชัน: idle (เด้ง) · move · attack · hit · death · loop ไร้รอยต่อ
- [ ] 3.3 (export แล้ว · เหลือ import + ตั้ง Material/Transparency ตาม `Slime.json`) export + import → `Monsters.luau` (`Scale`) · ตรวจความโปร่งซ้อนชั้นในเกมจริง

### 4. Monster ทั่วไป: Goblin → Orc → Wolf
ต่อ 1 ตัว: ร่างแบบ (สัดส่วน/สี/อาวุธ) → **ต้นแบบ 1 ตัว render หน้า+หลัง+ใกล้ → ผู้ใช้ยืนยัน** → rig + แอนิเมชัน (idle/move/attack/hit/death) → export → import → ใส่ config
**กติกา rig (ผู้ใช้ตัดสิน 2026-11-15):** ตัวที่ทำเป็น R6 ได้ → **R6 บล็อกแบบ hero v3** (ใช้ lib เดียวกับ `heroes/build_heroes.py`: `Hero`/`box`/`coplanar`) · ตัวที่เป็น R6 ไม่ได้ (slime · wolf) → **mesh เต็มตัวมีกระดูก**
- [ ] 4.1 Goblin — R6 สเกล 0.72 · โมเดลรอบแรกเสร็จ 2026-11-15 (`monsters\build_monsters.py` · `Monsters_All.blend` · `preview\monsters_sheet.png`) — **ผู้ใช้สั่งทำต่อเนื่องไม่รอยืนยันทีละตัว ยังไม่ได้ดู** · เหลือ rig + แอนิเมชัน + export + config · รอบเก็บงาน: กระบองใหญ่ขึ้น + ผิวเหลืองขึ้น + หมวกแดง (ให้แยกจากพื้นหญ้า)
- [ ] 4.2 Orc — R6 สเกล 1.12 · โมเดลรอบแรกเสร็จ (เหลือเหมือน 4.1)
- [ ] 4.3 Wolf — โมเดลรอบแรกเสร็จ: บล็อกแยกชิ้น Body/Head/ขา 4/Tail (rig = กระดูกต่อชิ้น weight แข็ง) · เหลือ rig + แอนิเมชัน + export
- 2026-11-15: export แยกตัวครบ (`_tools\split_monsters.py` → `models\monsters\<Name>\` · kind mob · origin ชิ้น = ข้อต่อ Motor6D) + แอนิเมชัน Idle Walk Attack Hit Death (boss เพิ่ม Cast Roar) ใน `anims\` · เหลือ import + publish + config
- **animation monster/boss/Slime อยู่ในเกมแล้ว 2026-11-15**: ไม่ใช้ animation asset — `shared/Config/MonsterAnims.luau` (สร้างจาก `anims\build_anims.py <models> <out> 0 <module>`) + `Rig.Animate` ตั้ง `Motor6D.Transform` / `Bone.Transform` ทุกเฟรม · `Playback.place` เลือก clip: Death > Attack (จัดให้ hit time ตรง event) > Hit > Walk > Idle · ยังไม่ใช้: Roar, Cast ของ boss
- budget ~1k–2.5k tri · texture 512 · ต้องอ่านออกบนพื้นเขียว (เลี่ยงเขียวล้วน)

### 5. Boss: มนุษย์หมาป่า → Orc leader → Dirt golem
- [ ] 5.1–5.3 (โมเดลรอบแรกเสร็จทั้ง 3 · เหลือ rig/แอนิเมชัน/export) มนุษย์หมาป่า · Orc leader · Dirt golem = ยืนสองขา → **R6** (ขยายสเกล + ชิ้นเสริมหัว/ไหล่/หาง) · ขั้นเดียวกับข้อ 4 แต่ใหญ่กว่า/ละเอียดกว่า (เป้า ≤ 5k tri) · ต้องต่างจากตัวธรรมดาชัด (ขนาด · silhouette · สีเด่น) · เพิ่มท่า: intro/roar · skill
- [x] 5.4 (ทำแล้ว 2026-11-15: boss อยู่ wave สุดท้ายอยู่เดิม · `Sim.pickBoss(rng, level)` สุ่มจาก boss ที่ปลดแล้ว · `Monsters.luau`: เพิ่ม Wolf + Werewolf/OrcLeader/DirtGolem แทน OgreKing · stylua/selene/luau-lsp 0 error · **ยังไม่ได้เล่นใน Studio** · สเตตัส boss ตั้งเอง ปรับได้ · `SkeletonArcher` ยังอยู่ใน config แต่ไม่มีโมเดลในแผน) กติกา boss (ผู้ใช้ตัดสิน 2026-11-15): **boss โผล่เฉพาะ wave 5 · สุ่มว่า level นี้เป็นตัวไหนใน 3 ตัว ไม่ตายตัว** → อ่าน `Stages.luau`/`Monsters.luau` + ระบบ spawn ว่าทำแบบนี้อยู่แล้วหรือยัง ถ้ายัง: สุ่มฝั่ง server ตอนเริ่ม level (seed จาก level ถ้าต้องให้ client เดาตรงกัน) · เพิ่ม 3 boss ใน config

### 6. VFX โจมตี
- [ ] 6.1 (ต้นแบบเสร็จ **รอผู้ใช้ยืนยันสไตล์**: `vfx\Slash_Proto.blend` กด Space · `vfx\preview\slash_sheet.png` · ริบบิ้น 4 เส้น + ขอบฟ้า + เส้นมืด + glow + flash · 1,280 tri 5 ชิ้น · หมุนเข้า 70° ใน 0.1 วิ จาง 0.2 วิ) อ่าน `references/vfx.md` (§10–12) · ต้นแบบ 1 ชุด: **ท่าฟันของ Warrior** → contact sheet + .blend → ผู้ใช้ยืนยันสไตล์ → เขียนลง `art-style.md` §VFX (สี core/mid/outer · จังหวะ · สิ่งที่ไม่เอา)
- [ ] 6.2 Warrior: slash · skill ตาม `Skills.luau`
- [ ] 6.3 Mage: ลูกพลังจากคทา + ระเบิดตอนโดน · skill
- [ ] 6.4 Archer/Ranger: ลูกธนู + หาง + hit · skill
- [ ] 6.5 Healer: แสง heal (HealAll) · Revive · Shield ตาม `Skills.luau`
- [ ] 6.6 Monster/Boss: hit ของแต่ละตัว + ท่า boss
- [ ] 6.7 ต่อโค้ด: **client วาด + LOD** (SKILL.md §2.7 · roblox-game-dev §6.5) — server ส่งแค่ event/attribute · ทุก emitter มี MaxParticles · ชั้นเบา (particle) + ชั้นหนัก (mesh)

### 7. Icon ปุ่ม 32px pixel art
- [x] 7.1 (20 อัน: Gold Ruby Inventory Boxes Forge Heroes Team Tree Rebirth Quests Shop Trade Daily Settings Skip Camera Bag View Watch Farm · ไม่มี tier ของ item ใน config จึงไม่ทำ) ไล่รายการปุ่มจริงจาก `src/client/UI/` (หน้า: Boxes Daily Forge HeroSelect Heroes Inventory Quests Rebirth Settings Shop Team Trade Tree + `Core/HUD.luau`) → ทำตารางรายการ icon ให้ผู้ใช้ตัด/เพิ่ม
- [x] 7.2 (ทำครบ 16 อันรอบแรกแทนต้นแบบ 4 · รอผู้ใช้ยืนยันสไตล์ · Team/Rebirth วาดใหม่แล้ว) ต้นแบบ 4 อัน (เช่น Inventory · Shop · Team · Settings) วาด 32×32 จริง ขอบคม จานสีจำกัด → ผู้ใช้ยืนยัน
- [x] 7.3 (upload 20 อันที่ ×4 เป็น Image asset 2026-11-15 · ไม่มี tier/สถานะ) ทำครบชุด + currency (gold/ruby) + tier/สถานะ ถ้าผู้ใช้เอา · export PNG (ขยายแบบ nearest ×4/×8) · อัปโหลด
- [x] 7.4 (2026-11-15: id อยู่ `src/shared/Config/Icons.luau` · `Widgets.Icon` / `Button` prop `icon` · HUD + แท็บกลุ่ม · Pixelated เฉพาะ ≥ 32px) ต่อ UI: `ImageLabel.ResampleMode = Pixelated` · เก็บ asset id ที่ `src/shared/Config/` หรือ Theme (ห้าม hard-code ในไฟล์ UI) · `stylua src/` + `selene src/`

### 8. ปิดงาน
- [ ] 8.1 เล่นจริงใน Studio: ระยะกล้องเล่น · 720p · Device Emulator มือถือ · นับ instance/tri รวมต่อฉาก
- [ ] 8.2 เขียน Output contract ต่อชุด (SKILL.md §3) · อัปเดต `art-style.md` (Budget · Lighting · Pipeline) · `STATE.md`
- [ ] 8.3 ย้าย/ลบโฟลเดอร์ `_old_*` ใน `D:\BlenderForUltimateIdle\heroes\` (ผู้ใช้ลบเอง หรือขอสิทธิ์ลบ)

## คำตอบของผู้ใช้ (2026-11-15) — ไม่ต้องถามซ้ำ

1. Hero รอบเก็บงาน **ผ่าน** · โล่ Warrior เปลี่ยนเป็นโล่เหล็กกางเขนแดงตามภาพอ้างอิง ถือ**มือซ้าย** ขนาด**เท่าลำตัว** (ทำแล้ว รอดู)
2. Monster/boss: **R6 ได้ให้เป็น R6** · ที่เป็นไม่ได้ (slime, wolf) = mesh เต็มตัวมีกระดูก
3. Exporter: ใช้ tool เดิมได้ถ้ายังใช้ได้และไม่มีปัญหา
4. หญ้า: กอ mesh รายละเอียดต่ำ
5. ชื่อ class: คง `Archer` แบบเดิม
6. Boss: เฉพาะ wave 5 · สุ่มตัวต่อ level

## คำถามที่ยังค้าง

- โล่ใหม่ของ Warrior ผ่านไหม
