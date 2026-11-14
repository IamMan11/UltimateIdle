# Smoke test — รัน Play ใน Studio แล้วอ่าน console ให้เป็นระบบ

ใช้ได้ทุกโปรเจกต์ Roblox · ชื่อ prefix / module / field ในตัวอย่างเป็น placeholder — เปลี่ยนเป็นของโปรเจกต์จริงก่อนใช้ (ถ้าโปรเจกต์มีรายการ prefix ของตัวเอง ให้เขียนไว้ใน `docs/STATE.md` → Regression runs)
เครื่องมือ = Roblox Studio MCP (`get_studio_state` · `start_stop_play` · `execute_luau` · `get_console_output`)

**เมื่อไหร่รัน:** เฉพาะเมื่อผู้ใช้สั่ง ("รัน smoke", "ทดสอบดู", "เช็กว่าพังไหม") หรือใส่ไว้ในงานตั้งแต่ต้น
**เมื่อไหร่ห้ามรัน:** เพื่อเช็กงาน UI/ภาพ (ผู้ใช้ดูเองและบอกเอง) · หลังแก้โค้ดโดยไม่ได้ถูกสั่ง · ตอนผู้ใช้กำลังใช้ Studio อยู่
smoke test ตอบแค่ "boot ได้ไหม มี error/warn ไหม state ตรงที่คาดไหม" — "เล่นได้" ยังหมายถึงคนเล่นจริง

## ขั้นตอน (ทุกครั้งเหมือนกัน)

1. **ก่อนเริ่ม:** `rojo serve` ต้องรันอยู่และ Studio เชื่อมแล้ว (`get_studio_state` → ไม่ได้อยู่ใน play mode) · โค้ดผ่าน `stylua` + `selene` แล้ว
2. **เริ่ม Play** (`start_stop_play`) แล้วรอ: boot lobby 10 วิ · ในรอบ 30 วิ
3. **อ่าน console** (`get_console_output`) — อ่านเฉพาะส่วนท้าย ไม่ dump ทั้งหมดลงบริบท แล้วให้คะแนนตามตารางข้างล่าง
4. **ถาม state จาก server** ด้วย `execute_luau` ถ้าต้องยืนยันมากกว่า "ไม่มี error" — รันตัวนี้ก่อนครั้งแรกของ session เพื่อรู้ว่า `execute_luau` อยู่ context ไหน:
   ```lua
   local RunService = game:GetService("RunService")
   print("server", RunService:IsServer(), "running", RunService:IsRunning())
   ```
   ถ้า `server true running true` → ถามได้ตรง ๆ (ตัวอย่างล่าง) · ถ้าไม่ใช่ → ใช้ได้แค่ console และสิ่งที่ผู้ใช้ทำเองผ่าน dev panel
5. **หยุด Play** เสมอ (`start_stop_play`) — ห้ามปล่อย play mode ค้าง
6. **บันทึก 1 บรรทัด** ใน `docs/STATE.md` → Session log: วันที่ · แก้อะไร · ผล (PASS/WARN/CRASH) · บรรทัด error แรก

## ให้คะแนน

| ผล | เงื่อนไข |
|---|---|
| PASS | ไม่มี error stack ไม่มี `warn` จาก prefix ของเรา และ (ถ้ามี) `--expect` ทุกตัวขึ้น |
| WARN | มี warn จาก prefix ของระบบเรา (เช่น `[RunManager]` `[PlayerData]` `[Lobby]` — แต่ละ module ควร warn ด้วย `[ชื่อ module]` นำหน้า) แต่ไม่ล้ม — อ่านทีละบรรทัด ส่วนใหญ่คือบั๊กจริง |
| CRASH | error stack ใด ๆ · log ที่ loop หลักจับ pcall ได้ (เช่น `[RunManager] step failed:` = ระบบในรอบพัง) · `Infinite yield possible` · `attempt to index nil` · require ล้ม (`Requested module experienced an error`) |

error ที่ loop หลักจับด้วย pcall สำคัญสุด: เกมยังเดินต่อ แต่ระบบที่ล้มหยุดทำงานเงียบ ๆ — ถือเป็น CRASH เสมอ (loop หลักทุกตัวควร log error ที่จับได้ด้วย prefix ชัด ๆ ห้ามกลืนเงียบ)

## ด่านของ smoke (ทำเป็นลำดับ ผ่านด่านก่อนค่อยไปด่านถัดไป)

| ด่าน | ทำอย่างไร | ผ่านเมื่อ |
|---|---|---|
| boot | Play 10 วิ | ไม่มี error · ผู้เล่นมี character (rig ตามที่เกมกำหนด) · โลก/lobby สร้างแล้ว |
| data state | `execute_luau` (server): profile โหลด, ค่าเริ่มต้นถูก | ด้านล่าง |
| gameplay | ผู้ใช้เริ่ม loop หลักของเกม (รอบ/ด่าน/รอบเล่น) หรือสั่งผ่าน dev panel · รอ 30 วิ | ไม่มี error ที่ loop จับได้ · state เดินตามคาด |
| feature | ผู้ใช้เข้าส่วนที่เพิ่งแก้ | เหมือน gameplay + ฟีเจอร์ที่แก้ทำงานจริง (ดูจาก state) |

### `execute_luau` ที่ใช้บ่อย (server context เท่านั้น)

```lua
-- boot: ผู้เล่น + ตัวละคร + lobby
local Players = game:GetService("Players")
local p = Players:GetPlayers()[1]
local char = p and p.Character
print("player", p and p.Name, "rig", char and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.RigType)
print("world ready", workspace:FindFirstChild("<WorldRoot>") ~= nil) -- เปลี่ยนชื่อเป็นของโปรเจกต์
```

```lua
-- lobby state: profile พร้อม
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local p = game:GetService("Players"):GetPlayers()[1]
local profile = PlayerData.Get(p)
print("profile", profile ~= nil, profile and profile.Data.Coins) -- field ตาม PROFILE_TEMPLATE ของโปรเจกต์
```

```lua
-- gameplay: ถาม state จาก module เจ้าของ (ตัวอย่าง: RunManager.GetRun)
local ServerScriptService = game:GetService("ServerScriptService")
local Owner = require(ServerScriptService.Server.Gameplay.RunManager) -- เปลี่ยนเป็น module เจ้าของ state จริง
local p = game:GetService("Players"):GetPlayers()[1]
local run = Owner.GetRun(p)
print(if run then "in run" else "not in run")
```
(ชื่อ module/field ดูจริงในโค้ดก่อนใช้ — ถ้าไม่ตรงให้แก้ snippet ไม่ใช่เดา)

## Regression runs

รายการใน `docs/STATE.md` → "Regression runs" คือ smoke ที่ต้องผ่านหลังแก้ shared code (networking, config/สูตรที่หลายระบบใช้, loop หลัก) — รันทุกตัวเมื่อผู้ใช้สั่งเช็ก ด่านที่เคยผ่านแล้วพังคือสิ่งที่ต้องแก้ก่อนอย่างอื่น

## Circuit breaker

แก้ 3 ครั้งแล้ว smoke ยังพังที่เดิม = หยุดเดา (SKILL.md §4.5): อ่าน STATE.md, ไล่ data flow ในโค้ดจริง, แล้วถามผู้ใช้คำถามเดียว
