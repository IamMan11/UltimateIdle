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
| สร้างเกมตามแผน | เฟส 0–7 เสร็จ ยกเว้น 7.3 (SEEN) · trade/ดูด่านคนอื่น ยังไม่ได้เล่นจริง 2 คน · ID Robux ยังเป็น 0 · มือถือยังไม่ได้ลอง emulator | 7.3 balance เมื่อมีข้อมูล Analytics จริง · ทดสอบ 2 คน (Studio Test → Clients and Servers 2 players) · Device Emulator · leaderboard/raid รอเจ้าของ | 2026-11-14 |
| ลบไฟล์เก่า | `src/shared/Hello.luau` ย้ายไป `_to_delete/` (ไม่มีสิทธิ์ลบ) (SEEN) | ผู้ใช้ลบโฟลเดอร์ `_to_delete/` เอง | 2026-11-14 |
| Asset ด่าน 1 (ทุ่งหญ้า · monster · boss · hero · VFX · icon 32px) | **แผน + ขั้นตอนทั้งหมดอยู่ `docs/asset-plan.md`** · ฉาก + slime ยืนยันแล้ว (ต้นแบบ) · hero v3 **ผ่านแล้ว** (OVERLAPS 0 · 3.4k–5.0k tri) · โล่ Warrior ทำใหม่ตามภาพอ้างอิง รอผู้ใช้ดู (SEEN) · คำถามค้าง 6 ข้อผู้ใช้ตอบแล้ว (อยู่ใน plan) | **import + ต่อโค้ดแล้ว 2026-11-15** (เกมใช้โมเดล/ฉากจริง ยังไม่มี animation · `Workspace.StageDemo` ลบได้ · place ยังไม่ได้ save โดยผม · ยังไม่ได้ดูภาพตอนเล่นจริงด้วยตา) · เหลือ (ก) ผู้ใช้ยืนยันสไตล์ VFX ต้นแบบ `vfx\preview\slash_sheet.png` แล้วทำ VFX ที่เหลือ (ข) ทุกอย่างที่ต้อง import: hero/monster/slime/ฉาก → assemble → `anims\build_keyframes.luau` → publish → ต่อโค้ด · **icon 20 อัน upload + ต่อ UI แล้ว 2026-11-15** (`Config/Icons.luau`) · monster 3 + boss 3 + icon ผู้ใช้โอเคแล้ว · ฉาก kit (2.1–2.3) เสร็จ รอผู้ใช้ดู → ต่อไป 2.4–2.5 ใน Studio · 1.2–1.3 เสร็จ · 1.4 แยกทีละตัวเสร็จ (`models\heroes\`) · **ต่อไป 1.5**: ผู้ใช้ Import 3D `Warrior.fbx` ใน Studio แล้วรัน `assemble.luau` (ยังไม่เคยลองใน Studio) → ผ่านแล้วทำไฟล์รวม + ตัวที่เหลือ | 2026-11-15 |
| commit แรก | ยังไม่มี commit (SEEN) | ผู้ใช้รัน `git add .` + `git commit` เอง (git ใน device_bash ค้าง lock ถ้าไม่มีสิทธิ์ลบ) | 2026-10-31 |

## Strikes — บั๊กเดิมที่แก้แล้วยังพัง

แก้พลาด 1 ครั้ง = 1 strike · ครบ 2 ให้กลับไปอ่าน reference + โค้ดจริงก่อนลองใหม่ · ครบ 3 หยุดเดา ถามคำถามเดียวที่เฉพาะเจาะจง
แก้ได้แล้วย้ายไป Learned patterns แล้วลบแถว

| ปัญหา | ครั้งที่ | ลองอะไร | ผล |
|---|---|---|---|
| | | | |

## Learned patterns

- โมเดลจากกล่อง: bevel ด้วย modifier ทุกกล่อง = tri บวม 3 เท่า → bake bevel ใน bmesh ตามขนาด (ใหญ่ 2 ชั้น · กลาง 1 · เล็กไม่ bevel) ลดจาก ~15k เหลือ ~4k/ตัว (SEEN)
- กล่องซ้อนหน้า coplanar = ผู้ใช้เห็นเป็น "model ซ้อน" → log กล่องทุกใบแล้วดันใบหลังออก 0.02 อัตโนมัติ + พิมพ์ `OVERLAPS n` (ดู `box()`/`coplanar()` ใน `heroes/build_heroes.py`) · กล่องที่หมุน/เรียวไม่ถูกตรวจ → เลี่ยงซ้อนกล่องหมุน (SEEN)
- ช่องแคบลึกระหว่างกล่อง (เช่น ใต้จมูก) render เป็นสีดำ → อุดด้วยกล่องตรง ไม่ใช้กล่องหมุนชนกัน (SEEN)
- render Cycles ใน container: lineup 1600×840 ×2 + close-up 12 ภาพ ≈ 10 นาที เกิน timeout 600s → รันเบื้องหลังหรือลดจำนวนภาพ (SEEN)
- กล่อง `rot=` วางระนาบเดียวกับกล่องตรง = หน้าซ้อน render ดำ และ `coplanar()` ไม่จับ (`OVERLAPS 0` ทั้งที่ซ้อน) → กล่องหมุนต้องหนากว่า/ยื่นกว่ากล่องข้างใต้ ≥ 0.02 · จับได้ด้วย turnaround ท่ากางแขนเท่านั้น (SEEN)
- mesh 2 ชิ้นที่ความละเอียดขอบต่างกัน (พื้น 4 stud ชนเนิน 20 stud) = ขอบตรงกันแค่บางจุด เกิดช่องเห็นฟ้าเป็นแถบซีด — ดูเหมือนหมอก/เงาสะท้อนแต่ไม่ใช่ → ให้ชิ้นหยาบมุดใต้ชิ้นละเอียด 1 แถว (skirt) (SEEN)
- bmesh `loops.layers.color` = byte sRGB: ใส่ค่า linear แล้วสีมืด/น้ำตาล → ใช้ `loops.layers.float_color` (linear) + FBX `colors_type="SRGB"` (SEEN)
- bake หินหลายก้อนลง atlas เดียว: smart_project ทีละก้อน → ย่อ UV ลงช่อง → bake ทีละก้อน `use_clear=False` · DIFFUSE(COLOR)/NORMAL/ROUGHNESS ที่ 4 samples ทั้งชุด < 30 วิ (SEEN)
- import FBX เข้า Studio ไม่ต้องใช้ dialog: `open_cloud_invoke` POST `/assets/v1/assets` (assetType Model, โฟลเดอร์ต้องอยู่ใน MCP Permissions → Open Cloud upload directories) → `InsertService:LoadAsset(id)` · ชื่อ mesh, ขนาด 1 unit = 1 stud, texture ฝัง (→ `TextureID`; ชุด D/N/R → SurfaceAppearance), vertex color, กระดูก มาครบ · **pivot ของ Model ที่ import = origin + แกนของไฟล์ต้นทาง** → `PivotTo` แล้วอ่านตำแหน่งชิ้นได้เลย ไม่ต้องพิมพ์ตาราง c/s จาก json (SEEN) · asset ที่ upload ลบผ่าน API ไม่ได้
- **แก้ข้อถัดไป: วินิจฉัยผิด** — hero ไม่มีลายเพราะรูป atlas ของ Warrior/Mage โหลดไม่ได้จริง (`AssetFetchStatus.Failure` ทั้งที่ Open Cloud บอก Approved; ตอน import ใหม่ ๆ ยังเห็นเพราะ cache) → upload PNG ซ้ำเป็น Image asset แล้วเปลี่ยน `TextureID` · **ผู้ใช้บอกว่า texture หาย = เช็ก `ContentProvider:PreloadAsync(decal, cb)` ทุก id ก่อน ห้ามเดาจากแสง** (SEEN)
- `MeshPart.Color` คูณกับ vertex color และ `TextureID`: ค่าเทาเริ่มต้นของ importer (163) ทำให้ทุกอย่างมืดลง 1/3 → ตั้งขาวหลัง import (ยกเว้น Neon/Glass) (SEEN)
- แผ่นพื้นเปิด (grid) หลัง `recalc_face_normals` normal ชี้ลงได้ทั้งแผ่น: Blender เห็นปกติ แต่ Roblox cull ทิ้ง พื้นหายเห็นแต่ part รองข้างล่าง → บังคับ `normal.z > 0` ก่อน export · mesh ใหญ่สีต่อหน้า ตั้ง `RenderFidelity = Precise` (SEEN)
- (เดิม เรื่องแสง ยังจริงแต่ไม่ใช่สาเหตุหลัก) ผู้ใช้เห็นในเกมแล้วบอก "texture ไม่เข้า" ทั้งที่ `TextureID` มี → สาเหตุคือแสง: ดวงอาทิตย์อยู่หลังฉาก ด้านที่กล้องเห็นอยู่ในเงา + ambient ต่ำ · ตรวจ `Lighting:GetSunDirection()` เทียบฝั่งกล้องก่อนสรุปว่า texture หาย (SEEN ค่า · SAID ว่าแก้แล้วดูดี — ผู้ใช้ยังไม่ยืนยัน)
- พื้น vertex color ไล่สีเนียน + shading smooth ใน Roblox = ดู "ดินน้ำมันเปียก" → ใช้สีเรียบต่อหน้า + flat shading + `EnvironmentSpecularScale 0` (SAID)
- Rig template: ต้องอยู่ `ReplicatedStorage` (client สร้างตัวเอง — `ServerStorage` มองไม่เห็น) · หา feet จาก part ที่ `Transparency < 1` เท่านั้น ไม่งั้น RootPart/ref part ที่ซ่อนอยู่ดันตัวลอย (Slime ลอย 1 stud) · โมเดลหน้า −Z → ตั้ง `PivotOffset` หมุน 90° ให้หน้าไป +X ตามที่ Playback คาด · จาง/คืน transparency ต้องจำค่าเดิมต่อ part (แก้ว, part ซ่อน) (SEEN)
- Studio ที่ใช้จริง: `UltimateIdle` placeId 75117035173153 · universe 10776566899 (เลข 108236200953937 ในตารางงานค้างเป็นของเก่า) (SEEN)
- เล่นท่าจากข้อมูลตรง ๆ ไม่ต้อง publish: pose ต่อข้อเป็น CFrame ในแกนโมเดล → `Transform = A:Inverse() * pose * A` · Motor6D: `A = C0.Rotation` · Bone: `A = bone.WorldCFrame.Rotation` ของ template ที่ไม่หมุน · part ต้อง unanchored (root anchored) ไม่งั้น Motor6D ไม่ขยับ · ตรวจทิศได้ด้วยตัวเลขใน Play: ขยับแล้วอ่านตำแหน่งในแกนโมเดล (Slime พุ่ง −Z, ตายล้มไป +Z) (SEEN)
- แอนิเมชัน R6/ชิ้นแข็งทำเป็นข้อมูลได้โดยไม่ต้องเปิด Studio: เก็บ quaternion ต่อข้อ (แกน Roblox, หมุนรอบข้อ) แล้วให้ Luau แปลงเป็น `Motor6D.Transform` ด้วย `C0.Rotation:Inverse() * R * C0.Rotation` — ไม่ต้อง hard-code แกนข้อ R6 (SAID: สูตรยังไม่ได้ลองใน Studio)
- ย้าย origin ของ object ไปที่ข้อต่อโดย mesh ไม่ขยับ: `mesh.transform(new.inverted() @ old)` แล้วตั้ง `matrix_world = new` หลัง reparent (parent ก่อน ลูกทีหลัง) (SEEN)
- ใช้ lib ของ hero กับตัวอื่น: `exec` ส่วนบนของ `build_heroes.py` (ถึงบรรทัด `# === WARRIOR`) + `coplanar()` — ดู `monsters/build_monsters.py` · ตัวไม่ใช่ R6 (wolf) = ลบ vert ของ Head เริ่มต้น + `h.log.clear()` แล้วตั้งชื่อ piece เอง · สเกลตัว = `root.scale` + `root.location.z = 3*scale` (SEEN)
- `build_heroes.py` 100% 48 samples ใน cloud (2 core) = 9.5 นาที → รันเบื้องหลัง · turnaround ortho 640² 24 samples 40 ภาพ ≈ 2 นาที (SEEN)
- bpy 5.3: `image.unpack(method="REMOVE")` แล้วชี้ไฟล์ = render ชมพู → คง packed ไว้ ใช้ `image.save(filepath=)` เขียนสำเนาให้ FBX (SEEN)

- โมเดลของ `D:\blendermodel\models` (โปรเจกต์เก่า) = **ดูเป็นแนวทางได้ ห้ามเอา mesh/texture มาใช้** — append แล้วเปลี่ยนสี/เติมชิ้น ผู้ใช้ถือว่าลอก (SAID 2 ครั้ง) · "ปรับใช้แบบไม่ลอก" = ออกแบบใหม่ทั้งชุด/ผม/หน้า/อาวุธ ด้วยวิธีสร้างแบบเดียวกัน (`heroes/build_heroes.py`)
- object ที่ parent ต่อจาก root ไป arm (arm อยู่ที่ transform ของ root): ใช้ `matrix_parent_inverse = Identity` — ใส่ `arm.matrix_world.inverted()` แล้วของกระเด็นไป origin (SEEN)
- สคริปต์ที่รันด้วย `python3 x.py` ห้ามตั้งชื่อชน stdlib (`inspect.py`) — bpy ถูก init ซ้ำแล้ว crash (SEEN)

- Blender MCP ต่อไม่ได้ (Blender ไม่ได้เปิด) → `pip install bpy` ใน cloud container (ได้ 5.3) build + render Cycles CPU ได้: 1280×720 40 samples ≈ 2.5 นาที/ภาพ (ฉากหญ้า instance ~150k) · ทดสอบที่ 50% ก่อน (SEEN)
- bpy 5.3: `FunctionNodeRandomValue` socket = Min 0 · Max 1 · ID 2 · Seed 3 · output 0 (ไม่ใช่ 2/3 แบบ 3.x) → เช็ก `[(i,s.name) for …]` ก่อนตั้งค่าด้วย index (SEEN)

- ProfileStore ไม่มี API access → ไม่คืน nil แต่สลับเป็น mock เอง พิมพ์ `Roblox API services unavailable - data will not be saved` → เช็คบรรทัดนี้แทนการรอโดน kick (SEEN)
- type `ProfileStore.Profile<Data>` ไม่ตรงกับค่าที่ `StartSessionAsync` คืนใน strict (`Data & JSONAcceptable`) → ใช้ `typeof(assert(PlayerStore:StartSessionAsync("", {})))` แทน (SEEN, luau-lsp 1.70.1)
- selene `[config] x = { severity = ... }` ไม่ใช่ syntax จริง · ระดับ lint ตั้งใน `[lints]` · ยกเว้นไฟล์ด้วย `exclude = [...]` (SEEN)

- `string.gsub` คืน 2 ค่า: ซ้อนเป็น arg แรกได้ (ถูกตัดเหลือค่าเดียว) แต่อย่าวางเป็น arg สุดท้ายของ call อื่น (SEEN)
- ใน VM ของ device_bash ไม่มี stylua/selene/luau → โหลด release จาก GitHub ลง cloud container แล้ว stage ไฟล์ไปตรวจ: `luau` รันเทส pure module ได้, `luau-analyze --mode=strict` ตรวจ type ได้ถ้าไม่ require Roblox instance (SEEN)

- Rojo ไม่ได้ต่ออยู่ (ไฟล์ใหม่ไม่โผล่ใน Studio) → เช็ก `Shared.Config:FindFirstChild(<ไฟล์ใหม่>)` ใน Edit ก่อน Play · ทดสอบได้โดย patch `.Source` ใน Edit ด้วย find/replace เดียวกับที่แก้บนดิสก์ (Rojo ต่อใหม่จะเขียนทับด้วยของดิสก์) (SEEN)
- upload รูป UI: `open_cloud_invoke` POST `/assets/v1/assets` assetType `Image` ทีละไฟล์ → poll operation ได้ `assetId` ใช้เป็น `rbxassetid://` ได้ตรง ๆ (ไม่ใช่ Decal id) · pixel art 32px upload ที่ ×4 · `ResampleMode.Pixelated` เฉพาะตอนแสดง ≥ 32px (ย่อด้วย nearest pixel หาย) (SEEN)
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

- `Widgets.Window` ต้องเป็น TextButton (ไม่ใช่ Frame): ไม่งั้นคลิก label ในหน้าต่างทะลุไปโดน backdrop → หน้าปิด (SEEN)
- ของที่ระบบอื่นแก้ผ่าน `Inventory.Set*` เป็น table เดิม → อ่านค่าเก่า (เช่น `item.Plus`) ก่อนเรียก setter ถ้าจะส่งใน notice (SEEN)
- Relic นับเฉพาะของที่ hero ในทีมใส่ → Modifiers ต้อง MarkDirty ตอน Equip/Unequip/SetTeam/แก้ socket ของที่ใส่อยู่ (SEEN)
- Stage `finishLevel` ใช้ `Stage.ProgressFor(data, run.Rebirth)` ไม่ใช่ rebirth ที่เล่นตอนนี้ (ผู้เล่นสลับ rebirth กลาง level ได้) (SEEN)

- `/tmp/sm.json` ใน VM ของ device_bash อาจเป็นของ user อื่น (Permission denied) → เขียน sourcemap ที่ `$HOME/sm.json` (SEEN)
- luau-lsp: ค่าจาก `{ Kind }` ที่ Kind เป็น union ของ string literal ถูกมองเป็น `string` ตอนส่งข้าม module → cast `x :: Period.Kind` ตรงจุดเรียก (SEEN, 1.70.1)
- ทดสอบหน้า React ที่ต้องมี 2 คน: ใน Client `execute_luau` require component เอง + `ReactRoblox.createRoot` ลง ScreenGui ชั่วคราวพร้อม props จำลอง แล้วอ่าน Text ของลูก (SEEN, หน้า Trade)
- ProfileStore mock (ไม่มี API access) ยัง fire `OnAfterSave` → `PlayerData.WaitSaved` / ProcessReceipt ทดสอบใน Studio ได้ผ่าน dev `receipt` (SEEN)
- คลิกปุ่ม HUD ขณะเปิดหน้าอื่นอยู่ = โดน backdrop → หน้าเดิมปิด ไม่เปิดหน้าใหม่ → ปิดหน้าก่อน (Close) แล้วค่อยคลิก (SEEN)

- Phase-7 server hooks กัน require วน: ระบบล่าง (Currency/Quest/RateLimit) ไม่ require ระบบบน → ใช้ hook (`RateLimit.OnTrip`, `Quest.OnProgress`) ให้ Analytics/Tutorial มาเกาะแทน (SEEN)
- `pcall(fn)` เมื่อ `fn: () -> ()` ใน strict → "Function only returns 1 value, but 2 are required" · ห่อเป็น `pcall(function(): nil fn() return nil end)` (SEEN, luau-lsp 1.70.1)
- `React.useEffect` ที่ return cleanup บางทาง/nil บางทาง ไม่ผ่าน strict → annotate `function(): () -> ()` แล้ว return cleanup ทุกทาง (SEEN)
- คลิกวัตถุ 3D ใน Studio MCP: `user_mouse_input` instance_path ใช้ได้แค่ GuiObject · คำนวณพิกัดด้วย `Camera:WorldToViewportPoint` ใน Client แล้วส่ง x/y (ตรง ไม่ต้องบวก inset) (SEEN)
- `FindFirstChild(name, true)` บน PlayerGui ชนชื่อซ้ำระหว่าง HUD กับหน้าที่เปิด (เช่น "Tutorial") → หา parent ที่ระบุก่อน (`HUD`) (SEEN)
- device_bash VM ใหม่ทุก session: `$HOME/bin` ว่าง ต้องโหลด stylua/selene/luau-lsp/rojo ใหม่ (สคริปต์ตรวจรวมเขียนไว้ที่ `$HOME/check.sh` ได้) (SEEN)
- place นี้ไม่มี `PlayerScripts.PlayerModule` (WaitForChild ค้าง) แต่ avatar ยังเดินได้ → หยุด avatar ด้วย Humanoid (`WalkSpeed/JumpPower/JumpHeight = 0`, `AutoRotate = false`) ฝั่ง client แล้วคืนค่าเดิม ไม่พึ่ง control module (SEEN)
- ฉากด่านสร้างฝั่ง client → ไม่ติด StreamingEnabled แม้อยู่ไกล lobby 6000 studs · ซ่อน = `Parent = nil` (SEEN)
- เช็ก unit ใน `Workspace.ClientBattle` ได้เฉพาะโหมด Lane (โหมดเดิน folder ถูกถอดออก) (SEEN)
- ProfileStore probe ได้ HTTP 500 (แทน 403) → เข้าใจว่า API ใช้ได้ → เซฟจริงโดน 403 วน → client ค้าง "Loading..." · Stop/Play ใหม่ (SEEN)
- MCP `start_stop_play` ค้าง "Start play hasn't finished yet" ขณะ Studio ยังอยู่ Edit → ให้ผู้ใช้กด Play เอง (SEEN)

## Dead ends — ลองแล้วไม่ได้ผล อย่าลองซ้ำ

- 

## Regression runs — เช็กหลังแก้ shared code

- `stylua src/` และ `selene src/` → ผ่าน
- smoke boot: Play 10 วิ → ไม่มี error (ขั้นตอน `.claude/skills/roblox-game-dev/references/smoke-test.md` — รันเมื่อผู้ใช้สั่งเท่านั้น)
- prefix log ของระบบเรา (ใช้ให้คะแนน WARN ใน smoke): `[PlayerData]` `[Currency]` `[Inventory]` `[RateLimit]` `[World]` `[Battle]` `[Offline]` `[Analytics]` `[Anomaly]`
- tool รัน: `rojo sourcemap default.project.json --output /tmp/sm.json` → `luau-lsp analyze --sourcemap=/tmp/sm.json --definitions=$HOME/bin/globalTypes.d.luau --base-luaurc=.luaurc --ignore="Packages/**" --ignore="**/ProfileStore.luau" src/` ต้องว่าง

## Session log

- 2026-10-31: ตั้ง PlayerData (src/server/Data) + ProfileStore vendored, .vscode/settings.json, selene.toml, roblox.yml gitignored · stylua/selene/luau-lsp ผ่าน · Play: โหลดโปรไฟล์ได้ (mock) PASS
- 2026-11-14: ตกลงสเปกเกมกับเจ้าของ เขียน docs/design.md + docs/plan.md · ยังไม่แตะ src/
- 2026-11-14: ขั้น 0.1 — Types.luau + Format.luau · stylua/selene/luau-analyze ผ่าน · `Format.Number(1.5e12) == "1.5T"` PASS (รันด้วย luau CLI) · ช่องสวมใส่ = 10 (เจ้าของยืนยัน แก้เลข 11 ใน design/plan แล้ว)
- 2026-11-14: เฟส 0–2 (0.2–2.7) ครบ · stylua/selene/luau-lsp strict ผ่าน 0 error · Studio Play: เลือก hero → ด่านเล่น/จ่าย gold+gear, Bag ค้นหา @tag + salvage confirm, Heroes ใส่ของ/ซื้อ hero, Boxes เปิด/แปลง, Farm + skip wave + กล้อง 3D PASS · offline/AFK ยังไม่ได้ทดสอบจริง
- 2026-11-14: เฟส 3 (3.1–3.7) ครบ · stylua/selene/luau-lsp strict 0 error · Studio Play PASS: ซื้อ node (confirm), Squad I → ทีม 2 ช่อง (ลากวาง + เกินช่อง = toast), เปลี่ยนอาชีพ 2 ขั้น (wear cap 60→110→150), sim ยิงสกิล (PowerStrike/Fireball/Meteor/ShieldWall/MassHeal) + ชื่อสกิลขึ้นบนหัว, กล่องเปิดอัตโนมัติทุก 20 วิ, cap กล่อง 25→35 · ยังไม่ทดสอบ: Resurrect ในด่านจริง, toggle Berserk ผ่าน UI, กระเป๋าเต็มแล้ว auto-open หยุด/กลับมา · `Settings.AutoOpenBoxes` = สวิตช์ auto-open · `SkillOff` = node toggle ทั่วไป
- 2026-11-14: เจ้าของตัดสิน 4 ข้อ → ทำแล้ว: skip wave เฉพาะ level ที่เคยผ่าน · ออกจาก Farm กลางรอบ = ได้ก้อนของรอบที่จบล่าสุด (`LastFarmRound`) · กล่องแยก stack ตาม kind:rebirth:ช่วง level 25 (schema v2) แปลง class ได้จาก Normal และ Boss · ข้อความภาษาอังกฤษเท่านั้น · Studio PASS (กล่องแยกช่วง, แปลง Boss→Mage, ป้าย skip รอผ่าน level)
- 2026-11-14: เฟส 6 ครบ (schema v3: Quests/Pass/Shop/Purchases.GiftTo) · stylua/selene/luau-lsp 0 error · Studio PASS: quest progress + claim (ซ้ำ = ปฏิเสธ), pass claim ฟรี/premium ล็อก, dev receipt ShopRuby ซ้ำ id ไม่ให้ซ้ำ + PurchaseGranted หลังเซฟ, premium ผ่าน receipt, ร้าน gold/Ruby + โควตา + ปุ่ม Robux ID 0, x2 gold (87→174), หน้า trade lobby + render ข้อเสนอจำลอง · ยังไม่ทดสอบ: trade จริง 2 คน, gift ข้ามคน, lock ของระหว่าง trade, offline x2, ซื้อ Robux จริง · ตัดสินเอง (ปรับได้): trade ได้ gear/วัตถุดิบ/กล่อง/gold/Ruby · ไม่ขายกล่องด้วย Robux/Ruby (paid random items) · ราคา gold + รางวัล gold = หน่วย "gold-level" × Scaling.Gold(level ดีสุด) · อัตรา offline เก็บแบบไม่รวม x2 แล้วคูณตอนจ่าย
- 2026-11-14: เฟส 4–5 ครบ · stylua/selene/luau-lsp strict 0 error · Studio PASS: ตีบวก (+1..+3, ข้อความผล), เปิดช่อง (merge ของซ้ำ + Socket Core), ใส่ Gem/Artifact/Relic, ถอด (คืนของ เสีย gold), enchant (ก่อน/หลัง), rebirth 0→1 (R1 เริ่มที่ level เดิม, ได้แต้ม+ของ), สลับเล่น R0 · ยังไม่ทดสอบ: ผล Relic ต่อ drop จริง, crit/lifesteal ใน sim (ดูด้วยตาเท่านั้น), Farm + สลับ rebirth กลางรอบ · ตัดสินเอง (ปรับได้): cap hero/สวมใส่/level ส่วนตัว ใช้ rebirth ที่ปลดสูงสุด, ความยาก/cap drop/ตาราง drop ใช้ rebirth ที่เล่น · Relic นับเฉพาะ hero ในทีม · rebirth ใหม่ MaxLevel = level ที่พามา · อัตราตีบวกไม่แสดงใน UI (อยู่ Secret)
- 2026-11-14: เฟส 7 (7.1 7.2 7.4 7.5) · schema v4 (Tutorial/Daily/Codes/Settings.UiScale+LowDetail) · stylua/selene/luau-lsp 0 error · Studio PASS: ด่านตัวเองเล่นหลังแยก `Playback`, คลิกด่านสลับ 2D→3D, `[Anomaly] RateLimit`, tutorial ขั้น 1→2 + ข้าม, daily claim + กดซ้ำไม่ได้, โค้ด WELCOME (ซ้ำ/ไม่มี = ปฏิเสธ), UI size 115%, low detail · เจ้าของสั่งข้าม: leaderboard, raid/challenge/event/boss map · 7.3 รอข้อมูลเล่นจริง · ตัดสินเอง (ปรับได้): ดูด่าน = ส่งเฉพาะคนที่ดู, tutorial 5 ขั้น + รางวัล, daily 7 วัน, โค้ดอยู่ `Secret/` · ยังไม่ทดสอบ: ดูด่าน 2 คน, Equip/OpenBox/BuyNode/Enhance ใน tutorial, มือถือจริง
- 2026-11-14: ย้ายด่านไป Z −6000 (ไม่มี part ฝั่ง server), ฉาก placeholder ฝั่ง client (`Scenery.luau` + `Config/Scenery.luau`), กล้อง 2D เอียง 12°, freeze avatar ตอนดูด่าน · stylua/selene/luau-lsp 0 error · Studio PASS: 2D/3D, W/A/S/D/Space ไม่ขยับ, โหมดเดิน = ฉาก+unit หาย เดินได้ · ยังไม่ทดสอบ: ดูด่านคนอื่น, มือถือ, gamepad · ศิลป์จริงยังไม่มี (`Backdrop.Image` ว่าง, `docs/art-style.md` ยังว่าง)
- 2026-11-14: รวมหน้า: ปุ่ม HUD `Team` = Heroes/Team/Skill Tree, `Inventory` = Bag/Boxes/Forge เป็นแท็บในหน้าต่างเดียว (`UI/Core/Groups.luau`, `Widgets.Window` prop `group`, `State.Ui.Tabs` จำแท็บล่าสุด) · `Ui.Page` ยังเป็นชื่อหน้าเดิม · stylua/selene/luau-lsp 0 error · **ยังไม่ได้ทดสอบใน Studio** (Play ค้าง) → เช็ก: ปุ่ม 2 ปุ่มเปิด/ปิด, สลับแท็บ, จำแท็บล่าสุด, tutorial ไฮไลต์ปุ่มกลุ่ม, จอ compact แท็บไม่ทับ title

- 2026-11-15: asset 1.2–1.4 (บางส่วน): turnaround 4 hero, แก้เข่า Warrior, `_tools/` (export_roblox · split_heroes · turnaround), export แยก 4 ตัว + README · OVERLAPS 0 · tri 3.4k–4.8k · ยังไม่ทดสอบ: import ใน Studio
- 2026-11-15: monster 3 + boss 3 (โมเดลรอบแรก OVERLAPS 0) + icon 32px 16 อัน · ทำต่อเนื่องตามคำสั่ง ยังไม่มีการยืนยันสไตล์ · ยังไม่ทดสอบ: ทุกอย่างใน Studio
- 2026-11-15: ฉากด่าน 1 ชุดจริง `stage01_meadow/kit` (17 ชิ้น 19k tri, FBX รวม + json + atlas หิน) · ยังไม่ทดสอบ: import Studio, vertex color ใน Roblox, DoubleSided หญ้า
- 2026-11-15: รอบเก็บงาน asset: hero (Healer sigil, รองเท้า Warrior, Heroes_All.fbx + assemble_studio.luau) · goblin/golem · icon 20 อัน · ฉาก (ปิดช่องเห็นฟ้าที่โคนเนิน) · OVERLAPS 0 ทุกตัว · ยังไม่ทดสอบ: ทุกอย่างใน Studio
- 2026-11-15: boss สุ่มที่ wave สุดท้าย + Wolf/3 boss ใน config (lint/type ผ่าน ยังไม่ Play) · export monster แยกตัว · Slime ของจริง · แอนิเมชันเป็นข้อมูล 10 ตัว · ต้นแบบ VFX ฟัน Warrior · ยังไม่ทดสอบ: ทุกอย่างใน Studio
- 2026-11-15: upload FBX 9 ไฟล์ (asset: Heroes 76465505499533 · Goblin 137974030743174 · Orc 75635272133669 · Wolf 85218028526593 · Werewolf 70479184041192 · OrcLeader 121302840715286 · DirtGolem 83802354969206 · Slime 81446098105858 · Meadow_Kit 79409088000009) + ประกอบ template + StageDemo · ตรวจด้วย screenshot · ยังไม่ทดสอบ: Play, animation, ต่อโค้ด
- 2026-11-15: ต่อ Rig + Scenery เข้ากับ template ที่ import · stylua/selene/luau-lsp 0 error · Play (MCP): Stage = 234 MeshPart จาก kit, Rig.Acquire 9 kind เท้าที่ FloorY, ไม่มี error ใน console · ยังไม่ทดสอบ: ดูด้วยตาตอนสู้จริง, มือถือ, FPS กับหญ้า 175 patch
- 2026-11-15: ฉาก v2 (low-poly, ทางเดินดิน, ดงหญ้าเป็นกลุ่ม) upload asset 96571578096564 → `StageKits.Meadow` · `Scenery.fromKit` วางหญ้าเป็น cluster · Lighting ปรับ · lint/type 0 error · Play: Stage 300 ชิ้น ไม่มี clump บนทาง · ยังไม่ทดสอบ: ดูด้วยตา
- 2026-11-15: ฉาก v3 (asset 124865124030080, normal พื้นถูก) · atlas Warrior 108565257201171 / Mage 102087574220979 upload ซ้ำ · Color ขาวทุก mesh · ตรวจด้วย screenshot ใน Edit: พื้น+ทางเดิน+hero 4 ตัวมีลายครบ · ยังไม่ทดสอบ: ดูตอน Play ด้วยตา
- 2026-11-15: animation monster/boss/Slime ต่อเข้าเกม (data-driven) · lint/type 0 error · Play: ข้อขยับตามข้อมูล ทิศถูก (ตรวจด้วยตัวเลข 7 kind) hero ไม่ถูกแตะ · ยังไม่ทดสอบ: ดูด้วยตาตอนสู้, จังหวะตีเทียบ damage, FPS ตอน monster 40 ตัว
- 2026-11-15: icon 20 อัน upload (Image asset) → `Config/Icons.luau` · `Widgets.Icon` + `Button` prop `icon/iconSize` · HUD (ปุ่มหน้า 8, Gold/Ruby, ปุ่มควบคุม 5) + แท็บกลุ่ม 6 · ปุ่มหน้า 120→140, ปุ่มควบคุม 190→220 · lint/type 0 error · Play: 18 รูปโหลดครบ (PreloadAsync fail 0), ดู screenshot แล้ว · ยังไม่ทดสอบ: compact (มือถือ), ปุ่ม 220 หลังขยาย, Studio ใช้ Source ที่ patch มือ (Rojo ไม่ได้ต่อ)
