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
| <อาการ> | <ไฟล์เจ้าของ> | <doc> |
