# Debug map — อาการ → ไฟล์เจ้าของ

เริ่มที่เจ้าของ state ไม่ใช่หน้าจอที่เห็นอาการ · path ใต้ `src/` · เพิ่มแถวทุกครั้งที่หาสาเหตุเจอ (session ถัดไปจะเริ่มถูกที่)
อ่านโดย `.claude/skills/roblox-game-dev/SKILL.md` §2.5

| อาการ | ดูก่อน | แล้วค่อย |
|---|---|---|
| Data ไม่ save / รีเซ็ต | `server/Data/PlayerData.luau` (`PROFILE_TEMPLATE`, session ProfileStore) | ห้ามใช้ DataStoreService ตรง |
| Client event ถูกเมิน / error "bad …" | `shared/Net.luau` validator ของ event นั้น · handler ฝั่ง server | `.claude/skills/roblox-game-dev/references/networking.md` |
| UI window / modal เพี้ยน (layer, Esc, focus) | `client/UI/Core/` · state ใน client store | `.claude/skills/ui-modal/references/roblox-react.md` |
| ข้อความผิด / hard-code | `shared/Text/` เท่านั้น | — |
| ตัวเลขผิด | `shared/Config/` (สูตร/ค่า) | balance = แก้ค่าจริง ไม่ใช่ตัวคูณรวม |
| UI ไม่อัปเดตหลังซื้อ/ได้ของ | system เจ้าของเรียก `Replication.Set` ไหม · `client/State/init.luau` applyDelta | `server/Systems/Replication/` |
| ไม่มีอะไรเล่นในด่าน / ด่านไม่เริ่ม | team ว่าง (`Hero.GetTeam`) · `server/Systems/Stage/init.luau` startLevel · client `Battle/init.luau` (attribute `Lane`) | — |
| ด่านแพ้ timeout 180 วิ ทั้งที่ไม่ตาย | `Sim.luau` ระยะตี (`MELEE_SLACK`) กับ Range ของ monster | `shared/Config/Monsters.luau` |
| Toast/notice ไม่ขึ้นตอนเข้าเกม | `Replication.Notify` คิวก่อน snapshot | — |
| ของไม่ drop / ถูกย่อยหมด | `Settings.AutoSalvage` · ความจุ `Inventory.FreeSpace` · `server/Secret/DropTables.luau` | — |
