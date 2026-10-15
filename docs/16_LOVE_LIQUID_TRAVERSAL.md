# Liquid movement & immersion — 2026-10-15

**Behavioral decision:** Water and future liquid surfaces are traversable.
They do not appear in player/pathfinding's solid `obstacles()` API.
Entering water reduces movement speed to 55% and visually submerges the
bottom half of the placeholder character; leaving it restores full speed.
No breath, stamina, deep-water block or underwater swimming mode is added.

## Authority separation

- `world/field.lua` determines the semantic `feature`; water is now
  `walkable=true` for the current procedural terrain.
- `world/liquids.lua` defines explicit surface rules. More liquids can
  be introduced with a new rule instead of hard-coded movement logic.
- `objects/query.lua` supplies ONLY solid resources to swept AABB/A*,
  and a `surface_at(x,y)` query for movement and immersion. Missing real
  world data raises instead of faking dry terrain.
- `world/collision_adapter.lua` continues to derive a conservative
  dry-site exclusion mask using Marching water patches. **Only resource
  placement** uses this mask; it no longer blocks players. Existing
  shoreline geometry and object placement remain deterministic.
- `player/controller.lua` reads surface speed at fixed 60 Hz physics
  step and stores immersion at the new position. Original motion/CCD and
  standability for rocks/trees are unchanged.
- `objects/renderer.lua` clips the figure at the waterline and draws a
  subdued submerged portion plus surface ripples. The player and objects
  still use world-foot Y-depth.

The speed change at the shoreline is per physics tick, not a gradual
interpolation. The liquid is a gameplay medium, not a terrain obstacle.
A* remains distance-oriented and can traverse water; it is not yet a
speed-weighted optimal travel-time planner.

## Acceptance

Pure Lua test checks dry/wet fixed-step speed, entering/leaving water,
object CCD/A*, negative/seeded WorldQuery behavior and unknown liquid
validation. CI additionally runs LuaJIT and real LÖVE screenshots via Xvfb
with `OSMAN_LOVE_LIQUID_SMOKE=1`. Screenshots verify engine drawing,
not Android device behavior or final art quality. Current save/catalog
systems and user data are unchanged; full water visuals/art remain later.

## Current data-system caution

JSON catalog/schema exists, but `objects/definitions.lua` replicates
resource gameplay settings in Lua instead of loading them from canonical
JSON. Sparse object delta and temporary Wallet are in memory; no versioned
atomic LÖVE save, inventory/crafting, or migration exists yet. Future data
audit should compare Definition/Instance/State/Visual, schema consistency,
generator_version persistence, event ownership and catalog adapters.
