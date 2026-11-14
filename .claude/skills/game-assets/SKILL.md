---
name: game-assets
description: มาตรฐานการทำ asset เกมแบบที่สตูดิโอใช้จริง — 3D model ใน Blender (topology, tri budget, UV, PBR, LOD, export), rigging + animation, real-time VFX (particle, flipbook, timing, overdraw), SFX/audio (loudness, format, variation, voice limit) และ limit ของ Roblox ใช้ทุกครั้งที่สร้าง รีวิว หรือสั่งงาน asset: โมเดล ตัวละคร อาวุธ ฉาก เอฟเฟกต์ เสียง แอนิเมชัน — engine ไหนก็ได้ (Roblox/Unity/Unreal/Godot)
---

# Game Assets — Blender · Rig/Anim · VFX · SFX

ไฟล์นี้เป็น **router** — อ่านเฉพาะ reference ที่ตรงกับงาน ไม่ต้องอ่านทั้งหมด

## 0. ก่อนทำ asset ใด ๆ ตอบ 4 ข้อ

1. **ใช้ที่ไหน / เห็นใกล้แค่ไหน** — hero (ตัวเอก/อาวุธในมือ) · gameplay (ศัตรู prop ใกล้) · background → กำหนด budget ทันที
2. **แพลตฟอร์มต่ำสุด** — mobile ตัดทุกอย่างครึ่งหนึ่งถึง 1/4 จาก PC · Roblox = คิดแบบ mobile เสมอ
3. **ต้องขยับไหม** — static / rigged / animated → กำหนด topology, bone, export
4. **อ่านออกใน 0.2 วินาทีไหม** — silhouette (โมเดล) · shape-timing-color (VFX) · transient (เสียง) ถ้าไม่ผ่านตั้งแต่ร่าง ไม่ต้องลงรายละเอียด

## 0.5 สไตล์ภาพ — ต้องชัดก่อนลงมือ

ก่อนสร้างหรือสั่งงานโมเดล/VFX ชิ้นใหม่:

1. **เช็ก style doc ของโปรเจกต์ก่อน** — ปกติอยู่ `docs/art-style.md` · มีแล้ว → ยึดตามนั้น **ไม่ต้องถามซ้ำ** ถามเฉพาะสิ่งที่ doc ยังไม่ครอบคลุม (เช่น ธาตุ/ชุดสีใหม่ ประเภท asset ใหม่)
2. **ไม่มี doc หรือ doc ไม่ครอบคลุม → ถามผู้ใช้จนชัด ห้ามเดาแล้วเริ่มทำ** (AskUserQuestion ทีละชุด 1–4 ข้อ จนตอบครบ):
   - reference: เกม/ภาพอ้างอิง 1–3 อัน + สิ่งที่**ไม่เอา**
   - ระดับความสมจริง: photoreal / semi-real / stylized / cartoon
   - รูปทรง: smooth / low-poly faceted / blocky-voxel · silhouette หนาหรือเพรียว
   - สี: อิ่ม/หม่น · palette หรือชุดสีหลัก · มี outline/ขอบเข้มไหม
   - แสง: glow/bloom · emissive · เงา
   - texture: hand-painted / palette / PBR / flat color
   - มุมกล้องและระยะที่ผู้เล่นเห็น
   - (VFX) การเคลื่อนไหว: สั่น/ลอย/timing · ควันมากน้อย · particle หรือ mesh
   - budget / แพลตฟอร์มต่ำสุด
3. **ทำ preview เล็กก่อน** (ภาพนิ่ง 1–2 มุม หรือ 1 ชิ้นตัวอย่าง) ให้ผู้ใช้ยืนยัน แล้วค่อยทำชุดเต็ม
4. **ยืนยันแล้ว → เขียนลง style doc** (ไม่มีให้สร้าง `docs/art-style.md`) พร้อม path ภาพอ้างอิง + prompt template — ครั้งต่อไปจะได้ไม่ต้องถามซ้ำ

## 1. Routing

| งาน | อ่าน |
|---|---|
| โมเดล prop / อาวุธ / ฉาก / ตัวละคร ใน Blender · topology · UV · texture · LOD · export | `references/3d-models.md` |
| ใส่กระดูก · weight paint · ทำ/ส่งออกแอนิเมชัน · loop · root motion · attack timing | `references/rigging-animation.md` |
| particle · hit/explosion/magic effect · flipbook · trail/beam · screen shake · performance VFX | `references/vfx.md` |
| เขียน prompt / spec สั่งงาน VFX 2D (flipbook) หรือ 3D (Blender mesh) · preview → export → เชื่อมโค้ด | `references/vfx.md` §10 |
| รอยฟัน · คลื่นดาบ · ฟันหมุน · tornado ของท่าโจมตีด้วยอาวุธ (สไตล์เส้น/strand · texture ไม่ยืด · หมุนเข้า · หดตามระยะ) | `references/vfx.md` §11 (+ style doc ของโปรเจกต์) |
| ลูกไฟ/เปลวไฟ 3D ที่ขยับแบบไฟจริง (กระดูก + คลื่น) · skinned mesh → Roblox Bone · ไฟล์ preview .blend หลายฉากที่เล่นลื่น · ปัญหาที่เจอแล้ว (โปร่งสลับลำดับ, compositor, UV sphere, toolbox mesh) | `references/vfx.md` §12 |
| เสียง SFX / UI / ambience / music · loudness · format · variation · mixer | `references/sfx.md` |
| ค่า limit ของ Roblox (mesh, texture, audio, particle, animation) + วิธี import | `references/roblox-limits.md` |
| เขียน/แก้สคริปต์ Blender Python (bpy · bmesh · modifier · armature/keyframe · render preview/icon · API ที่เปลี่ยนใน 4.4+/5.x) | `references/blender-python.md` (+ reference ของชนิด asset นั้น) |
| **ตัวละคร R6 แบบบล็อก** (ร่าง 6 ชิ้น · หมวก/ฮู้ด · สายสะพาย/ผ้าพาด/สร้อย/เข็มขัด · ปก/ลายเสื้อ · เช็ก 360°) | `references/class-models-r6.md` |
| ตัวละคร/class model R15 + ชุดเกราะ: Blender → 3D Importer → ใส่บนตัวผู้เล่น (สเกล, สเปก rig, palette texture, ReplaceBodyPartR15, บังคับขนาด/แอนิเมชัน) | `references/roblox-character-pipeline.md` (+ `3d-models.md`) |

## 2. กฎที่ใช้ร่วมทุกประเภท

- **ตั้งชื่อ**: `Prefix_Name_Variant_Suffix` ไม่มีช่องว่าง/อักขระพิเศษ ≤ 64 ตัว · ห้าม `Final/New/Test/Copy/(1)` · prefix: `SM_` static mesh · `SK_` skinned · `T_` texture (`_D _N _R _M _AO _E`) · `M_` material · `A_` animation · `FX_` effect · `S_` sound
- **หน่วย**: 1 Blender unit = 1 m · Roblox 1 stud ≈ 0.28 m (ตัวละคร R15 สูง ~5 stud) — ตัดสินใจสเกลครั้งเดียวแล้วเขียนไว้ใน docs · **แนะนำสำหรับ Roblox: 1 unit = 1 stud · หน้า −Y · Z ขึ้น** (ดู `roblox-character-pipeline.md` §1)
- **Apply transforms ก่อน export เสมอ** (scale 1,1,1 · rotation 0,0,0) ทั้ง mesh และ armature
- **ทำ LOW ก่อน** แล้วค่อยเพิ่ม — asset ที่ออกแบบที่ budget สูงแล้วลดทีหลังจะพัง
- **ทดสอบใน engine จริง บนเครื่องต่ำสุด** ไม่ใช่ใน viewport ของ Blender/DCC
- **ทุก asset มี off-switch/quality tier** (VFX ลดชั้น, LOD, เสียง virtualize)
- Source file (.blend/.spp/.wav 24-bit) เก็บแยกจากไฟล์ที่ import เข้าเกม · ไม่ commit ของ generated

## 2.5 ชุดโมเดลหลายตัว: ส่ง 2 แบบเสมอ (ไฟล์รวม + แยกทีละตัว)

ทุกครั้งที่สร้างหรือแก้โมเดลหลายตัว (ตัวละคร อาวุธ เกราะ มอนสเตอร์ ของในฉาก ฯลฯ) ให้ได้ **ทั้งสองอย่าง** — ที่อยู่จริงเขียนไว้ใน README ของโฟลเดอร์ asset ของโปรเจกต์:

1. **ไฟล์รวม — ไว้ import ทีเดียวทั้งชุด**: `<assets>/<ชุด>/` → สคริปต์สร้าง (`build_*.py`) · `.blend` รวม · `<ชุด>_All.fbx` (ไฟล์ละ ≤ ~150 mesh) · สคริปต์ประกอบใน Studio (`assemble_studio.luau`) · โฟลเดอร์ preview · README
2. **แยกทีละตัว — ไว้แก้ทีละโมเดล**: `<assets>/models/<หมวด>/<ชื่อ>/` → `<ชื่อ>.blend` (palette + สคริปต์ export ฝังในไฟล์) · `<ชื่อ>.fbx` · `<ชื่อ>.json` (ตำแหน่ง/offset จาก export) · `assemble.luau` · `preview.png`

กติกา:
- **โฟลเดอร์แยกทีละตัว = ต้นฉบับที่ผู้ใช้แก้** · ไฟล์รวมเป็น snapshot — ก่อนสร้างไฟล์รวมใหม่ทับ เช็กก่อนว่าผู้ใช้แก้ .blend รายตัวไว้ไหม (เทียบเวลาแก้ไข) ถ้ามี ให้ถามก่อน หรือรวมจากรายตัวแทน · ห้ามเขียนทับโฟลเดอร์รายตัวที่มีอยู่แล้ว
- แก้โมเดลตัวเดียว → แก้ที่ .blend รายตัวแล้ว export ตัวนั้น ไม่ต้องสร้างไฟล์รวมใหม่
- ตำแหน่งที่ assemble ใช้ต้องมาจาก export (json) เสมอ ไม่พิมพ์มือ · offset ที่โค้ดต้องใช้ (จุดจับอาวุธ ฯลฯ) ใส่เป็น attribute บนโมเดล — โค้ดอ่าน attribute ก่อน config
- พิกัด/origin ของแต่ละชนิด + Custom Properties ที่สคริปต์ export อ่าน → เขียนใน README ของโฟลเดอร์ asset ครั้งเดียว

## 2.6 สไตล์ VFX ต่อหมวด — ยืนยันแล้วเขียนลง style doc

- แต่ละหมวด (ท่าโจมตีด้วยอาวุธ · ธาตุ · สถานะ · ของในฉาก) อาจคนละสไตล์ (เช่น รอยฟันแบบเส้น strand vs ธาตุแบบ low-poly faceted) — ยืนยันกับผู้ใช้ทีละหมวด เลือก**ต้นแบบ 1 ตัว** ให้ตัวอื่นทำโครงเดียวกัน แล้วเขียนลง `docs/art-style.md` (รวมรายการที่ผู้ใช้**ไม่เอา**)
- ส่งให้ผู้ใช้ดู: **ภาพนิ่ง contact sheet + ไฟล์ .blend ที่มีแอนิเมชัน (กด Space)** — ไม่ต้องทำวิดีโอ เว้นแต่ขอ · ดู render เองก่อนส่งทุกครั้ง

## 2.7 เอฟเฟกต์ที่ขึ้นพร้อมกันเยอะ = client วาด + LOD

- เอฟเฟกต์ที่ติดตัว/ค้างบนพื้นและขึ้นได้หลายสิบชิ้น (ไฟติดตัว สถานะ วงบนพื้น) **ห้าม server clone mesh ใส่ทุกชิ้น** → server ติด tag/attribute · client วาด (roblox-game-dev SKILL.md §6.5)
- ออกแบบ asset เป็น 2 ชั้นเสมอ: **ชั้นเบา** (particle — ทุกชิ้นต้องเห็น แม้ไกล/นอกโควตา) + **ชั้นหนัก** (mesh/skinned — เฉพาะชิ้นใกล้กล้อง) · ชั้นเบาอย่างเดียวต้องยังอ่านออกว่าเป็นเอฟเฟกต์อะไร
- mesh ชั้นหนักต้องจัดขนาดใหม่ได้ทั้งชิ้น (ขนาด + `Bone.Position`) เพราะชิ้นถูกใช้ซ้ำจาก pool · ท่าที่ขยับด้วยโค้ดต้องทนการขยับแบบเฟรมห่าง (ไกล ๆ ขยับ ~8 ครั้ง/วิ)

## 3. Output contract เมื่อส่งงาน asset

1. **Spec** — ชนิด / budget (tri, texture, particle, voice) / แพลตฟอร์มเป้าหมาย
2. **ไฟล์** — ชื่อตาม convention · format · ที่อยู่ในโปรเจกต์
3. **Import settings** — scale, axis, compression, loop, attenuation
4. **ที่ต้องตรวจในเกม** — ระยะมอง, พื้นหลังสว่าง/มืด, จอ 720p, เครื่องมือถือ
5. **Checklist ของ reference นั้น** ติ๊กครบ
6. **ทั้งไฟล์รวม + โฟลเดอร์แยกทีละตัว** ตามข้อ 2.5 ถ้าเป็นชุดหลายตัว (บอกผู้ใช้ทั้งสองที่)

## 4. Anti-patterns ที่เจอบ่อยสุด

R15 ที่มี `_Att`/HumanoidRootPart mesh ติดไปใน FBX / weld part ใหม่ทับ avatar แทน ReplaceBodyPartR15 / n-gon / ไม่ apply scale / origin ไม่อยู่ที่พื้น / UV ทับกันแล้ว bake / normal map ผิดฝั่ง (DirectX↔OpenGL) / bone > 4 influence / rest ≠ bind pose / loop ไม่ seamless / particle ไม่มี MaxParticles / distortion บนมือถือ / additive บนควัน / เสียงไม่มี variation / WAV ดิบใน build / ทุก asset ทำที่ budget PC แล้วหวังว่ามือถือจะไหว

## แหล่งอ้างอิงหลัก

- skills จริงที่ใช้งานใน omer-metin/skills-for-antigravity: `3d-modeling`, `rigging-animation`, `animation-systems`, `vfx-realtime`, `game-audio`, `game-ui-design`, `motion-design`
- Game-ready asset checklist (Blender→engine): https://www.strayspark.studio/blog/game-ready-asset-checklist-blender-2026
- Roblox docs: modeling specs · texture specs · audio assets (ลิงก์ใน `references/roblox-limits.md`)
- Audiokinetic — Mastering a game with Wwise (loudness targets): https://audiokinetic.com/en/mastering-a-game-with-wwise-part1
