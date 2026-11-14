# ตัวละคร / ชุดเกราะ R15: Blender → Roblox → ใส่บนตัวผู้เล่น

บทเรียนจากการทำ class model + เซ็ตเกราะในเกมจริง — ทุกข้อเจอปัญหาจริงมาแล้ว

## 1. สเกลและแกน (ตัดสินครั้งเดียว ใช้ทั้งโปรเจกต์)

- **1 Blender unit = 1 stud**: scene `unit_settings.scale_length = 0.01` + export FBX `apply_unit_scale=True`, `apply_scale_options="FBX_SCALE_ALL"`, `global_scale=1` → FBX เก็บเป็น cm = stud
- Blender scale 1.0 (เมตร) ตรง ๆ = ใหญ่ ×100 ใน Roblox
- ตัวละครหัน **−Y** ใน Blender · export `axis_forward="-Z"`, `axis_up="Y"` → ใน FBX หัน +Z ตามสเปก Roblox · ซ้ายของตัวละคร = +X ใน Blender
- Import 3D: **Scale Unit = Stud** · เช็ค **File Dimensions** ก่อนกด Import — R15 ต้องสูง ~5.2 stud
- ตำแหน่ง joint ใช้ค่า R15 มาตรฐาน (ดึงจาก `Players:CreateHumanoidModelFromDescription` ใน Studio ได้) เทียบกับ HumanoidRootPart: Neck 1.049 · Waist −0.6 · Root −1.0 · Shoulder ±0.972/0.798 · Elbow 0.014 · Wrist −0.756 · Hip ±0.5/−1.0 · Knee −1.87 · Ankle −2.797 · พื้น −3.006
- Roblox: หน้า = −Z · ซ้ายของตัวละคร = −X

## 2. สเปก rig R15 ที่ 3D Importer ยอมรับ (ไม่งั้นขึ้น "This rig does not follow the guidelines of chosen rig type")

- Bone: `Root → HumanoidRootNode → LowerTorso → UpperTorso → Head / L-R UpperArm → LowerArm → Hand` และ `LowerTorso → L-R UpperLeg → LowerLeg → Foot`
- **Root, HumanoidRootNode, LowerTorso อยู่ที่ 0,0,0** (origin = joint ราก ไม่ใช่พื้น — เท้าอยู่ที่ Z −2.006)
- Mesh ชื่อ **`<Part>_Geo`** ครบ 15 ชิ้น (Head_Geo, UpperTorso_Geo, LeftUpperArm_Geo …) · ชื่อ bone = ชื่อ part
- Bone ชี้ขึ้น (+Z) roll 0 ทุกตัว · rigid skin: แต่ละ mesh weight 1.0 กับ bone เดียว · ไม่มี weight บน Root
- **ห้ามใส่ mesh `HumanoidRootPart`** — importer สร้างให้เอง (ถ้าใส่จะเป็นกล่องทึบ 2×2×1 ทับลำตัว)
- **ห้ามใส่ `_Att` ใน rig ที่ skin** — แม้สเปกบอกว่า mesh ชื่อ `_Att` จะถูกแปลงเป็น Attachment แต่ geometry ของมันถูกรวมเข้า mesh ที่ skin โดยไม่มี weight → เป็นเศษสามเหลี่ยมสีขาวยื่นออกมาตอนขยับ · และถ้ามี material ใต้ `_Att` = error สีแดง · ใช้ accessory attachment ของ avatar แทน (ลอกตอน runtime ข้อ 5)
- Rig attachment (`*RigAttachment`) importer สร้างจาก bone เอง ไม่ต้องทำ
- `use_selection` export เฉพาะ collection ของร่าง (armature + `_Geo`) · `add_leaf_bones=False` · `bake_anim=False`

## 3. ขนาดและรูปทรง

- กว้าง/ลึกของแต่ละ part = **R15 block มาตรฐาน**: แขน/ขา 1 × 1 stud · UpperTorso ~1.94 × 1.0 · LowerTorso ~1.99 × 1.0 · Head ~1.16 — ถ้าทำเรียวลงเอง แขนกับลำตัว/ขาสองข้างจะห่างกันแปลก ๆ และผสมกับ part ของ avatar ไม่ได้
- ความสูงแต่ละท่อนให้ต่อกันพอดีที่ joint (ไม่ต้องซ้อนเหมือน mesh ของ Roblox)
- เกราะ (static mesh แยกไฟล์ต่อชิ้น) ต้องใหญ่กว่าร่างพอคลุมมุม: เช็คด้วย superellipse `(x/ra)^p + (z/rb)^p < 1` ที่มุมของ part ข้างใน · ขาสองข้างชิดกันจึงยอมให้เกราะข้างในเหลื่อมกันนิดหน่อย
- งบ: ร่าง ~4k tri · เกราะครบชุด ~9.6k tri (ทุกชิ้น < 1.6k)
- ตั้งชื่อชิ้นเกราะ `<ItemId>_<BodyPart>` (เช่น `PlateArms_LeftLowerArm`) · 1 Model ต่อ item ชื่อ = item id

## 4. สี/วัสดุแบบ palette (1 material · 1 UV set)

- texture 256² แบ่ง 8×8 ช่อง ช่องละ 32 px = 1 สี · ทุก face วาง UV เป็นสี่เหลี่ยมเล็กกลางช่องสี (ไม่ใช่จุดเดียว — กัน UV area 0)
- 3 ภาพ UV เดียวกัน: `_D` สี (sRGB) · `_M` metalness · `_R` roughness (Non-Color) → importer สร้าง SurfaceAppearance ให้ · ปรับ `_M/_R` ทีหลังได้โดยไม่แตะ mesh
- เหล็กใน preview ของ Blender ดูขาวเพราะสะท้อน world สว่าง — ใช้ world แบบ gradient ความสว่างต่ำ (~0.45) ก่อนตัดสินสี

## 5. ใส่บนตัวผู้เล่นตอน runtime (server)

- **อย่าเอา part ใหม่ไป weld ทับ part ของ avatar** — avatar ส่วนใหญ่สัดส่วนไม่ใช่ R15 มาตรฐาน (Rthro/แขนยาว/ไหล่แคบ) ชิ้นจะเหลื่อมและหลุดตำแหน่ง
- ใช้ `Humanoid:ReplaceBodyPartR15(Enum.BodyPartR15.X, part)` ต่อชิ้น แล้ว `Humanoid:BuildRigFromAttachments()` ครั้งเดียวหลังแทนครบ — joint เกิดจาก rig attachment ของแต่ละ part จึงผสม part ของโมเดลกับ avatar ได้ต่อกันพอดี
- ก่อนแทน: clone จาก template → **ทิ้ง JointInstance/Constraint ใน clone** (ชี้ไป part ของ template) · **ลอก Attachment ที่ clone ไม่มีจาก part เดิม** (Hat/Hair/Grip ฯลฯ ให้ accessory และ tool ยังเกาะได้) · เก็บสำเนา part เดิมไว้คืนตอนเลิกใช้
- HipHeight คำนวณจากสาย attachment ของขา: `(−HRP.Size.Y/2 − RootRig.Y) − [(Hip−Root)_LowerTorso + (Knee−Hip)_UpperLeg + (Ankle−Knee)_LowerLeg + (−Foot.Size.Y/2 − Ankle)_Foot]` เอาขาที่ยาวกว่า
- **บังคับรูปลักษณ์ตอนใช้โมเดล** (`ApplyDescriptionAsync` ก่อนแทน part เสมอ): Height/Width/Depth/Head scale = 1, BodyType/Proportion = 0, Idle/Walk/Run/Jump/Fall/Climb/Swim/Mood animation = 0 (แอนิเมชัน R15 ปกติ) — ชุดท่าของ avatar บางชุดทำให้โมเดลบล็อกพัง · เลิกใช้ = คืน description เดิม (`GetAppliedDescription` เก็บไว้ก่อน) · ลำดับ: คืน part เดิม → เปลี่ยน description → แทนใหม่ (part ที่เก็บไว้เป็นขนาดก่อนเปลี่ยน จึงล้างทิ้ง)
- `ApplyDescriptionAsync` yield → งานทั้งหมดอยู่ใน `task.spawn` · กันเรียกซ้อน (busy + dirty แล้วทำซ้ำ) · เช็คตัวละครยังเดิม/ยังไม่ตายหลัง yield
- Shirt/ShirtGraphic/Pants ถอดเก็บเมื่อส่วนนั้นใช้โมเดล (วาดตาม UV avatar มาตรฐาน จะทับสี palette)
- accessory ที่ weld หลุดหลังแทน part → ลบ weld แล้ว `Humanoid:AddAccessory` ใหม่ · accessory บน part ที่ถูกแทน/มีเกราะคลุม → ซ่อน Handle (เก็บค่าเดิมใน attribute)
- เกราะ: clone MeshPart → `Weld` Part0 = body part, `C0 = CFrame.new(rigAttachment.Position + offset)` · offset = จุดกึ่งกลาง bbox ของชิ้นเทียบกับ joint (Blender script คำนวณแล้วเขียน `<set>_attach.json`) — MeshPart ที่ import แล้ว CFrame อยู่ที่กึ่งกลาง bbox · `Massless`, CanCollide/CanQuery/CanTouch = false
- ใส่ตอน `CharacterAppearanceLoaded` (+ สำรองหลัง 3 วิ) · เปลี่ยน class / ค่าตั้ง / ใส่-ถอดของ → เรียก Refresh ที่ทำซ้ำได้ (idempotent)

## 6. ใน Studio

- Import 3D อยู่ที่ **File → Import 3D** (แท็บ Avatar ของ UI ใหม่ไม่มีปุ่มนี้)
- Rig Type = R15 (ร่าง) / No Rig (เกราะ) · Scale Unit = Stud · ปิด Merge Meshes ตอน import เกราะ
- template เก็บที่ `ServerStorage.<Templates>` (Rojo ไม่ map → ไม่ถูกเขียนทับ แต่ **ต้อง save place** เพราะไม่อยู่ใน git) · importer ตั้งชื่อ Model ตามไฟล์ (`<Id>_Body_R15`) → โค้ดควรหาได้ทั้ง `<id>` และ `<id>_Body_R15`
- `EditableMesh` อ่านไม่ได้ถ้าไม่เปิดใน Experience Settings → Security
- Studio อาจแสดง mesh เก่าค้าง (เศษ/รอยแตกที่หายไปแล้วในเกมที่ publish) → ปิด-เปิด Studio ใหม่ หรือเช็คในเกมจริงก่อนสรุปว่าโมเดลพัง

## 7. Checklist ก่อนส่งโมเดลตัวละคร R15

- [ ] Root/HumanoidRootNode/LowerTorso ที่ 0,0,0 · หัน −Y · unit scale 0.01 · File Dimensions ~5.2 stud
- [ ] mesh `<Part>_Geo` 15 ชิ้น · ไม่มี HumanoidRootPart mesh · ไม่มี `_Att`
- [ ] กว้าง/ลึกเท่า R15 block · ต่อกันพอดีที่ joint
- [ ] 1 material · 1 UV · palette `_D/_M/_R`
- [ ] Import preview ไม่มี ⚠ แดง (เหลือง "guidelines" = เช็คชื่อ bone/mesh/origin)
- [ ] ลองใน Play: ยืนนิ่ง เดิน กระโดด · ติ้กแยกส่วน · ใส่/ถอดเกราะ · ทดสอบกับ avatar ที่สัดส่วนไม่มาตรฐาน · ยืนยันในเกมที่ publish ถ้า Studio แสดงแปลก
