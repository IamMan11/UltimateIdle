# Roblox — limit และวิธี import (ตรวจจาก create.roblox.com/docs ล่าสุด · API เปลี่ยนบ่อย ถ้าไม่แน่ใจเช็คอีกครั้ง)

## Mesh / Model
- **≤ 20,000 tri ต่อ mesh** (ขาด = แยกชิ้น) · watertight ไม่มีรูหรือ backface โผล่ · ไม่มี zero-thickness · quad ไม่มี n-gon
- Format: .fbx (แนะนำ) · .obj (static) · .gltf/.glb (3D Importer รองรับ) · import ผ่าน **3D Importer** (Avatar → Import 3D) ได้ทั้ง mesh + rig + texture + animation
- สเกล: 1 stud ≈ 0.28 m · ตัวละคร R15 สูง ~5.2 stud · **แนะนำ**: Blender Unit Scale 0.01 (1 unit = 1 stud) + FBX `FBX_SCALE_ALL` + Import 3D "Scale Unit" = Stud — Unit Scale 1 ตรง ๆ จะใหญ่ ×100 (รายละเอียด `roblox-character-pipeline.md`)
- 1 material ต่อ mesh · 1 UV set · UV ใน 0–1 · ทับกันได้
- `RenderFidelity` Automatic (ให้ engine ลด LOD เอง) · `CollisionFidelity` Box/Hull เป็นค่าเริ่ม
- Rig: root bone ที่ 0,0,0 · ทุก bone scale 1 rot 0 · **≤ 4 influence/vertex** · ไม่มี weight บน root · cage ชื่อ `<Mesh>_InnerCage/_OuterCage` (เฉพาะ layered clothing)
- R15 ตัวละคร: bone `Root → HumanoidRootNode → LowerTorso …` (3 ตัวแรกที่ 0,0,0) · mesh `<Part>_Geo` · ไม่ใส่ HumanoidRootPart mesh และ `_Att` ใน rig ที่ skin (เป็นเศษขาว) — ดู `roblox-character-pipeline.md`
- Animation: **1 track ต่อไฟล์** · 30 fps ค่าเริ่ม (editor ถึง 60) · import เป็น KeyframeSequence → publish เป็น Animation asset

## Texture
- .png / .jpg / .tga / .bmp · สูงสุด 4096² (แต่ PBR/SurfaceAppearance ใช้ ≤ 1024²)
- แนะนำ: วัตถุ 5 stud → 256 · 10 stud → 512 · 20 stud → 1024
- PBR ผ่าน `SurfaceAppearance`: ColorMap (RGB/RGBA) · NormalMap (**OpenGL tangent-space เท่านั้น**) · RoughnessMap (grayscale) · MetalnessMap (grayscale) · + EmissiveMask · `AlphaMode` Overlay/Transparency
- Texture โปร่งใสบน MeshPart ธรรมดา: ใช้ `TextureID` + alpha หรือ `Decal` · อย่าใช้ `Transparency` ของ part กับ texture ที่มี alpha ซ้อน

## Particle / VFX
- `ParticleEmitter.Texture` ≤ 1024² · flipbook: texture จัตุรัส power-of-2 · `FlipbookLayout` Grid2x2 / 4x4 / 8x8 · `FlipbookMode` Loop/OneShot/PingPong/Random
- `Rate` สูงสุดจริง ~ ไม่จำกัด แต่ engine throttle ตาม quality level · ใช้ `:Emit(n)` สำหรับ burst
- `LightEmission`/`LightInfluence`/`Brightness` · `Size`/`Transparency`/`Color` เป็น sequence · `Squash`, `Drag`, `Acceleration`, `WindAffectsDrag`, `Shape`/`ShapeStyle`
- `Beam`/`Trail`: texture ≤ 1024 · `Lifetime` สั้น · ตั้ง `Attachment` 2 จุด
- ไม่มี distortion/soft particle · post-effect: `Bloom`, `ColorCorrection`, `SunRays`, `DepthOfField` (คุมที่ Lighting ทั้งฉาก)
- Quality: ผู้เล่นปรับ 1–10 · อ่าน `UserSettings().GameSettings.SavedQualityLevel` · มือถือตรวจ `UserInputService.TouchEnabled` แล้วลด tier

## Audio
- .mp3 / .ogg / .wav / .flac · ≤ 20 MB · ≤ 7 นาที · ≤ 48 kHz · mono/stereo (3.0/5.1 ได้)
- Upload quota ต่อ 30 วัน: 100 (ยังไม่ ID-verify) / 2,000 (verify แล้ว) · Studio transcode ทุกไฟล์
- `Sound` properties: `Volume` (linear 0–10) · `PlaybackSpeed` (pitch) · `RollOffMode`/`RollOffMinDistance`/`RollOffMaxDistance` (stud) · `SoundGroup` = bus · `TimePosition`, `Looped`, `PlayOnRemove`
- Preload: `ContentProvider:PreloadAsync({sounds})` ตอนโหลด · เสียงเริ่มเล่นได้เมื่อ `IsLoaded`
- Audio ใหม่ (Audio API): `AudioPlayer`/`AudioEmitter`/`AudioListener`/`AudioFader`/`Wire` — ใช้เมื่อต้องการ mixer graph จริง

## UI (ที่เกี่ยวกับ asset)
- Image ≤ 1024² · 9-slice ผ่าน `ScaleType=Slice` + `SliceCenter` · `ImageRectOffset/Size` สำหรับ sprite sheet
- Icon ขนาด 2× ของที่แสดง (เช่น แสดง 48 px → ทำ 96–128 px) เพื่อจอ hi-DPI

## แหล่ง
- Modeling specs: https://create.roblox.com/docs/art/modeling/specifications
- Texture specs: https://create.roblox.com/docs/art/modeling/texture-specifications
- Audio assets: https://create.roblox.com/docs/audio/assets
- Particle: https://create.roblox.com/docs/effects/particle-emitters
