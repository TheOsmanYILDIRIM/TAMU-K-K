# Core/plasma + autonomous axe/pickaxe integration (2026-10-17)

## Scope and decisions
The canonical avatar remains a **rigless magical-metal core with procedural plasma**. Main already contained the baseline core and original `assets/axe_121227.png`, and the axe runtime branch's `objects/renderer.lua` blob was identical to main as inspected on 2026-10-17. The experiment branches are intentionally **not** wholesale merged.

Main changes are limited to visual-only `player/axe_strike.lua`, `player/core_visual.lua`, `objects/renderer.lua`, a tool routing regression test, and the core avatar workflow. A large axe (1254x1254 original PNG) was previously rendered at a screen scale up to .28; it obscured the core and mobile hotbar. Now the screen scale is `min(0.048*camera.zoom, 0.085)` and the initial handle offset scales with the drawn image. On trees an original rendered PNG follows the four-phase strike arc and impact VFX; on rocks a lightweight independent procedural pickaxe uses actual harvest elapsed time. No bone rigging is introduced.

## Validation evidence
- Baseline experiment CI, 16 real LÖVE/Xvfb screenshots (tree and rock × 320x700 and 360x780 × windup/strike/impact/recover): https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/39026554715
- Corrected experiment CI, repeated 16 screenshots and 13 Lua 5.4 + LuaJIT test suites, real production Stage5 smoke and real water immersion smoke: https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/39026692599
- Isolated test harness: `experiment/core-plasma-tool-merge-20261017`; only production-ready Lua visuals and focused test/CI hookup were selected for main. Its test-only `main.lua` smoke injection and experiment-only workflow stay out of main.

## Preserved boundaries and limitations
No changes to `main.lua`, physics, collision, Y-depth, water movement (55%)/immersion (50%), `Stage5` domain objects, `Stage6` save/transaction code, user data, World Builder, Terrain Studio, Object Studio, backups, or rig experiments. The CoreVisual water scissor and foot anchor stay unchanged. The plazma video/energy experiment branch is **not** merged: its 102 original frames and core source asset are absent from the checked-out repo package, so fallback render is not final video-based visual proof. Tech/Magic/stat palettes and Android real-device performance remain separate unapproved/unverified work; GitHub CI does not prove actual device performance.
