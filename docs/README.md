# <ProjectName> — เอกสารระบบ

<สรุปเกม 1–2 บรรทัด: แนว · loop หลัก · สถานะตอนนี้>

เอกสารแยกตามระบบ อ่านเฉพาะอันที่เกี่ยว · ทุกแถวบอกว่า code อยู่ที่ไหน (path ต้องมีจริง)

| ระบบ | อ่านที่ | code อยู่ที่ |
|---|---|---|
| <ชื่อระบบ: สิ่งที่ครอบคลุม> | [system.md](./system.md) | `src/...` |
| ข้อมูลผู้เล่น: โหลด/เซฟผ่าน ProfileStore, `PlayerData.Get(player)` | — (ดู CLAUDE.md § Player data) | `src/server/Data/PlayerData.luau` |
| **สไตล์ภาพ (โมเดล + VFX)** — อ่านก่อนทำ asset ใหม่ทุกครั้ง | [art-style.md](./art-style.md) | — |
| อาการพัง → ไฟล์เจ้าของ | [debug-map.md](./debug-map.md) | — |
| ความจำข้าม session | [STATE.md](./STATE.md) | — |

## โครงสร้างโฟลเดอร์ (`src/`)

ไฟล์ใหญ่แตกเป็นโฟลเดอร์ที่มี `init.luau` · บรรทัดแรกของทุกไฟล์บอกว่าไฟล์นั้นทำอะไร

```
src/shared/      (ReplicatedStorage.Shared)
src/server/      (ServerScriptService.Server)
src/client/      (StarterPlayer.StarterPlayerScripts.Client)
```

## กติกาของเอกสาร

- 1 ระบบ = 1 ไฟล์ · บอก "อะไรมีอยู่ อยู่ที่ไหน ทำงานยังไง" ไม่ใช่ประวัติการแก้ (อันนั้นไป STATE.md)
- ตัวเลขเกมอยู่ใน `src/shared/Config/` — เอกสารอ้างชื่อ config ไม่ copy ตัวเลขมา (จะเก่า)
- แก้โค้ดแล้วพฤติกรรมเปลี่ยน → แก้เอกสารระบบนั้นใน commit เดียวกัน
