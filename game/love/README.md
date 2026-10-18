# Oyun — LÖVE2D 2D world runtime

The 2D engine lives in `game/love/` on `main`, with an
independent `experiment/world-2d-design-20261012` history. The Godot 3D scaffold
in the repository root is **historical**, not the agreed 45-degree 2D direction.
The branch is intentionally isolated: do not merge the old branch wholesale
into `main`, because `main` contains newer Object Studio changes.

## Run

Install LÖVE 11.5 on desktop and launch from repository root:

```sh
love game/love
```

Keyboard: WASD/arrows pan the camera; mouse drag to pan, wheel to zoom,
click polygon to select, R to reset, Escape to clear. On Android:
one-finger drag pans, tap selects, two-finger pinch zooms; on-screen
+/−/R controls work with touch. UI accommodates portrait dimensions,
resizes and safe-area insets.

The main entrypoint now includes seeded continuous terrain, Marching Squares,
chunk streaming, player physics/A*, object harvesting and traversable water.
Resource gameplay constants are generated from JSON catalog for packaged LÖVE.
The older polygon scene remains a Stage 1 test fixture. Stage5 crafting, inventory and workbench placement are playable on main.
Stage6 save/recovery and detached Stage5 transaction bridge are opt-in only
via OSMAN_STAGE6_EXPLICIT=1 and an explicit world UUID. Autosave and crash-
durable Android filesystem guarantees remain unverified; no production save
is silently created. Android APK and networking are not yet verified. World units are continuous,
no visible tilemap.

## Test

```sh
cd game/love
lua5.4 tests/run.lua
lua5.4 tests/runtime.lua
find . -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
```

GitHub Actions `LOVE biome core validation` performs Lua syntax and unit
tests and launches the real LÖVE render loop under Xvfb for three frames
on the experiment branch. CI proves startup/render smoke, **not** visual
correctness or Android compatibility. Those require real engine and device
tests in subsequent work.

## Boundaries

Preserve backup branch, `main`, World Builder, Terrain Studio, Object Studio,
other experiment branches, external assets, IndexedDB, and user saves.
No texture files were added; existing 18 terrain variants are out of scope.

## Core stat progression V1 (session-only)

Player gains general character XP from successful RAM-only resource harvest/craft/build.
Character level rewards free stat points; STATS touch panel or keyboard P spends them.
Core Level is separate: all six stats share a ceiling and all Core types share normal
skill capacity at the same Core level. Future skill definitions unlock typed actions
and earn separate usage XP; feat/proficiency systems are not adopted.

Run: cd game/love && lua5.4 tests/core_stat_progression.lua
Also run LuaJIT, quality CI and real LÖVE/Xvfb production UI smoke.

IMPORTANT: numeric curves are provisional. This demo does NOT upgrade Core,
transfer consciousness, activate skills, or persist progression in save_v2.
Stage6 explicit play does NOT award session XP to avoid non-atomic cross-save commits.
The HUD displays SESSION ONLY / NOT SAVED. Do not mistake test snapshot/restore
for production durable saving. A new versioned save contract and migration are required.
