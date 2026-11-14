# Field notes — ปัญหาจริงที่เจอแล้ว (Roblox · luau-lsp · Studio MCP · Cowork)

สรุปจาก Learned patterns / Dead ends ของโปรเจกต์จริง เก็บเฉพาะข้อที่ไม่ผูกกับเกมใดเกมหนึ่ง · อ่านเมื่อเจออาการตรงหัวข้อ
ข้อของโปรเจกต์เองเขียนใน `docs/STATE.md` ของโปรเจกต์นั้น — ข้อที่พิสูจน์แล้วว่าใช้ได้ทั่วไป ค่อยย้ายมาที่นี่

## R6 / แอนิเมชัน

- `Animate` (สคริปต์ R6 ของ Roblox) ปรับความเร็วท่าเดินตาม WalkSpeed **เฉพาะ id default `180426354`** → ท่าเดิน custom เล่น 1x เสมอ · ต้องสเกลเองฝั่ง client (`track:AdjustSpeed(WalkSpeed / ความเร็วอ้างอิงของท่า)`)
- ท่า R6 ด้วย `Motor6D.Transform`: ไหล่/สะโพกแกว่งรอบแกน Z ของ C0 (`CFrame.Angles(0, 0, a)`) — ไหล่ทั้งสอง +a, สะโพกทั้งสอง −a = เดินสลับปกติ (แกนซ้าย/ขวากลับด้านกันเอง) · X+ = หุบเข้า · RootJoint/Neck: X+ = ก้ม, pos Z = ขึ้น
- Studio **Edit mode** ไม่ solve `Motor6D.Transform` → ต้องการภาพท่าใน Edit = คำนวณ FK เอง (`Part0.CFrame * C0 * Transform * C1:Inverse()`) แล้ววาง copy แบบ anchored
- คลิปที่ผู้ใช้ทำ priority = Action ทั้งหมด → ท่า run ต้องเป็น Action2 (หรือสูงกว่า walk) ไม่งั้น walk ทับ run
- อาวุธที่ผู้ใช้ผูกเป็น Motor6D ใน rig: **pose ของอาวุธอยู่ในคลิปด้วย** → จุดติดในเกม = `C0 * poseอาวุธ * CFrame.new(-center)` ไม่ใช่ C0 อย่างเดียว · ถ้าเกม weld ด้วย `C1 = CFrame.new(-center)` → `mount = C0 * CFrame.new(-center)`

## Mesh / texture / collision

- `MeshPart.TextureID` ไม่ตัด alpha (ส่วนโปร่งแสดงเป็นสี `Color` ของ part / ดำ) → decal/ใบไม้/ลวดลายโปร่ง ใช้ `SurfaceAppearance` + `AlphaMode = Transparency` (สร้างผ่าน Command Bar ได้)
- MeshPart ที่ export แยกตามวัสดุแต่ทั้ง prefab ใช้ `CollisionFidelity = Hull` → hull ครอบหลายชิ้น = กำแพงล่องหน → ของที่เดินผ่าน/รอบ ๆ ตั้ง `PreciseConvexDecomposition` หรือ `Box` ตามรูปทรง
- Roblox ซ่อนหน้าหลังเสมอ (Blender EEVEE โชว์ 2 ด้าน) → แผ่นเปิด/ริบบิ้น ต้องทำ 2 ด้านตอน export (ดู game-assets `vfx.md` §12)
- mesh จาก toolbox ของคนอื่นอ่าน geometry ไม่ได้ (`CreateEditableMeshAsync` = no permission) · `EditableMesh` ต้องเปิดใน Experience Settings → Security
- Studio อาจแสดง mesh เก่าค้าง → ปิด-เปิด Studio หรือเช็กในเกมที่ publish ก่อนสรุปว่าโมเดลพัง

## UI (React-lua)

- เงา/ฉากหลังที่เป็น sibling ZIndex เท่ากับการ์ด → ลำดับวาดไม่แน่นอน (React children เป็น dict) → ตั้ง ZIndex ของเงาต่ำกว่าเสมอ
- `GuiButton.Modal` รายปุ่มมีบั๊ก (ปุ่มห่างขอบล่าง < 58px หรือ AnchorPoint/Position ไม่ default ไม่ทำงาน) → ตั้งที่ backdrop เต็มจอตัวเดียว · `UserInputService.ModalEnabled` deprecated

## Luau / luau-lsp

- table config ที่ cast `:: { "A" | "B" }` ทำให้ literal กลายเป็น `string` → return เป็น union ไม่ผ่าน · ใช้ `string` ใน type ของ config หรือประกาศ `local x: T = {...}` ก่อน return/ส่ง event
- luau-lsp แบบ CLI: `rojo sourcemap default.project.json --output /tmp/sm.json` → `luau-lsp analyze --sourcemap=/tmp/sm.json --definitions=globalTypes.d.luau --base-luaurc=.luaurc --ignore="Packages/**" src` · โปรเจกต์ที่มี error ค้างเยอะ → ดูเฉพาะไฟล์ที่แก้

## Studio MCP

- `execute_luau` รันใน context ไหนไม่แน่นอน → เช็ก `RunService:IsServer()` / `IsRunning()` ก่อนครั้งแรกของ session (ดู `smoke-test.md`)
- `screen_capture` ได้ภาพขาวทั้งจอ = เครื่องผู้ใช้ล็อกจอ → ตรวจภาพด้วย render ใน container จาก transform ที่ export แทน
- อัปโหลดรูปจาก session: `upload_image` รับแค่ http(s) URL · `AssetService:CreateAssetAsync` ใน `execute_luau` → "not available yet" → ให้ผู้ใช้ Bulk Import เอง แล้วส่ง id กลับมา

## Cowork / เครื่องมือ agent

- `device_commit_files` ใช้ stagedPath เดิมซ้ำแล้วไฟล์บนเครื่องไม่อัปเดต (ได้เนื้อหารอบแรก) → copy เป็นชื่อใหม่ทุกครั้งก่อน commit แล้วเช็ก md5 ทั้งสองฝั่ง · หรือแก้ตรงบนเครื่องด้วย python ใน `device_bash` — อย่าสลับสองแบบกับไฟล์เดียวกัน
- **ห้าม `git stash` / คำสั่ง git ที่เขียน index ใน `device_bash`** ก่อนได้สิทธิ์ลบ → ค้าง `.git/index.lock` · ถ้าค้างให้ `mv .git/index.lock .git/stale-index-lock-<เวลา>`
- stylua / selene / luau-lsp / rojo ไม่มีใน VM → โหลด binary Linux รุ่นตาม `rokit.toml` จาก GitHub releases ลง `$HOME/tools` แล้วรัน (ถ้าเครื่องผู้ใช้บล็อกรัน binary ที่โหลดมา = บอกผู้ใช้ว่ายังไม่ได้รัน ห้ามอ้างว่าผ่าน)
- tool timeout ~60 วิ แต่โปรแกรมปลายทาง (Blender/Studio) ทำต่อ → รอแล้วเช็กเวลาไฟล์ผลลัพธ์ แทนการสั่งซ้ำ
