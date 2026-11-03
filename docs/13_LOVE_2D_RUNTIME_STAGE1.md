# Stage 1 — LÖVE2D runtime, updated 2026-10-15

## Current decision
The user chose 45-degree isometric 2D with LÖVE2D, procedural continuous
terrain with Marching Squares planned (not square-tile visuals). The root
Godot 4.6.3 real-3D scaffold and README describe the **former design**.
Keep them for historical reference; do not silently repurpose old data.

The original `experiment/world-2d-design-20261012` branch contains the
three-biome sample + World Builder. Stage 1 reuses its verified `world.iso`,
`world.regions`, `world.biomes`, and `world.scene` rather than duplicating
them, and creates an actual desktop/mobile input runtime in `game/love`.

## Phase gates

1. **Current phase:** boot, camera transform with anchor-preserving zoom,
   scene, keyboard/mouse/touch and pinch gestures, safe-area-aware HUD,
   deterministic pure Lua validation. Runtime visuals remain placeholders.
2. Procedural seeded biome fields, continuous contour boundaries via
   Marching Squares, chunk streaming, seams and generation tests.
3. Character sprite, animation, movement, physics and collision.
4. Interactable objects, gather and state changes.
5. Inventory, recipes, crafting, building.
6. Versioned atomic save/load and migration safety.
7. Android LÖVE APK pipeline, rendering/performance and real-device tests.
8. Authoritative two-player multiplayer, sync and reconciliation.
9. Terrain Studio/Object Studio integration, approved asset provenance.

Each phase requires code, deterministic tests, GitHub Actions proof and
separate runtime/device evidence where applicable. No unverified Android
or gameplay performance claims.

## Integration approach
Only the vetted `game/love` runtime files and stage-one documentation were
ported into `main` using a new tree based on its own latest HEAD. The older
experiment's whole tree was never merged. Main-root README/AGENTS now identify
Godot 3D as historical while preserving existing assets, schemas, studio tools
and earlier files.
