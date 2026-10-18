# Drive source optical plasma — produced experimental .love (2026-10-17)

This work corrects the prior missing-art conclusion by using existing, authenticated Drive data **without re-uploading the original archive to GitHub**.

- Canonical source Drive file: `1S-0zSMvfLODz2E_mdKUER9tTamQ2YiMU`, `core_plasma_all_original_sources.zip`, SHA256 `e54442ee8dcc7dde61bc8600ca4eb34eaf4a8ec05ea31271240a292b0035e4c3`.
- Original metal core: `sources/core/121222.png`, SHA256 `2c63bc1645ab1718e8f612f17a8821ed4f22cd557ffd66c2e506e8d46d2dcf0b`, 1254×1254 RGBA, **unchanged bytes** in `.love`.
- User-approved Veo orbit: `sources/veo/121246_orbit.mp4`, SHA256 `50b2d7a0c810206855ce5120010cf8fe10cd14661799b29ccfa7a345347a5bc6`, 1280×720 24fps. Optical flow closed loop derives 102 frames from [31..146], transition 14, resized 384×216, black-key converted to transparent RGBA; no original MP4 or GIF is baked into game runtime.
- Derived binary assets are **not** committed to GitHub; locally distributed as user-facing downloadable `oyun-core-plasma-optical-drive-v1.love`, SHA256 `eae28172fe1cd9183eab2fa6740caec677f5f88dfb14370b673dc5742fc72710`, 11,369,599 bytes, 175 package entries.
- Composition comes from the archived experimental plasma full-game runtime and selectively preserved current main axe strike integration. It retains game `main.lua`, autonomous tree axe image, procedural rock pickaxe, Stage5 domain logic, and separate optical video renderer `player/plasma_video_visual.lua`. The actual video pixels stay in 102 separate runtime images, not in the user's source video itself.

## Validation
Local ZIP `testzip`, 102/102 distinct 384×216 alpha PNGs, original core SHA, optical video SHA, 103 asset loads and 204 frame quads with Lua mocked graphics; both 320×700 and 360×780 viewport drawing branches, wet scissor and pickaxe smoke; Lua core, plasma controller, render regression, Stage5 transactions, player CCD/A* and 55% water speed/50% immersion all pass in local Lua 5.3 runtime. Note: these tests are **not** actual LÖVE/Xvfb or Android GPU proof.

The static/mobile and GIF preview deliverables are explicitly PIL composites, not actual production LÖVE screenshots. Real LÖVE 11.x with these assets is pending as source-bearing binary cannot be exercised on the local container (LÖVE binary absent), and must not be claimed as validated until captured independently at 320×700 and 360×780. Next check: real LÖVE/Xvfb screenshots for normal/slow/breath/level-up/two/three rings/energy/wet, Y-depth, axe/pickaxe and perf. In this experiment, **main and backup must remain unchanged**. Existing Stage5/6 isolated work and all studios remain untouched.

## Reproduce from Drive without GitHub binary upload

`python3 scripts/drive_optical_generate_frames.py original-archive.zip local-output/assets/core_plasma`

Requires Pillow, NumPy and OpenCV. The script verifies both original SHA256 values and 102 frame uniqueness; production packaging additionally needs approved full-game experimental `.love` sources and axe integration. This repo retains **only** the reproducible extraction script and manifest of local result; no raw media is published.

Beyin tracked task: `oyun-core-plasma-art-assets-20261016`. Optic asset production is finished locally; visual-engine/device acceptance remains waiting.
