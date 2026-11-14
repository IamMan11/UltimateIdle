# UltimateIdle

เกม Roblox ที่เขียนโค้ดนอก Studio แล้ว sync เข้าไปด้วย Rojo
ภาษา **Luau** · แพ็กเกจ **Wally** · จัดการเครื่องมือด้วย **Rokit**

> ก่อนแก้โค้ดครั้งแรก อ่าน [CLAUDE.md](./CLAUDE.md) (กติกาของโปรเจกต์) และ [docs/README.md](./docs/README.md) (เอกสารระบบ)

---

## 1. ติดตั้งครั้งแรก (ทำครั้งเดียวต่อเครื่อง)

### 1.1 โปรแกรมที่ต้องมี

| โปรแกรม                                     | ใช้ทำอะไร                                                         |
| ------------------------------------------- | ----------------------------------------------------------------- |
| [Git](https://git-scm.com/downloads)        | ดึง/ส่งโค้ด                                                       |
| [Roblox Studio](https://create.roblox.com/) | รันและทดสอบเกม                                                    |
| [VS Code](https://code.visualstudio.com/)   | เขียนโค้ด                                                         |
| [Rokit](https://github.com/rojo-rbx/rokit)  | ติดตั้ง rojo / wally / stylua / selene ตามเวอร์ชันใน `rokit.toml` |

**ติดตั้ง Rokit (Windows):** โหลดไฟล์ `rokit-...-windows-x86_64.zip` จาก [Releases](https://github.com/rojo-rbx/rokit/releases/latest) → แตกไฟล์ → เปิด terminal ในโฟลเดอร์นั้นแล้วรัน

```powershell
./rokit.exe self-install
```

ปิดแล้วเปิด terminal ใหม่ เช็กว่าใช้ได้:

```powershell
rokit --version
```

### 1.2 Extension ของ VS Code

| Extension            | ID                          |
| -------------------- | --------------------------- |
| Luau Language Server | `JohnnyMorganz.luau-lsp`    |
| StyLua               | `JohnnyMorganz.stylua`      |
| Selene               | `Kampfkarren.selene-vscode` |
| Rojo (ไม่บังคับ)     | `evaera.vscode-rojo`        |

### 1.3 Clone โปรเจกต์ + ติดตั้งเครื่องมือ

```powershell
git clone https://github.com/IamMan11/UltimateIdle.git
cd UltimateIdle

rokit install            # ลง rojo, wally, wally-package-types, luau-lsp, stylua, selene
rojo plugin install      # ลงปลั๊กอิน Rojo เข้า Roblox Studio
```

> ถ้า `rokit install` ถามให้ trust เครื่องมือ ให้ตอบ yes

### 1.4 ลงแพ็กเกจ + สร้างไฟล์ที่ไม่ได้อยู่ใน git

`Packages/` และ `sourcemap.json` ถูก gitignore ไว้ ต้องสร้างเองหลัง clone:

```powershell
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
```

จากนั้นใน VS Code กด `Ctrl+Shift+P` → **Developer: Reload Window**

> ถ้า selene ฟ้องว่า Roblox API ที่มีจริงไม่รู้จัก (`roblox.yml` หาย/เก่า) ให้รัน `selene generate-roblox-std`

---

## 2. เริ่มทำงาน (ทำทุกครั้ง)

```powershell
git pull
rojo serve               # เปิดค้างไว้ตลอดที่ทำงาน
```

1. เปิด Roblox Studio → เปิด place ของทีม
   (ถ้ายังไม่มี place ให้สร้างจากโค้ด: `rojo build -o UltimateIdle.rbxlx` แล้วเปิดไฟล์นั้น)
2. แท็บ **Plugins** → **Rojo** → กด **Connect**
3. เปิดโฟลเดอร์โปรเจกต์ใน VS Code แล้วแก้ไฟล์ใน `src/` — Studio จะอัปเดตเองทันที

> Rojo ไม่ได้ sync `Workspace`, `Lighting`, `SoundService` — แมพที่สร้างใน Studio ปลอดภัย ไม่โดนทับ

**ถ้า `git pull` แล้ว `wally.toml` เปลี่ยน** ให้รันชุดคำสั่งข้อ 1.4 ซ้ำ

---

## 3. ก่อน commit

```powershell
stylua src/              # จัดฟอร์แมต
selene src/              # lint — ต้องไม่มี error
```

แล้วค่อย commit:

```powershell
git checkout -b feature/<ชื่อฟีเจอร์>
git add .
git commit -m "<สิ่งที่ทำ>"
git push -u origin feature/<ชื่อฟีเจอร์>
```

แล้วเปิด Pull Request บน GitHub

---

## 4. โฟลเดอร์ไหนไปอยู่ตรงไหนใน Studio

| ในโปรเจกต์    | ใน Roblox                                   |
| ------------- | ------------------------------------------- |
| `src/shared/` | `ReplicatedStorage.Shared`                  |
| `src/server/` | `ServerScriptService.Server`                |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |
| `Packages/`   | `ReplicatedStorage.Packages`                |

นามสกุลไฟล์กำหนดชนิด: `.server.luau` = Script · `.client.luau` = LocalScript · `.luau` = ModuleScript · ใช้ `.luau` เสมอ ห้าม `.lua`

---

## 5. ห้ามทำโดยไม่ถามก่อน

- เพิ่มแพ็กเกจใน `wally.toml`
- แก้ `default.project.json` (โดยเฉพาะเพิ่ม service)
- เปลี่ยน `languageMode` ใน `.luaurc`
- ลบ field หรือเปลี่ยนชนิดใน `PROFILE_TEMPLATE`
- แก้ `.gitignore`
- แก้ไฟล์ที่ generate อัตโนมัติ: `Packages/`, `sourcemap.json`, `wally.lock`, `roblox.yml`, `ProfileStore.luau`

---

## 6. แก้ปัญหาที่เจอบ่อย

| อาการ                                                   | วิธีแก้                                                                                   |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `rojo` / `wally` : command not found                    | ยังไม่ได้ `rokit install` หรือยังไม่ได้เปิด terminal ใหม่หลังลง Rokit                     |
| `Unknown type 'X.Y'`                                    | รัน `wally-package-types` (ข้อ 1.4) · บางแพ็กเกจ (Red, Promise) ไม่มี type ให้ใช้อยู่แล้ว |
| `$path that could not be turned into a Roblox Instance` | ยังไม่มี `Packages/` → `wally install`                                                    |
| `Failed to update sourcemap … cannot find the path`     | VS Code → **Reload Window**                                                               |
| แก้โค้ดแล้ว Studio ไม่เปลี่ยน                           | เช็กว่า `rojo serve` ยังรันอยู่ และกด Connect ในปลั๊กอินแล้ว                              |
| โค้ด sync เข้าไปแต่ไม่รัน                               | นามสกุลไฟล์ผิด ต้องเป็น `.server.luau` / `.client.luau`                                   |

ดูเพิ่ม: [docs/debug-map.md](./docs/debug-map.md) (อาการ → ไฟล์ที่รับผิดชอบ)
