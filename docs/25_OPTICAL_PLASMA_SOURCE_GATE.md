# Optical plasma source gate — 2026-10-17 (experiment only)

This is an **independent negative source audit**, not visual approval. Canonical `main` remains `b92baeaf5c54bd4839bcfdb44d0ac916703acc3e`. Beyin task: `oyun-core-plasma-art-assets-20261016`, revision 16, waiting on entry. No main, Stage5/6, backups or original Drive archive are modified.

## Observed sources, without original archive re-upload

- Source inventory, energy experiment `7b7984fdb3d372a9a595b92e39ac2661a2552bdf`: `art-source/core-plasma/2026-10/manifest.json` is `inventory_only_no_binary_import_verified`. `game/love/assets/core_plasma/core_original.png` and **102** frames (`loop/frame_000.png` to `loop/frame_101.png`) are missing from the branch tree. The optical renderer `player/plasma_video_visual.lua` has an explicit geometry fallback.
- Accessible CI artifact `oyun-core-plasma-full-love`, action [#39023821315](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/39023821315): inner `.love` SHA256 `026f26de9edef0ecd9af7305cdb52cdf3345c3d39d898819c4901e21f05ceaac`, 76 entries, **0 PNG**, **0 plasma frames**, core absent. Thus 18 captured 320x700/360x780 FX and water screenshots show the fallback, *not optical/video-backed plasma*.
- Accessible axe full-game artifact inner `.love` SHA256 `7b6cd0ae1915866f2d2adc035f7c7150ede7db3435735f00919d235c9dca6c38`, 75 entries, single `axe_121227.png`; no plasma frames or metal core source.
- Original `core_plasma_all_original_sources.zip` remains safely on user Drive; do not upload another copy or reinterpret its inventory manifest as gameplay-ready image files.

## Gate

Run `python3 scripts/audit_optical_plasma_love.py <approved-art-bearing.love> --approved-core-sha256 <independently-confirmed-64-hex-hash> --require-ready`.
The script also accepts one nested `.love` inside a GitHub artifact zip. It validates 102 named frames, PNG alpha headers and consistent dimensions, frame variability, core provenance hash, and reports `render_ready`. Even `ready_for_visual_review` is **not** optical approval: actual LÖVE/Xvfb smoke for 320x700 and 360x780, visual inspection of normal/slow/breath/level-up/2 rings/3 rings/energy/water, core front/back occlusion, mobile composition, alpha/temporal continuity and GPU/mobile checks are still required.

The original visual screenshots can be inspected as *negative fallback evidence*; they must never be relabeled as optical. No synthetic frames, reconstruction from images, or copied source assets are introduced by this experiment. Core/axe/physics/Y-depth/water/Stage5/Stage6/World Builder/Terrain Studio/Object Studio and user data remain unchanged.
