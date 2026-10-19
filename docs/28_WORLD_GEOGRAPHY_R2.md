# Round 2 A — approved overworld scale, geography and exploration graph

Decision gate: **approved 2026-10-18**. State: versioned **authoring contract**, not a game runtime switch. Starting production engine remains 45° isometric LÖVE2D and `generator_version=1`.

## Canonical sources and existing v1

- New global manifest: `data/worldbuild/osman_overworld.v2.json` (`osman-worldmap-v2`, schema `schemas/worldbuild-map-v2.schema.json`).
- Its Fısıltı Ormanı authored source: `data/worldbuild/fisilti_ormani.r2.v1.json` (existing `osman-worldbuild-v1` interchange, validated with the original v1 schema and geometry validator).
- The former `data/worldbuild/fisilti_ormani.v1.json` is **retained byte-for-byte as a pilot**. It is **not** the final world size or region catalogue. Its three region objects and two connector objects survive unmodified in the new authored source; the original main-path coordinates remain the prefix of the expanded path. This preserves prior stable IDs and all old test fixtures.
- `worldmap:osman-overworld` is the separate global manifest ID. `worldmap:fisilti-ormani` remains the authored child map ID; these do not replace any saved `world_id`.

## World bounds, extension and compatibility

- Bounds (world units): `[-4096, -4096)` origin to `(28672, 28672)` maximum: a **32,768 × 32,768** initial square. For membership, minima are inclusive and maxima exclusive, so future adjacent map tiles can share an edge unambiguously.
- Cardinal frontier *design intents*: north mountain ridge, west highlands, east sea cliffs, south coast. **No coastline/obstacle mesh is generated here.** `bounds.enforcement=design_only`: active `WorldQuery` still generates outside; a later adapter must explicitly apply physical frontiers and test them. Do not claim there is a physical invisible wall today.
- Future growth uses adjacent separately versioned maps, preserving old global coordinates, seed and immutable IDs. No coordinate rebasing; changes require migration decisions before runtime activation.
- Global hierarchy: `worldmap:osman-overworld` → four **nonoverlapping area partitions** → authored source maps / `region:*` polygons → stable `site:*` anchors; `connector:*` is the region adjacency graph and `feature:*` contains author-intent path/water polylines. Logical area rectangle boundaries are **not** rendered tile edges or biome cuts.
- Generator v1 fallback: inside global bounds, outside every authored polygon, retain generator-v1 world sampling. Region boundaries are resolved in lexicographic region-ID order. Outside global bounds returns authoring result `out_of_bounds`, *not* a claim that current Lua runtime clips travel. The v1 authored source remains `intent_only` for water/path and cannot alter real traversal water, collision, saves, object IDs or Stage5/6 transactions. `seed=20261018`, `generator_version=1`, world-space coordinates and original biome variant vocabulary are retained.

## Authored/procedural distribution

Target at **world maturity**: **10–20% authored polygon surface**, **80–90% procedurally sampled**. This target is intentionally **not a minimum enforced on the first authored cluster**. The R2 content is a starter Fısıltı cluster only; do not pretend the entire world has been hand-painted or silently stamp regions over the unbuilt quadrants. The validator computes and prints current authored surface fraction separately from the long-term goal.

| Parent area | Initial policy | R2 authored child |
| --- | --- | --- |
| `area:fisilti-havzasi` (south-west) | authored anchor + procedural surrounding world | `worldmap:fisilti-ormani` |
| `area:guneykiyi` (south-east) | procedural first, future coastline authored work | None |
| `area:kuzey-sirtlari` (north-west) | procedural first, future ridge authored work | None |
| `area:dogu-yaylalari` (north-east) | procedural first, future plateau authored work | None |

The four current *logical* areas partition the rectangle exactly, with CCW axis-aligned polygons and no interior overlap; they are not predetermined future biome themes.

## Fısıltı Ormanı exploration and routing

1. `site:fisilti-uyanis` in `region:fisilti-giris`: safe spawn intent/first resources, not an implemented spawn change.
2. `site:fisilti-yol-ayrimi` in `region:fisilti-koruluk`: main fork, potential first gathering/learning.
3. **Main** `route:fisilti-ana` follows the existing extended `feature:fisilti-ana-patika` through `site:fisilti-dere` to `site:fisilti-kayalik-cikis` in a new rocky pass region. It uses the prior `connector:fisilti-giris-koruluk` and `connector:fisilti-dere-koruluk` unchanged, and the new pass connector.
4. **Optional ruin branch** `route:fisilti-kalinti` reaches `site:fisilti-kalinti` in a new southern clearing through its own stable connector. Reward content is **not authored/placed** by this agent.
5. **Optional northern loop** `route:fisilti-kuzey` exits the old koruluk through `region:fisilti-kuzey-iz` and returns to the old dere area through a separate connector. It is a real topological alternative to the direct koruluk→dere connector, not a disconnected illustration.
6. `site:fisilti-dere-kiyisi` is an additional waterside point on the retained `feature:fisilti-dere-izi` water **intent**; it does not override the generator water channel.

The six region polygons are simple CCW, interior-disjoint, and pass validator portal-width support and route centerline-in-union tests. Sites are strictly inside their referenced regions; a route's site anchors must occur in increasing order on its named path feature, and successive site regions must be connected through matching-anchored path connectors. This is a logical authoring contract, not an AI pathfinding/physics implementation.

## Determinism and guardrails

- IDs are permanently assigned identity strings (`worldmap:`, `area:`, `region:`, `connector:`, `feature:`, `site:`, `route:`), not positional array indices, polygons, chunk coordinates or RNG-derived hashes.
- `scripts/validate_worldbuild_map_v2.py` validates the v2 manifest with JSON Schema, the nested v1 map with the original strict validator, referential integrity, area partition, adjacency graph, site containment, route waypoint order, seed and projection invariants, and authoring fallback.
- Canonical SHA-256 digest normalizes all unordered collections and embeds validated authored-map content. A digest change indicates an authoring contract change; it **does not change any entity ID**. Contract checksum is exposed by the validator CLI for B/E/F consumers.
- `quality.yml` already executes `python -m unittest discover -s tests -v`, thus picks up `tests/test_worldbuild_map_v2.py`, which explicitly runs the v2 validator CLI. No new CI or workflow edit.
- `WorldQuery`, `world-builder`, `main.lua`, `save/`, inventories, progression and other agents' files are not modified. There is **no new LÖVE visual/Android/runtime integration proof in this authoring-only deliverable**. The runtime owner must test exact terrain seam masking, water behavior, collision, deterministic replay and save compatibility before enabling.

## Consumer contracts / dependency handoff

- **B (Builder):** retain old local user storage and v1 interchange, use the manifest as metadata read-only; never implicitly map the v2 manifest to active runtime. Editor must assign immutable IDs and preserve valid route/connector anchors.
- **E (population):** use strict `site:*` as authorial POI anchors, not automatic drop, resource or saved `worldobj:v1:*` IDs. Placement requires separately approved content definitions and deterministic object namespaces.
- **F (integration):** load both formats explicitly and validate before switching; honor same global coordinate/boundary tie-break across visual mesh, physics and harvest; match `generator_version`/seed; future boundary enforcement must not silently erase generator areas or old saves. The global map is optional until those tests pass.

**Acceptance:** verified branch HEAD; v2 manifest and v1 authored-source validation; Python unit and CLI PASS in existing quality GitHub Actions; report in `docs/WORLDBUILD_R2_AGENT_REPORT.md`; exact SHA-256 digest emitted by CLI. `main` merge belongs to coordinator.

## H integration correction — approved 2026-10-19

The R2 authored river `feature:fisilti-dere-izi` was aligned to the existing `site:fisilti-dere` at (704,128), preserving its permanent ID and the route/region/connector IDs. The child R2 river centerline is now `[[536,56],[616,62],[704,128],[735,74]]` (width 22 world units). The original independent v1 pilot is unchanged. The optional `game/love/world/r2_valley_surface.lua` lowers the authoritative B topography by up to 2 world units in the stream center and tapers to zero 47 world units away; A–F consumers use `r2_compat_bridge.lua`. The crossing is validated as a **wet walkable route**, not an installed bridge or shallow ford. Narrow-river diagnostic rendering uses 8-world-unit sampling; the production game/Generator v1/save behavior is **not activated or changed** by the integration. Combined Lua 5.4, LuaJIT, JSON/Node and actual LÖVE/Xvfb preview evidence: [H CI #39244914458](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/39244914458). Existing Stage6 save migration and Android device validation remain open.
