# SFX & Game Audio

หลัก: เสียงคือ feedback ที่เร็วที่สุด — **ทุก action ของผู้เล่นต้องมีเสียงภายใน 1 เฟรม** · ความดังสม่ำเสมอสำคัญกว่าความดัง

## 1. Loudness target (Sony ASWG-R001 ที่ทั้งวงการใช้)

| แพลตฟอร์ม | Integrated | True peak | LRA |
|---|---|---|---|
| Console / PC | **−24 LUFS ±2** | ≤ −1 dBTP | ≤ 20 LU |
| Mobile / portable (รวม Roblox) | **−18 LUFS ±2** | ≤ −1 dBTP | ≤ 20 LU |

- วัดจาก gameplay จริง ≥ 30 นาที ไม่ใช่จากไฟล์เดี่ยว
- Master limiter: ceiling −1 dBTP · EQ บน master กว้าง ๆ ≤ 3 dB · มากกว่านั้น = mix ต้นทางผิด
- ระดับสัมพัทธ์ (rule of thumb): dialogue/VO เป็นจุดอ้างอิง 0 · SFX ผู้เล่น −3..0 · ศัตรู −6..−3 · ambience −18..−12 · music −12..−6 (ลด −6 dB อัตโนมัติเมื่อ VO เล่น fade 0.3 s)
- Slider volume เป็น dB ไม่ใช่ linear: `dB = 20·log10(x)` · x ≤ 0.0001 → −80 dB

## 2. ไฟล์ asset (ก่อน import)

- Source: 48 kHz / 24-bit WAV mono สำหรับ SFX 3D · stereo สำหรับ UI/music/ambience
- Peak ต่อไฟล์: −3 ถึง −1 dBFS · ไม่ clip · ตัด silence หัวท้าย (เริ่มที่ transient ภายใน 5 ms · fade-out 10–30 ms กัน click)
- Normalize **ตามหมวด** ไม่ใช่ทุกไฟล์เท่ากัน: UI click −18..−14 LUFS-S · hit/impact −14..−10 · explosion/ult −10..−8 · footstep/ambient −24..−20 · ให้ mixer ปรับช่วงท้าย
- ความยาว: UI ≤ 0.3 s · hit 0.1–0.4 s · สกิล 0.3–1.0 s · explosion ≤ 2 s · ambience loop 20–60 s · music loop ตามท่อน
- Loop: ตัดที่ zero-crossing · ไฟล์ loop ไม่มี reverb tail หลุดท้าย · crossfade ~50 ms ถ้าจำเป็น · sample rate เท่ากันทั้งโปรเจกต์ (44.1 หรือ 48 kHz ปนกัน = คลิกที่ loop)
- ใน build: **ห้าม WAV ดิบ** · SFX สั้น = ADPCM/PCM DecompressOnLoad · เสียงยาว/music = Vorbis/OGG 70–100% streaming · mobile ไม่ใช้ PCM ใช้ Vorbis ~50% · stream พร้อมกัน ≤ 2–4 ตัว
- Roblox: .ogg/.mp3/.wav/.flac · ≤ 20 MB · ≤ 7 นาที · ≤ 48 kHz · Studio transcode ให้ → ส่ง .ogg q5–7 (SFX) / .mp3 192k (music) เพื่อลด upload quota (100/เดือน ถ้ายังไม่ verify)

## 3. Variation (กันเสียงซ้ำน่ารำคาญ)

- เสียงที่เล่นบ่อย (ตี, เท้า, เก็บของ, UI) ต้องมี **3–5 variant** สลับแบบไม่ซ้ำตัวก่อนหน้า (round-robin/no-repeat)
- Randomize ทุกครั้ง: pitch ±3–8% (`PlaybackSpeed` 0.92–1.08) · volume ±1–3 dB · เสียงใหญ่ (explosion) pitch ±2% พอ
- Layer แทนไฟล์เดียว: hit = transient (click) + body (thud) + tail (debris/whoosh) · สุ่มแต่ละชั้นแยกกัน = variation ทวีคูณ
- เสียงสำคัญ (level up, crit, boss phase) **ไม่** randomize มาก — ต้องจำได้
- เกม survivor: ตีโดนศัตรู 50 ตัว/วินาที → **ไม่เล่นทุก hit** · cap ต่อหมวด (เช่น hit ≤ 6 เสียง/0.1 s) · รวมเป็นเสียง "multi-hit" เมื่อเกิน · ลด volume ตามจำนวนที่เล่นพร้อมกัน

## 4. Voices / priority

- Voice limit: iOS 32 · Android 32–64 · Switch 48 · console 128–256 · PC 1024 (software) · Roblox ไม่กำหนดแต่คิดที่ **32** และตั้ง cap เอง
- จอง 25% ให้เสียงสำคัญ (ผู้เล่น, UI, boss) · priority: ผู้เล่น > UI > ศัตรูใกล้ > ศัตรูไกล > ambience
- Steal: priority ต่ำสุดก่อน → เหลือเวลาน้อยสุด → ถ้าขโมยไม่ได้ virtualize (เงียบแต่เดินเวลาต่อ) ไม่ทิ้ง
- Pool `Sound` object · ห้ามสร้าง/ทำลายทุกครั้งที่เล่น · log warning เมื่อ pool หมด (debug)
- ทุก PlayOneShot ผ่าน manager เดียว (ไม่ `Sound:Play()` กระจายในโค้ด) · event id จาก data (`SoundConfig`) ไม่ hardcode asset id ใน gameplay

## 5. Mixer bus

```
Master
├── Music      (Gameplay, Menu)
├── SFX        (Player, Enemies, Environment, UI)
├── Voice      (Dialogue, Barks)
└── Ambient    (World, Weather)
```
- ผู้เล่นปรับได้ 4 slider: Master / Music / SFX / Voice (+ Ambient ถ้ามี) · บันทึกค่า
- Ducking: music & SFX −6 dB เมื่อ voice · music −3 dB ขณะ pause/menu · level-up/result screen ลด SFX bus
- Reverb/snapshot ต่อโซน ไม่ซ้อน reverb zone · Roblox: `SoundGroup` = bus · `SoundService` `AmbientReverb`/`DistanceFactor`

## 6. 3D attenuation (ค่าเริ่ม Unity-scale 1 u = 1 m · Roblox ×3.57 เป็น stud)

| เสียง | rolloff | min | max | spread |
|---|---|---|---|---|
| default | log | 2 m | 50 m | 45° |
| ยิง/ระเบิด | log | 5 | 100 | 30° |
| เท้า/ตีเบา | log | 1 | 20 | 60° |
| ambience | linear | 10 | 50 | 180° |

- ห้ามปล่อย default (linear min 1) · ปรับตามสเกลเกม · UI/ผู้เล่นเอง = 2D ไม่มี attenuation
- Roblox: `RollOffMode` InverseTapered · `RollOffMinDistance`/`MaxDistance` เป็น stud · เสียงผู้เล่นเอง parent ที่ `SoundService`/`PlayerGui` (2D) · ศัตรู parent ที่ part

## 7. Timing / sync

- เสียงต้องออกภายใน **≤ 50 ms** หลัง input (เป้า ≤ 1 เฟรม) → preload เสียงสำคัญ (`SoundService:PreloadAsync` / `ContentProvider`) · DecompressOnLoad · ไม่ stream เสียงสั้น
- เริ่มเสียงที่ anticipation ไม่ใช่ที่ impact (ดู vfx.md) · transient ของ hit ตรงกับเฟรม hitbox ±1 เฟรม
- เสียงที่ติด object: หยุด/fade เมื่อ object ตาย ไม่ปล่อยค้าง · เสียง loop ติดสกิลต้อง stop ทุก exit path
- Pause เกม → pause SFX bus แต่ music/UI เล่นต่อ (ตามดีไซน์) · มือถือ: จัดการ interruption (สายเข้า) และ focus

## 8. Naming

`S_<Category>_<Object>_<Action>_<Variant>` → `S_SFX_Sword_Hit_01.ogg` · `S_UI_Click_02` · `S_AMB_Forest_Loop` · `S_MUS_Boss_Phase2` · ตัวพิมพ์เล็ก/ใหญ่คงที่ · ไม่มีช่องว่าง

## 9. Sharp edges

1. ทุกไฟล์ normalize เป็น 0 dBFS → ทุกอย่างดังเท่ากัน mix ไม่ได้
2. เสียงตีเสียงเดียวซ้ำ 1000 ครั้ง (ไม่มี variant/pitch)
3. ไม่มี voice cap → เสียงหายแบบสุ่มเฉพาะบนมือถือ
4. Sample rate ปนกัน → คลิกที่ loop
5. WAV ดิบใน build → memory/load time
6. Stream เสียงสั้น → ดีเลย์ครั้งแรก
7. สร้าง Sound ใหม่ทุกครั้ง → GC hitch
8. 3D rolloff default → ได้ยินทั้งแมพ หรือไม่ได้ยินเลย
9. Loop ติดสกิลไม่หยุดเมื่อตาย/ออกจาก run
10. Music loop ไม่ seamless (reverb tail / ตัดไม่ตรงบีต)

## 10. Checklist

- [ ] Loudness: mix รวม −18 LUFS (mobile/Roblox) หรือ −24 (console) · peak ≤ −1 dBTP
- [ ] ไฟล์: 48k · peak −3..−1 dBFS · trim/fade · normalize ตามหมวด · ความยาวตามตาราง
- [ ] Format ใน build ตามชนิด · Roblox ≤ 20 MB / 7 นาที / 48 kHz · ไม่มี WAV ดิบ
- [ ] เสียงบ่อย: 3–5 variant · pitch ±3–8% · vol ±1–3 dB · no-repeat
- [ ] Voice cap + 25% reserve + priority + steal/virtualize · pool · manager เดียว · event id จาก data
- [ ] Bus Master/Music/SFX/Voice(/Ambient) · slider dB · ducking −6 dB/0.3 s
- [ ] 3D: rolloff/min/max/spread ตั้งทุกตัว · UI/ผู้เล่น 2D
- [ ] Latency ≤ 50 ms · preload ชุดสำคัญ · เสียงเริ่มที่ anticipation · transient ตรง hitbox
- [ ] Loop: zero-crossing · seamless · หยุดทุก exit path
- [ ] เทส: หูฟัง + ลำโพงมือถือ + TV · ฉากศัตรูมากสุด · 10 นาทีไม่ล้า
