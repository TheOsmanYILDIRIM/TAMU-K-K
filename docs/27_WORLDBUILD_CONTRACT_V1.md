# Worldbuild A — authored region / WorldQuery contract v1

Status: 2026-10-18 experimental, data+validation only. Not a production world switch.

## Scope and sources

- Canonical format: `schemas/worldbuild-region-v1.schema.json`.
- First **provisional layout**: `data/worldbuild/fisilti_ormani.v1.json`.
- Strict checks: `scripts/validate_worldbuild_contract.py` and `tests/test_worldbuild_contract.py`.
- Active engine reference: `game/love/world/field.lua`, `world_query.lua`, `regions.lua`, `liquids.lua` and `world/collision_adapter.lua`.
- Legacy Godot/voxel world schema is NOT this format; Stage6 `love-world-v2` save is independent. Do not migrate or alter saves here.

This layer formalizes user-directed, small authored regions on top of **Generator v1**. Existing LÖVE2D 45-degree isometric rendering does not expose a visual tile-grid. World coordinates are continuous, not screen coordinates, pixels, tiles or chunk indices. The displayed ISO transform stays (x-y)/sqrt(2), (x+y)/(2 sqrt(2))-z. Region polygons are CCW; boundaries shared by two regions may coincide, but **interiors must not overlap**. The pilot has 3 contiguous organically contoured regions with precisely shared polygon edges and a main path intent; proportions, biome choices and names are DESIGN PLACEHOLDERS pending visual/director approval, not locked biome canon.

## Stable identity and geometry

- Map ID: `worldmap:<slug>`; region: `region:<slug>`; connector: `connector:<slug>`; drawn line: `feature:<slug>`. These are opaque **author-assigned immutable identity strings**, not hashes of coordinates, order, seed, chunk key, catalog def IDs or runtime UUIDs.
- `regions[]` is a set keyed by ID. Every region has biome `meadow/forest/rocky` + a valid existing v1 variant, a finite world-space simple CCW polygon (3..96 points), no duplicate vertices or self-intersection. No two authored polygon interiors overlap.
- `connectors[]` describes an **undirected graph edge**. Its two region IDs are lexicographically sorted; each connector ID is unique. `anchor` lies on BOTH region boundaries and a full `width` world-unit opening fits centered on each corresponding boundary segment. A path or water intent-line with width at least as large as the connector must also pass through that anchor. Connector identity remains constant across edits unless the connection is intentionally deleted/replaced.
- `features[]` are editor INTENT ONLY (`intent_only: true`): ordered world-space path/water centerlines and world-unit widths. Their entire centerline must stay inside the authored region union; they neither create collision nor override fluid behavior until another agent develops and tests the runtime adapter.
- Exact-border lookup is unambiguous: choose the lexicographically smallest applicable region ID; elsewhere query Generator v1 unchanged. Order of regions/connectors/features does not affect identity/digest. World data must not depend on arbitrary array order, local clock or random numbers.

## Builder -> validator -> runtime bridge (integration owned by a separate agent)

1. World Builder's present v2 editor JSON (`version: 2`, `modules` / `paths` / `objects`) is **not** directly the runtime format. Preserve existing `localStorage`/IndexedDB and v1 exported files. Explicit versioned export/mapping must assign permanent IDs; do not infer them from array index or polygon vertices. Convert `modules[].outline` to `regions[].polygon`, resolve meadow/forest/rocky and variants explicitly; reject unknown editor types rather than silently approximating. Convert path/water polylines as `intent_only`; editor decorations are NOT catalog objects or world instances.
2. Validate the complete new map using `python scripts/validate_worldbuild_contract.py data/worldbuild/fisilti_ormani.v1.json`. Reject invalid geometry, broken portals, ID duplicates, unsupported v1 biome variants and unsupported generator versions. Save no partially imported world. The CLI prints a canonical SHA-256 of sorted collections (content provenance, NOT a region ID).
3. Future WorldQuery adapter (other agent): `WorldQuery.new(seed)` remains intact and unchanged outside authored polygons. In an authored polygon, region biome is a proposal requiring explicit adapter integration with mesh, cache, objects, pathfinding and water. All consumers must sample the same authoritative world-space query. NEVER make visual-only override while physics/harvesting still read the old generator; do not overwrite `field:channel` or silently reclassify existing water. Renderer/chunk/obstacle queries and saves must be separately verified before activation.
4. Generator v1 seeded world, biome IDs, global 32/256 grid, deterministic generated object `worldobj:v1:...` IDs, saved sparse deltas and save v2 remain byte-compatible by **not editing runtime** in this agent. Existing water is traversable at 0.55 speed and 0.5 immersion; water isn't a solid. Stage5/6 transactions, Core/plasma, Object/Terrain Studio, backup and user storage untouched.

## Acceptance and handoff

Run `python -m unittest discover -s tests -p "test_worldbuild_contract.py" -v`, `python scripts/validate_worldbuild_contract.py` and existing `quality` CI on branch. Inspect branch HEAD and changed paths after CAS push. A Python geometry plan/render can check polygon seams but is **not** a LÖVE screenshot; no runtime scene visualization or Android proof is claimed. Before enabling overlay in the game, require actual LÖVE/Xvfb visual comparison, chunk seam parity, collision/water and save replay regression, and product review of Fısıltı Ormanı layout.

**Open for other agents:** World Builder export/import UI, shared WorldQuery/mesh/collision integration, placement/save delta namespace for authored content, editing semantics for deleted/split regions, and scenic art/biome authoring decisions. None is implemented by this contract-only agent.
