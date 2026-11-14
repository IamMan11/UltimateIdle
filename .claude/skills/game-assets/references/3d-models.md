# 3D Models — Blender → Game

## 1. Budget (triangles)

| ชนิด | PC/console | Mobile / Roblox |
|---|---|---|
| Hero prop / อาวุธในมือ | 5k–20k | 1k–5k |
| Environment prop | 500–5k | 200–1.5k |
| Background / ไกล | 100–1k | 100–500 |
| ตัวละครหลัก | 15k–80k (AAA hero 80k–150k) | 5k–15k |
| NPC / ศัตรูทั่วไป | 10k–20k | 2k–5k |
| สถาปัตย์ modular | 100–2k | 100–1k |
| Collision mesh | 8–32 | 8–32 |

- Roblox: **≤ 20,000 tri ต่อ mesh** (hard limit) · เป้าจริงใช้ตารางคอลัมน์ขวา
- แบ่ง budget ตัวละคร: หัว/หน้า 25–30% · ลำตัว 20–25% · แขน 15–20% · มือ 15–20% · ขา 15–20%
- ความหนาแน่นลงที่: ข้อต่อ > silhouette > ใกล้กล้อง > รายละเอียดที่ normal map ปลอมไม่ได้ · "5k สะอาด ชนะ 3k รก"

## 2. Topology

- Quad ทั้งหมดบนสิ่งที่ deform · tri ได้เฉพาะ hard-surface ที่ตั้งใจ · **ห้าม n-gon** (triangulate ตอน export)
- ข้อต่อ: ≥ 3 loop (1 ที่จุดหมุน + ข้างละ 1) · งอ 180° ใช้ 5 loop · loop จุดหมุนต้องตรงกับ bone พอดี
- หน้า: ≥ 2 loop วงรอบตา · ≥ 3 loop แนวนอนรอบปาก · loop หน้าต้องไหลไปจบที่หู/คอ
- Pole (5-edge) วางที่แก้ม/ท้ายทอย/หลังมือ · **ห้าม**วางที่ข้อต่อ ปาก รอบตา
- Boolean: Exact solver · cutter ทะลุผ่านชิ้นงาน · หลัง boolean: ลบ n-gon → Merge by Distance 0.0001 → Delete Loose → เช็ค non-manifold → Shift+N recalc normals
- Hard-surface modifier order: Mirror → Array → Boolean → Bevel (Limit=Weight, width 0.02, segments 2) → Weighted Normal → Triangulate (เปิดเฉพาะ export)
- Floating detail (ร่องแผง): mesh แยก ลอย 0.001 เหนือผิว → bake ลง normal map
- ก่อน export: ไม่มี interior face · ไม่มี loose geometry · normal ออกนอก · watertight ถ้าเป็น Roblox

## 3. สเกล · origin · transform

- Scene Units = Metric · 1 unit = 1 m ตั้งแต่ไฟล์แรก · ประตูอ้างอิง 2.1 × 0.9 m
- Modular: ผนัง 4×3 m · พื้น 4×4 m · trim 4 m · ขอบอยู่บน grid · จำนวน vert ขอบที่ต่อกันต้องเท่ากัน
- Origin: prop = ก้นกลาง (จุดสัมผัสพื้น) · ผนัง = ก้นกลาง · พื้น = กลาง · ของหมุน = จุดหมุน · ประตู/หน้าต่าง = กลางช่อง
- `Ctrl+A → All Transforms` ก่อน export ทุกครั้ง · วางวัตถุที่ (0,0,0)
- Unity import Scale Factor ต้อง = 1 · ถ้าต้องใส่ 0.01 = pipeline พัง

## 4. UV

- Texel density (px/cm): hero character 10.24 · NPC/prop ใหญ่ 5.12 · environment 2.56 · ไกล 1.28 · **mobile ทุกอย่าง 2.56–5.12** · คงที่ทั้งชิ้น
- Padding ระหว่าง island: 256→2px · 512→4 · 1024→8 · 2048→16 · 4096→32 (bake padding = UV padding)
- Seam ซ่อนที่: รักแร้ ขาหนีบ หลังหู ขอบ material ด้านหลัง/ใต้ · **ห้าม**ผ่าหน้า จมูก ปาก พื้นเรียบที่เห็นชัด
- ทับกัน/mirror ได้เฉพาะ tiling/texture สุดท้าย · **ห้าม**ทับเมื่อจะ bake normal/AO → ใช้ UV2 แยก
- จัดกลุ่ม island · หมุนทิศเดียวกัน · ขอบตรงให้ขนานแกน
- Roblox: 1 UV set · อยู่ใน 0–1 · 1 material ต่อ mesh

## 5. Texture / PBR

- Power of two เท่านั้น (256…4096) · ไม่จำเป็นต้องจัตุรัส (2048×256 ได้)
- ขนาดตามการใช้: prop เล็ก 512 · environment prop 1024–2048 · hero 2048–4096 · UI icon 256 · Roblox: วัตถุ 5 stud→256 · 10 stud→512 · 20 stud→1024 (PBR สูงสุด 1024)
- ชุดมาตรฐาน: BaseColor (ไม่มีแสง bake) · Normal · Roughness · Metallic · AO · (Emissive) · pack เป็น `_ORM` = R:AO G:Rough B:Metal เมื่อ engine รองรับ
- ค่า PBR ที่สมจริง: BaseColor 0.02–0.9 (ไม่ดำ/ขาวสนิท) · Metallic 0 หรือ 1 · Roughness 0.02–1.0 (ไม่ 0)
- **Normal map convention**: OpenGL (Y+) = Blender, Unity, Godot, **Roblox** · DirectX (Y−) = Unreal · ส่งผิด = รอยนูนกลับด้าน เช็คด้วย test sphere
- Bake: cage ห่อ high poly พอดี (ดำ = ขยาย cage · เบลอ/คลื่น = smooth shade low + hard edge ที่ seam) · AO ≥ 128 rays · 64 samples

## 6. LOD

- LOD0 100% → LOD1 50% → LOD2 25% → LOD3 12.5% → (LOD4 5% billboard)
- ลดลำดับ: internal loop → bevel ไกล → extrusion < 5% ขนาด → bevel ทั้งหมด → รวมชิ้น · วงกลม 32→16→8→4 segment
- **ห้าม**ตัด: silhouette · จุดสัมผัสพื้น · ส่วนที่จำได้ (ตา มือ)
- Auto decimate ได้กับ prop/ฉาก · ตัวละคร/อาวุธ/hero ทำมือ
- Roblox ไม่มี LOD อัตโนมัติสำหรับ MeshPart (มี StreamingEnabled + `RenderFidelity`) → ทำ budget ให้ต่ำตั้งแต่แรกแทน

## 7. Collision

- ห้ามใช้ render mesh เป็น collision · ใช้ box/sphere/capsule/convex 8–32 tri · ชื่อ `UCX_<MeshName>` (Unreal)
- Roblox: `CollisionFidelity` = Box/Hull สำหรับ prop · PreciseConvex เฉพาะที่จำเป็น (แพง) · ตัวละคร/ศัตรูใช้ HumanoidRootPart/hitbox part แยก

## 8. Export

**FBX (Unity/Unreal/Roblox)**: Scale 1.0 · Apply Scalings = FBX All · Apply Unit ✓ · Apply Modifiers ✓ · Triangulate ✓ · Tangent Space ✓ · Smoothing = Face · Add Leaf Bones ✗ · Primary Bone Axis Y / Secondary X · Bake Animation ✓ · NLA Strips ✗ (export action ทีละตัว)
- แกน: Unreal −Y Forward / Z Up · Unity −Z Forward / Y Up (+ Bake Axis Conversion) · **export test cube ที่มีตัวอักษรก่อน** แล้วจดค่าที่ถูกไว้ใช้ตลอดโปรเจกต์
**glTF/.glb (Godot/web)**: +Y Up · Apply Modifiers · Draco สำหรับเว็บ · animation รองรับน้อยกว่า FBX
**OBJ**: static เท่านั้น ไม่มี hierarchy/animation

## 9. Sharp edges

1. ไม่ apply scale/rotation → ขนาดผิด/หมุน 90° · bake และ LOD พังด้วย
2. n-gon → triangulate มั่ว · normal map เป็นคลื่น
3. UV ทับกันแล้ว bake → เงาซ้อน
4. Texel density ไม่เท่ากัน → ชิ้นหนึ่งเบลอชิ้นหนึ่งคม
5. Normal map ผิดฝั่ง
6. Origin ลอย → วางบนพื้นแล้วจม/ลอย
7. Smooth shading ทั้งก้อนไม่มี hard edge/bevel → เงาเป็นคราบ
8. Texture ไม่ใช่ power of two → mipmap/compression พัง

## 10. Checklist

- [ ] Metric 1u=1m · transforms applied · origin ถูก · อยู่ที่ (0,0,0)
- [ ] ไม่มี n-gon / non-manifold / loose / interior face · normals ออก · merged by distance
- [ ] tri ใน budget ของแพลตฟอร์มต่ำสุด · Roblox ≤ 20k/mesh
- [ ] UV ไม่ทับ (ถ้า bake) · padding ตามขนาด · texel density ตรงเป้า · Roblox 1 UV set / 1 material
- [ ] Texture power-of-2 · ขนาดตามการใช้ · normal map convention ตรง engine · suffix ถูก
- [ ] LOD0–3 (หรือ budget ต่ำพอที่ไม่ต้องมี) · silhouette คงอยู่
- [ ] Collision แยก ≤ 32 tri
- [ ] Export settings ตามข้อ 8 · test cube ผ่านแล้ว
- [ ] ชื่อไฟล์/วัตถุ/material ตาม convention
- [ ] เปิดใน engine จริง เช็คที่ระยะเล่นจริง + จอ 720p
