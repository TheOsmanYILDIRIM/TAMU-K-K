# Core Plasma 3D overlay — source and handoff

## Purpose
Source for 2D projected 3D-orbit plasma effect. The player Core is an independent
asset already in the `oyun` repository. Do NOT bake a specific Core into the
production front/back sheets.

## Source of truth
- `core_plasma_generator_v4.html`: exact V4 HTML/JavaScript generator with
  four embedded PNG brush textures (ring, ribbon, curl, wisp).
- `core_plasma_settings.json`: user-approved values; do not silently replace.
- `render_core_plasma_sheets.py`: repeatable Chromium/Playwright export to
  independent transparent front/back RGBA sheets.
- `core_plasma_front_spritesheet_32x512.png` and
  `core_plasma_back_spritesheet_32x512.png`: previously rendered output.
- `core_plasma_manifest.json`: frame count, dimensions, sheet order.

## Composition
Draw BACK sheet frame -> current game's Core sprite -> FRONT sheet frame.
Both sheets have 8 columns x 4 rows of 512x512 RGBA frames. Both layers must
use the same frame index, same canvas anchor and scale. Preserve current Core
source and core-specific dimensions; use common normalized orbit bounds.
Render as an optional visual layer only; do not mutate physics, collision,
world state, inventory, save schema or player definition.

## Regeneration
Run in a folder containing the generator HTML, JSON and Python script:

    python -m pip install pillow playwright
    python -m playwright install chromium
    python render_core_plasma_sheets.py --frames 32 --size 512

The original HTML contains the brush PNG bytes inline. No external images
are required to regenerate the effect. The core image inside the HTML is
preview-only and must not be exported into production overlay sheets.

## Known limits
- Browser-based V4 rendering uses projected 3D-orbit geometry and front/back
  depth sign, not a true mesh depth buffer.
- Exported 32-frame set samples t=i*0.42. Perfect loop continuity is NOT
  demonstrated; preview GIF and real LÖVE rendering are different tests.
- No mobile FPS/GPU budget, Android, CI, or in-game integration verified.
- GIF preview and combined spritesheet are NOT runtime dependencies.
- Keep experimental sources and production game data separate until accepted.

## LÖVE2D integration contract
For frame index `f` in [0,31], compute:
    col = f % 8
    row = floor(f / 8)
    quad = (col*512, row*512, 512, 512)
Draw the back quad centered at the player Core screen anchor, draw the Core,
then draw the front quad at the identical anchor/scale. Test immersion and
Y-depth against existing `game/love/player/core_visual.lua` before enabling.


## Existing canonical spritesheets on main
The front/back PNG blobs are already on `main` at the repository root:
`core_plasma_front_spritesheet_32x512-1.png` and `core_plasma_back_spritesheet_32x512.png`.
Their SHA values match the uploaded experiment copies. Do not duplicate binary content.
Import scope is generator, approved settings, manifest and documentation only.

## Verified runtime handoff — 2026-10-18

The older “no in-game integration” entry in this document describes the state *before* the following commits. Current LÖVE production files are:
- `game/love/player/core_plasma_sheet.lua` (32 frame synchronized quads, 12 FPS)
- `game/love/player/core_visual.lua` (back → user Core/crystal shader → front → autonomous tool)
- `game/love/assets/core_plasma_back_spritesheet_32x512.png`
- `game/love/assets/core_plasma_front_spritesheet_32x512.png`
- `game/love/tests/core_plasma_sheet.lua`, `tests/core_avatar.lua`, `tests/core_avatar_smoke.lua`

Evidence: merge `db1598fff9d4147754737c943bd8097b890bc43a`; test corrections `99a8bd099797520e17b326a1624b83a83340e1c9`; successful Lua 5.4/LuaJIT, real LÖVE/Xvfb four-state screenshot and desktop FPS sample in Actions #39120557833 (artifact 12134062458). Screenshot visually inspected. Xvfb sample 266.32 FPS is *not Android performance evidence*.

**Asset contract:** The production Core stays separate; the generator's embedded Core serves previews only. Four embedded brush textures and the approved JSON enable regeneration, but the exact 32-frame sheet sampling is not proven seamless. Existing 4096×2048 sheets are RGBA (8 columns × 4 rows, 512×512 per tile). For any replacement Core keep shared pivot, visual bounds, draw order, and immersion scissor. No re-export is needed for ordinary Core art changes until alignment is proven to differ. Never silently overwrite user's approved `core_plasma_settings.json`.

**Open acceptance:** actual Android maximum texture dimensions, VRAM/FPS and sprite loop seam, plus geometric readability for other Core proportions. Do not confuse CI render with phone test, and do not re-merge retired experiment branches. The design findings and rejected chroma-key/AI-geometric-retouch methods are recorded in `docs/21_CORE_PLASMA_MTS_ART_FX_PIPELINE.md`.
