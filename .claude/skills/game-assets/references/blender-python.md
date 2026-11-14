# Blender Python (bpy) — สคริปต์สร้าง/แอนิเมต/render สำหรับเกม Roblox

สรุปจาก skill ทั่วไป `blender-scripting` · `blender-3d-modeling` · `blender-animation` · `blender-render-automation` · `blender-compositing` (terminal-skills, Apache-2.0) แล้วตัด/แก้ให้ตรงกับ pipeline Blender → Roblox
กติกาภาพ/budget อยู่ `3d-models.md` · `rigging-animation.md` · `vfx.md` — ไฟล์นี้ว่าด้วย **วิธีเขียนสคริปต์** เท่านั้น

## 0. สภาพแวดล้อม

- สมมติ Blender **4.4+/5.x** (สคริปต์ใช้ `compositing_node_group`, action แบบ slot/channelbag) — ตัวอย่างใน skill ทั่วไปที่เขียนแบบ 3.x หลายตัวใช้ไม่ได้แล้ว (ดู §7)
- VM ของ `device_bash` **ไม่มี Blender** → รันผ่านเครื่องมือ Blender MCP (`execute_blender_code` ในหน้าต่างที่เปิดอยู่ · `*_for_cli` สำหรับไฟล์ที่ไม่ได้เปิด) หรือให้ผู้ใช้รัน `blender -b <ไฟล์>.blend -P <สคริปต์>.py -- <args>`
- อาร์กิวเมนต์สคริปต์: `argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []`
- ที่อยู่สคริปต์: ชุดรวม `<assets>/<ชุด>/build_*.py` · แยกทีละตัว `<assets>/models/<หมวด>/<ชื่อ>/` (game-assets SKILL.md §2.5) · โปรเจกต์มีสคริปต์ export อยู่แล้ว → ใช้ของเดิม **ห้ามเขียน export FBX ใหม่ซ้ำ** · ยังไม่มี → เขียนครั้งเดียวเป็น tool กลางของโปรเจกต์

## 1. กติกาพิกัดสำหรับ Roblox (ทับค่าทั่วไป)

- **1 unit = 1 stud** · หน้า = **−Y** · Z ขึ้น — ไม่ใช่ 1 unit = 1 m แบบ skill ทั่วไป (เขียนลง README ของโฟลเดอร์ asset)
- origin แต่ละชนิด (ตัวละคร/อาวุธ/มอนสเตอร์ ฯลฯ) และ Custom Properties `roblox_*` ที่สคริปต์ export อ่าน → กำหนดครั้งเดียวใน README เดียวกัน
- **1 material + 1 UV (palette) ต่อชิ้น** → ระบายสีด้วยการวาง UV ลงช่องสี (`swatch(...)` ในสคริปต์เดิม) · **ห้าม**ใช้ `material_index` หลายวัสดุต่อ mesh แบบตัวอย่างทั่วไป (Roblox แยกชิ้นเมื่อ import) — ยกเว้นเปลวไฟ 2 ช่องที่อธิบายใน `vfx.md` §12

## 2. โครงสคริปต์

```python
import bpy, bmesh, math
from mathutils import Vector, Matrix

def link(ob, col=None):
    (col or bpy.context.scene.collection).objects.link(ob)   # ไม่ link = ไม่โผล่ในฉาก
    return ob
```

- `bpy.data` = เข้าถึงข้อมูลตรง (เร็ว ไม่ต้องมี context) — ใช้เป็นหลัก · `bpy.ops` = เลียนแบบการกด ต้องมี active/selected/context ถูก + ช้าเมื่อเรียกในลูป
- operator ที่ต้องมี context (เช่น `mode_set` หลัง `read_homefile`, `modifier_apply`) → `with bpy.context.temp_override(window=..., screen=..., view_layer=..., active_object=ob, object=ob):`
- สคริปต์สร้างชุดใหม่: เริ่มจากฉากเปล่า (`read_homefile(use_empty=True)` หรือลบของเก่า + orphan data) · **save เป็นไฟล์ใหม่** ไม่เขียนทับ .blend รายตัว (ต้นฉบับที่ผู้ใช้แก้มือ — SKILL.md §2.5)
- Custom property: `ob["roblox_piece"] = "Head"` · อ่าน `ob.get("roblox_piece")`

## 3. สร้าง mesh

- รูปง่าย/รู้ vertex ครบ: `me.from_pydata(verts, [], faces)` แล้ว `me.update()`
- มีการ extrude/subdivide/ต่อหน้า หรือ > ~1k หน้า: **bmesh** (เร็วกว่า `bpy.ops` ในลูปมาก)

```python
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")         # สร้าง UV layer ก่อนเสมอ (create_uvsphere(calc_uvs=True) ก็ต้องมี)
# ... bm.verts.new / bm.faces.new / bmesh.ops.*
bm.verts.ensure_lookup_table()               # ก่อนเข้าถึง bm.verts[i]
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("SM_Name"); bm.to_mesh(me); bm.free()   # free ทุกครั้ง
```

- ops ที่ใช้บ่อย: `extrude_face_region` → `translate` · `subdivide_edges` · `create_uvsphere/cone/cube` · `duplicate` + `reverse_faces` (ทำ 2 ด้านตอน export — `vfx.md` §12) · `remove_doubles(dist=1e-4)`
- เส้นโค้ง (Bezier/NURBS + `bevel_depth`) ใช้ทำทรงท่อได้ แต่ **ต้องแปลงเป็น mesh ก่อน export** (`new_from_object` จาก evaluated — export ของโปรเจกต์ทำให้แล้วถ้าเป็น mesh; curve ให้ convert เอง)
- ของซ้ำเยอะ (หลายสิบชิ้นขึ้นไป) ห้ามสร้าง object ต่อชิ้น → Collection Instance / Geometry Nodes (`vfx.md` §12)
- ทดสอบด้วยจำนวนน้อยก่อน แล้วค่อยขยาย (grid 100×100 + subsurf = Blender ค้าง)

## 4. Modifier

```python
m = ob.modifiers.new("Mirror", "MIRROR"); m.use_axis = (True, False, False); m.use_clip = True
m = ob.modifiers.new("Bevel", "BEVEL"); m.width = 0.02; m.segments = 2; m.limit_method = "WEIGHT"
```

- ลำดับ hard-surface: Mirror → Array → Boolean (Exact) → Bevel → Weighted Normal (ตาม `3d-models.md` §2) · Triangulate ไม่ต้องใส่ (FBX export triangulate ให้)
- **ไม่ต้อง apply ใน .blend** — `export_roblox.py` อ่าน mesh จาก `evaluated_depsgraph_get()` อยู่แล้ว (เก็บ modifier ไว้ให้ผู้ใช้แก้ต่อได้) · apply เฉพาะตอนต้องแก้ mesh ต่อด้วยสคริปต์
- Subdivision: ระวัง tri budget (Roblox ≤ 20k/ชิ้น แต่เป้าจริงต่ำกว่านั้นมาก) — นับหลัง evaluate (§8)

## 5. Armature + keyframe

- สร้างกระดูก: `mode_set("EDIT")` → `arm.edit_bones.new(name)` ตั้ง `head/tail/parent/use_connect` → `mode_set("OBJECT")` · ท่า/constraint ทำที่ `ob.pose.bones`
- กฎโครง Roblox (`rigging-animation.md` §1, §6): root ที่ 0,0,0 · ไม่มี weight บน root · **Roblox Bone ย่อ/ขยายไม่ได้ → ห้าม keyframe scale ของกระดูก** (ยืด = เลื่อนตำแหน่งข้อตามแกน) · `add_leaf_bones=False` · `use_armature_deform_only=True`
- Keyframe: `ob.keyframe_insert(data_path="location", frame=f)` · แกนเดียว `index=2` · custom prop `'["fx_alpha"]'` · กระดูก `pb.keyframe_insert("rotation_euler", frame=f)` (ตั้ง `pb.rotation_mode` ก่อน)
- Interpolation: `CONSTANT` = ค้าง · `LINEAR` = กลไก/จางเท่ากัน · `BEZIER` + easing = ท่าที่มีชีวิต
- **Loop ไร้รอยต่อ**: เฟรมแรก = เฟรมสุดท้าย + modifier `CYCLES` บน fcurve · ความถี่ทุกคลื่นเป็นจำนวนเต็มเท่าของ 1/ความยาวลูป (`vfx.md` §12)
- **IK / constraint / driver ไม่ถูก export** → `bpy.ops.nla.bake(frame_start=..., frame_end=..., visual_keying=True, clear_constraints=True, bake_types={"POSE"})` ก่อน export · หรือย้ายสูตรไป Luau แบบ `flame_pose` (Blender) ↔ `pose()` (Luau) (สูตรเดียวกันทั้งสองฝั่ง)
- NLA: ใช้จัดดูใน Blender ได้ แต่ Roblox = **1 track ต่อไฟล์** → export ทีละ action (`ad.action = None` ปล่อยให้ NLA คุมเฉพาะตอน preview)
- Shape key: Roblox ไม่เล่น shape key ทั่วไป → ท่าทางทำด้วยกระดูกหรือโค้ด · ใช้ shape key ได้แค่ช่วยปั้นแล้ว apply ทิ้งก่อน export

## 6. Render preview / icon

ตั้งครั้งเดียวเป็น helper ของโปรเจกต์ แล้วใช้ซ้ำ:

| งาน | engine |
|---|---|
| preview โมเดล (ตัวละคร/เกราะ/มอนสเตอร์) | `BLENDER_WORKBENCH` · light STUDIO · color TEXTURE · cavity + shadow · AA 16 · กล้อง ORTHO |
| icon ไอเทม พื้นใส | `CYCLES` · `film_transparent=True` · RGBA PNG · ORTHO |
| VFX / ฉาก (glow, โปร่ง, แอนิเมชัน) | `BLENDER_EEVEE` |

- `view_settings.view_transform = "Standard"` (+ `look = "None"`) เสมอ — AgX/Filmic ทำสี palette เพี้ยนจากที่เห็นใน Roblox
- กล้อง: ORTHO + `ortho_scale` คำนวณจากกล่องของวัตถุ × padding · หรือ `TRACK_TO` (`TRACK_NEGATIVE_Z`, `UP_Y`) ชี้เป้า · มุมมาตรฐาน หน้า 3/4 `(-0.7,-1,0.35)` หลัง 3/4 `(0.7,1,0.35)`
- render นิ่ง: `scene.render.filepath = path; bpy.ops.render.render(write_still=True)` · หลาย scene ใส่ `scene=name`
- แอนิเมชัน: render **เป็น PNG ทีละเฟรม** (พังกลางทางไม่เสียของ) แล้วรวมเป็น contact sheet — ไม่ทำวิดีโอ เว้นแต่ผู้ใช้ขอ (SKILL.md §2.6) · ดูภาพเองก่อนส่งทุกครั้ง
- Scene ที่เพิ่งสร้างใน call เดียวกัน animation ยังไม่ถูกประเมิน → render แยก call (`vfx.md` §12)

## 7. API ที่เปลี่ยนใน 4.4+/5.x (ตัวอย่างใน skill ทั่วไปใช้ไม่ได้)

| ของเดิม (3.x) | ใช้แทน |
|---|---|
| `action.fcurves` | `from bpy_extras import anim_utils` → `anim_utils.action_ensure_channelbag_for_slot(act, ad.action_slot).fcurves` (ต้องตั้ง `ad.action_slot` ก่อน — ดู `fcurves()` ใน `build_mage.py`) · อ่านอย่างเดียวรองรับทั้งสองแบบ: `getattr(act, "fcurves", None) or [fc for l in act.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]` |
| `scene.use_nodes` / `scene.node_tree` (compositor) | `scene.compositing_node_group` (node group ต่อ scene · `CompositorNodeRLayers.scene` ต้องชี้ scene ตัวเอง) |
| `BLENDER_EEVEE_NEXT` | `BLENDER_EEVEE` |
| ค่าของ Glare/Blur เป็น property (`glare.threshold`) | หลายค่ากลายเป็น socket — เช็คด้วย `[i.name for i in node.inputs]` ก่อนตั้ง |
| `bpy.ops.import_mesh.stl` / `export_scene.obj` | `bpy.ops.wm.stl_import` / `wm.obj_export` (FBX ยังเป็น `import_scene.fbx` / `export_scene.fbx`) |

ไม่แน่ใจชื่อ API → ใช้ `search_api_docs` / `get_python_api_docs` ของ Blender MCP หรือ `dir(...)` แทนการเดา

## 8. ตรวจก่อนส่ง (สคริปต์)

```python
dg = bpy.context.evaluated_depsgraph_get()
for ob in bpy.context.scene.objects:
    if ob.type == "MESH" and not ob.get("roblox_skip"):
        me = ob.evaluated_get(dg).to_mesh(); me.calc_loop_triangles()
        print(ob.name, len(me.loop_triangles), "tris", len(me.materials), "mats", len(me.uv_layers), "uv")
        ob.evaluated_get(dg).to_mesh_clear()
```

- tri ใน budget · 1 material · 1 UV · scale ของ object = 1 (หรือ export bake ให้) · ไม่มี non-manifold บนชิ้นปิด
- ชิ้นเปิด (แผ่น/ริบบิ้น) → ทำ 2 ด้านตอน export (Roblox ซ่อนหน้าหลัง) · นับ normal ขึ้น/ลง
- armature: ไม่มี keyframe scale · ไม่มี constraint ค้าง (bake แล้ว) · ไม่มี leaf bone
- ตาม checklist ใน `3d-models.md` §10 / `rigging-animation.md` §8 / `vfx.md` §9

## 9. Sharp edges ของ bpy

1. ลืม `link` object เข้า collection → สคริปต์ไม่ error แต่ไม่มีอะไรในฉาก
2. ลืม `bm.free()` / `to_mesh_clear()` → หน่วยความจำบวมเมื่อรันซ้ำ
3. bmesh ไม่สร้าง UV layer → texture ไม่ขึ้นแบบเงียบ ๆ
4. เข้าถึง `bm.verts[i]` โดยไม่ `ensure_lookup_table()` → IndexError
5. เรียก `bpy.ops` ในลูปหลายพันครั้ง → ช้ากว่า bmesh/data API หลายสิบเท่า
6. operator ผิด context (ไม่มี active / ผิด mode) → `poll() failed` → ใช้ `temp_override`
7. copy วัสดุต่อชิ้นเพื่อทำจาง → ไฟล์ preview กระตุก (ใช้ Attribute INSTANCER — `vfx.md` §12)
8. driver/constraint ไม่ bake → ใน Roblox ไม่ขยับ
9. เขียนทับ `.blend` รายตัว → งานที่ผู้ใช้แก้มือหาย

## 10. Blender MCP — ปัญหาที่เจอแล้ว

- `execute_blender_code` ต้อง `import bpy` ในโค้ดเอง · ใช้ lib ข้าม call: `exec(open(build.py).read(), G)` แล้วเก็บ `G` ใน `bpy.app.driver_namespace` · ดึง `ns["X"]` ใหม่ทุก call (globals เก่าชี้ datablock ที่ถูกลบ → ReferenceError)
- หลัง `wm.open_mainfile` ใน call เดียวกัน `bpy.ops.export_scene.fbx` พัง (`Context` ไม่มี `selected_objects`) → ห่อด้วย `bpy.context.temp_override(window=…, screen=…, scene=…, view_layer=…)`
- งาน > 60 วิ (build/render/export ทั้งชุด) → tool timeout แต่ Blender ทำต่อ → รันผ่าน `bpy.app.timers.register` แล้วเก็บผลใน `driver_namespace` มา poll · หรือเช็กเวลาไฟล์ผลลัพธ์ด้วย `device_bash`
- ภาพที่แก้บนดิสก์หลังโหลดแล้ว Blender ยังใช้ของเก่า (`images.load(check_existing=True)`) → `im.reload()` ก่อน render
- ลบ scene แล้ว object ค้างเป็น orphan ชื่อเดิม → build ใหม่ได้ชื่อ `.001` แล้ว export หาชื่อไม่เจอ → ลบ object ที่ไม่มี scene (prefix ของชุด) ก่อน build/export
- Blender บนเครื่องผู้ใช้มักไม่มี PIL → รวมภาพ (contact sheet) ใน VM ของ `device_bash` หรือ container
- เช็กไฟล์ที่ผู้ใช้เปิดอยู่ก่อนเขียนทับ: `bpy.data.filepath` + `is_dirty` · reload ด้วย `bpy.ops.wm.open_mainfile(filepath=..., load_ui=False)` (มุมกล้องผู้ใช้ไม่เปลี่ยน)
- ไม่มี Blender ให้ใช้เลย → `pip install bpy` (ตรงรุ่น) ใน container แล้ว build/render ที่นั่น
