# Modal ใน Roblox (React-lua) — pattern การ implement

อ่านหลัง `SKILL.md` (หลักการทั่วไป) · ไฟล์นี้คือ "ทำยังไงในโค้ด Roblox + React-lua"

**ชื่อในตัวอย่างเป็น convention — เปลี่ยนเป็นของโปรเจกต์จริง:** `GameState` = client store (state + ฟังก์ชัน `Open…/Close…`) · `Common` = ชุด widget + `Theme` (สี/ฟอนต์) · `App` = root component ที่ mount ทุกหน้า/modal · `Shared.Text` = module ข้อความที่ผู้เล่นเห็น · `Net` = event ไป server

อ่านคู่กับ `CLAUDE.md` และ `.claude/skills/roblox-game-dev/references/ui-ux.md` · ถ้าขัดกัน `CLAUDE.md` ชนะ

## 1. เลือกชนิดให้ถูกก่อนเขียน

| ชนิด | บล็อกการกดข้างล่าง | หรี่ฉากหลัง | ปิดเอง | ตัวอย่าง |
|---|---|---|---|---|
| **Toast** | ไม่ | ไม่ | ใช่ (timer) | "บันทึกแล้ว", "ได้รับ +100" |
| **Popup** (แจ้งผล ไม่หยุดเกม) | ไม่ | ไม่ | ใช่ (timer) | ได้ของใหม่ (รูป + ชื่อ) |
| **Modal** (ต้องตอบก่อนไปต่อ) | **ใช่** | **ใช่** | ไม่ — ผู้เล่นปิดเอง | เลือกบัฟตอนเลเวลอัป, ยืนยันขาย, สารานุกรม |
| **Page** (หน้าเต็มใน lobby) | ใช่ (ผ่าน `App` dim) | ใช่ | ไม่ | กระเป๋า, skill tree |

กฎ: ถ้าผู้เล่น **ต้องตัดสินใจ** หรือเนื้อหาต้อง **อ่านนาน** → Modal · แค่บอกผลแล้วหาย → Toast/Popup · ห้ามใช้ Modal แทน Toast (บล็อกเกมโดยไม่จำเป็น)

## 2. State ownership — GameState เป็นเจ้าของเสมอ

- สถานะ "เปิด/ปิด" และ "ข้อมูลที่โชว์" อยู่ใน `GameState` store **ไม่ใช่** `useState` ในคอมโพเนนต์ (ยกเว้น state ชั่วคราวภายใน เช่น แท็บที่กำลังดู, ค่า hover, timer ของ toast)
- เพิ่ม field ใน `State` + ฟังก์ชัน `Open…` / `Close…` ตาม pattern เดิม:

```lua
-- State/GameState.luau
confirm: ConfirmPrompt?,   -- nil = ปิด · มีค่า = เปิด (ข้อมูลอยู่ในนั้นเลย)

function GameState.OpenConfirm(prompt: ConfirmPrompt)
	update(function(state)
		state.confirm = prompt
	end)
end

function GameState.CloseConfirm()
	update(function(state)
		state.confirm = nil
	end)
end
```

- ใช้ `nil` = ปิด แทน boolean + ข้อมูลแยกกัน ถ้าเป็นไปได้ (ลด state ที่ขัดกันเอง) · ถ้าต้องจำ "เปิดอยู่" ข้ามข้อมูล (เช่น Index) ใช้ `xxxOpen: boolean` + `xxxTab`
- Modal ที่มีผลต่อเศรษฐกิจ/ความคืบหน้า (ซื้อ รีเซ็ต ขาย) → ปุ่มยืนยัน **ยิง Net event ไป server** แล้วปิด · server เป็นคนตัดสิน ห้ามแก้ profile ฝั่ง client
- หลังผล server กลับมา (`Notify` / sync) ค่อยปิด modal หรือโชว์ Toast — ห้ามเดาว่าสำเร็จ

## 3. Mount ใน root component (`App`)

- Modal ทุกตัวเป็น child ของ `ScreenGui` ใน `App` (ไม่ซ่อนอยู่ในหน้าใดหน้าหนึ่ง) → เปิดทับได้ทุกหน้าและ ZIndex คุมที่เดียว
- render แบบมีเงื่อนไข: `Confirm = if state.confirm ~= nil then e(Confirm, { prompt = state.confirm }) else nil` — ไม่ใช้ `Visible = false` (เพื่อให้ effect/connection ถูก unmount จริง)
- ลำดับ ZIndex (ScreenGui ใช้ `ZIndexBehavior.Sibling`):

| ชั้น | ZIndex | อะไร |
|---|---|---|
| Dim ของ page | 0 | `App` ใส่ให้เอง |
| Page / HUD | 1 (ค่าเริ่มต้น) | หน้าเต็ม |
| Modal ในรอบเล่น | 5 | เลือกบัฟ |
| Modal ทั่วไปใหม่ | **6–9** | ใช้ช่วงนี้ |
| Global overlay | 10 | สารานุกรม, Toast |
| Dev | 20 | dev panel |

ตั้ง ZIndex ที่ **backdrop** เท่านั้น ลูกข้างในไม่ต้องตั้ง (Sibling behavior สืบทอดลำดับให้)

## 4. โครงสร้างมาตรฐาน (Modal)

```
TextButton  (backdrop: เต็มจอ มืด รับคลิก ZIndex)
└── Frame  (window: ขนาด DESIGN คงที่ กึ่งกลาง + UIScale)
    ├── UIScale + กรอบ/พื้นของ window (จาก widget lib ของโปรเจกต์ เช่น `Common.Modal`)
    └── Content (UIPadding 18–20 · children ที่ส่งเข้า Modal อยู่ในนี้)
        ├── Title   (Common.Label bold, บนซ้าย)
        ├── Close   (Modal.CloseButton บนขวา)   ← ทุก modal ต้องมีทางปิดที่มองเห็น
        ├── Body    (เนื้อหา / ScrollBox ถ้ายาว)
        └── Footer  (ปุ่ม action — ปุ่มหลักขวาสุด)
```

กฎโครงสร้าง:
- **backdrop เป็น `TextButton`** (`AutoButtonColor=false`, `Text=""`) เพื่อกินคลิกไม่ให้ทะลุ · `Frame` เฉย ๆ ไม่กันคลิก
- ขนาดหน้าต่าง **เป็น pixel ตายตัว** (`DESIGN`) แล้ว `Common.useUiScale(DESIGN + Vector2.new(40, 40))` → `UIScale` · ห้ามใช้ Scale เปอร์เซ็นต์ล้วนกับ modal ที่มี text เยอะ
- สี/ฟอนต์/มุมโค้ง จาก `Common.Theme` เท่านั้น · ไม่ hardcode สีใหม่ · backdrop ใช้ `Theme.backdrop` (transparency 0.35–0.5)
- ใช้ `Common.Label` / `Common.Button` / `Common.Panel` / `Common.ScrollBox` ก่อนเขียน instance ดิบ
- ปุ่มทำลายล้าง (รีเซ็ต/ขาย/ลบ) ใช้สี `Theme.danger` (แดง) · ปุ่มยืนยันปกติ `Theme.confirm` (ขาว/ดำทึบ) · ยกเลิกไม่ใส่สี (เทา) · ตัวหนังสือบนพื้นเข้มใช้ `Theme.onColor` / `Common.TextOn(bg)`
- ข้อความ UI ที่แปรตาม id (ชื่อไอเทม ระดับ โหมด) ผ่าน module ข้อความกลาง (เช่น `ReplicatedStorage.Shared.Text`) ไม่ต่อ string เอง

## 5. การปิด — ต้องรองรับครบ

| วิธี | ต้องมี | หมายเหตุ |
|---|---|---|
| ปุ่ม "ปิด"/"ยกเลิก" | **เสมอ** | เรียก `GameState.Close…` ตรง ๆ |
| `Esc` / gamepad B | **เสมอ** (ยกเว้น modal บังคับเลือก เช่น เลือกบัฟตอนเลเวลอัป) | ดูโค้ดด้านล่าง |
| คลิกนอกกรอบ (backdrop) | เฉพาะ modal ที่ **ไม่มีผลข้างเคียง** (ดูข้อมูล/รายละเอียด) | modal ยืนยันซื้อ/รีเซ็ต **ห้าม** ปิดด้วยการคลิกพลาด |

```lua
-- Esc / B ปิด — ผูกตอน mount, ปลดตอน unmount
React.useEffect(function()
	local connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			GameState.CloseConfirm()
		end
	end)
	return function()
		connection:Disconnect()
	end
end, {})
```

- backdrop ที่ปิดได้: ใส่ `[React.Event.Activated] = onClose` ที่ backdrop และ **ต้องมี** `Active = true` ที่ window `Frame` ไม่งั้นคลิกในกรอบทะลุไปปิด
- ปิดแล้ว state ต้องกลับเป็น `nil` **ทุกครั้ง** รวมถึงกรณี run จบ/ออกจากหน้า (ตรวจ `update` ที่เคลียร์ state ตอน `result`/`page` เปลี่ยน)

## 6. Input ระหว่างเล่น (HUD)

- Modal ที่เปิดระหว่าง run (เมาส์ถูก lock / shift-lock): ตั้ง `Modal = true` **ที่ backdrop `TextButton` ตัวเดียว** ให้เมาส์หลุดจาก lock — อย่าตั้งทีละปุ่ม เพราะ `GuiButton.Modal` รายปุ่มมีบั๊กจริง: ไม่ทำงานเมื่อปุ่มอยู่ห่างขอบล่างจอ < 58px หรือมี AnchorPoint/Position ไม่ใช่ค่าเริ่มต้น (backdrop เต็มจอที่ (0,0) ไม่โดนทั้งสองเงื่อนไข) · `UserInputService.ModalEnabled` deprecated แล้ว ห้ามใช้
- ขณะ modal เปิด ต้อง**ไม่ยิง**คีย์สกิล (Q/E/R) ไป server → เช็ค `processed` และ/หรือ flag ใน `GameState` ก่อน Fire
- Toast/Popup ระหว่างเล่นห้าม `Active`/`TextButton` — ต้องปล่อยคลิกทะลุ

## 7. Gamepad / console

- window มีปุ่มอย่างน้อย 1 ปุ่มที่ `Selectable = true` · ตอน mount ตั้ง `GuiService.SelectedObject` ไปที่ปุ่มหลัก (ผ่าน `React.useRef` + `useEffect`) · ตอน unmount ตั้งกลับเป็น `nil`
- ปุ่มในกรอบเชื่อม `NextSelectionLeft/Right/Up/Down` ให้วนครบ ไม่ให้ selection หลุดไปปุ่มหน้าข้างล่าง
- ไม่ต้องทำสำหรับ Toast/Popup

## 8. Template (copy แล้วเปลี่ยนชื่อ)

```lua
--!strict
-- หน้าต่างยืนยัน: ถาม 1 คำถาม ปุ่ม ยกเลิก/ตกลง · เปิดจาก GameState.OpenConfirm · ปิดด้วยปุ่ม/Esc เท่านั้น (ไม่ปิดเมื่อคลิกนอกกรอบ)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Common = require(script.Parent.Common)
local GameState = require(script.Parent.Parent.GameState)

local e = React.createElement
local Theme = Common.Theme

local DESIGN = Vector2.new(420, 200)
local Z_INDEX = 6

export type Props = {
	prompt: GameState.ConfirmPrompt,
}

local function Confirm(props: Props): React.ReactNode
	local scale = Common.useUiScale(DESIGN + Vector2.new(40, 40))

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				GameState.CloseConfirm()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.backdrop,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		-- ปลดเมาส์จาก lock ขณะเปิด (ตั้งที่ backdrop ตัวเดียว ดูข้อ 6)
		Modal = true,
		ZIndex = Z_INDEX,
	}, {
		Window = e("Frame", {
			Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.panel,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Active = true,
		}, {
			Scale = e("UIScale", { Scale = scale }),
			Corner = Common.Corner(12),
			Stroke = Common.Stroke(Theme.stroke, 1, 0.3),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 18),
				PaddingBottom = UDim.new(0, 18),
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
			}),
			Title = e(Common.Label, {
				text = props.prompt.title,
				bold = true,
				size = UDim2.new(1, -100, 0, 30),
				maxTextSize = 24,
			}),
			Close = e(Common.Button, {
				text = "ปิด",
				size = UDim2.fromOffset(80, 30),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				onClick = GameState.CloseConfirm,
			}),
			Body = e(Common.Label, {
				text = props.prompt.body,
				size = UDim2.new(1, 0, 1, -30 - 46 - 24),
				position = UDim2.fromOffset(0, 42),
				color = Theme.subtext,
				maxTextSize = 18,
			}),
			Footer = e("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Cancel = e(Common.Button, {
					text = "ยกเลิก",
					size = UDim2.fromOffset(120, 40),
					layoutOrder = 1,
					onClick = GameState.CloseConfirm,
				}),
				Ok = e(Common.Button, {
					text = props.prompt.okText or "ตกลง",
					size = UDim2.fromOffset(140, 40),
					layoutOrder = 2,
					color = if props.prompt.danger then Theme.danger else Theme.confirm,
					onClick = function()
						props.prompt.onConfirm()
						GameState.CloseConfirm()
					end,
				}),
			}),
		}),
	})
end

return Confirm
```

ถ้ามี modal ลักษณะเดียวกัน **≥ 3 ตัว** ให้ย้าย backdrop+window ส่วนซ้ำเข้า `Common.Modal` (props: `design`, `title`, `onClose`, `closeOnBackdrop`, `zIndex`, `children`) แล้วให้ทุกตัวใช้ร่วมกัน — อย่าก็อปปี้ template ซ้ำเรื่อย ๆ

## 9. Checklist ก่อนบอกว่าเสร็จ

- [ ] เลือกชนิดถูก (Toast / Popup / Modal / Page) ตามข้อ 1
- [ ] state เปิด/ปิดอยู่ใน `GameState` มี `Open…`/`Close…` · ปิดแล้วเป็น `nil`
- [ ] mount ใน root (`App`) แบบ conditional · ZIndex ตามตาราง
- [ ] backdrop เป็น `TextButton` กินคลิก · window `Active = true`
- [ ] ปิดได้ด้วยปุ่ม + Esc/B · คลิกนอกกรอบตามนโยบายข้อ 5
- [ ] ทุก `Connect` มี `Disconnect` ใน cleanup ของ `useEffect` · timer ใช้ `task.delay` + `task.cancel`
- [ ] ขนาด `DESIGN` คงที่ + `useUiScale` · ทดสอบที่ 1920×1080 และ 1280×720 ไม่ล้น
- [ ] สี/ฟอนต์จาก `Theme` · ข้อความผ่าน module ข้อความกลาง
- [ ] action ที่มีผลต่อข้อมูล ยิง Net ไป server · ไม่แก้ profile ฝั่ง client
- [ ] gamepad: `SelectedObject` ตั้ง/คืน · selection ไม่หลุดออกนอกกรอบ
- [ ] formatter + linter ของโปรเจกต์ผ่าน (เช่น `stylua src/` + `selene src/`)
