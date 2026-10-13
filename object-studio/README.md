# Osman World Object Studio

A small mobile-first, fully local browser workspace for authoring seven core isometric game prop families for three biomes. Inspired by Mineclonia Texture Studio's material realism, alpha/silhouette protection, asset-specific production prompts, and non-destructive editing discipline. This is a **production controller**, not an image generator or an online cloud uploader.

## Scope

- Three base biomes: meadow, forest, rocky. Water/path are world features, not additional biome classes.
- Three tree (T-01..03) and four rock (R-01..04) core models.
- Per-object **form** × **surface** variations, with biome preview independent of the actual asset ID.
- Stages 00 art direction, 01 reference, 02 creative transparent square PNG, 03 Image A structure + Image B style correction, 04 explicit user approval (normal/height production postponed). No layer separation: trees and rocks use one complete RGBA sprite.
- Each prompt is per asset; no generic prompt fallback for uncovered assets.
- Main output is 1024×1024 PNG RGBA with isolated alpha. The app accepts square 256–4096 PNG but warns if not 1024. Historic layer images remain in local storage/backups for recovery but are not part of the active workflow.
- The image stays local in IndexedDB `OsmanObjectStudioAssets` / `png-assets`; metadata stays in `osman:object-studio:v1:metadata`. Prior MTS and World Builder DBs are never opened or changed.
- Export a **full JSON backup including binary images**; import explicitly merges and warns that conflicting variant keys replace. No automatic remote upload.
- Independent stage approval; it never silently marks missing art as complete.
- Browser preview renders 45° ground projection, real PNG alpha-silhouette projected soft shadow, editable scale/pivot, and a retained optional **original versus normal-map illumination** lab for previously uploaded maps; no new map production requirement. This is 2D per-pixel lighting only, **not displacement or a LÖVE2D shader proof**.
- Black background repair accepts a separate PNG, flood-fills **border-connected** near-black pixels at a user-specified threshold, shows before/after and downloads a separate transparent PNG. Original IndexedDB assets are not overwritten; dark object edges that physically meet the canvas border must be reviewed.

## Terrain Studio and GitHub save status

- `terrain.html` is a separate, mobile-friendly environment editor linked from the Object Studio start page. Three **shared materials** (grass, soil, stone) each have 2 variants per biome (meadow, forest, rocky): 18 independent material/biome/variant records without inventing more base biomes.
- **Variant source rule:** Each of the three materials uses its existing **first variant** (meadow, index 0) as Image A for every other biome/surface variant. There is no extra base/master PNG or storage key. The first variant is produced independently; each derived variant uses **only the first PNG as Image A plus one authored instruction**, with no second Image B or extra reference-production stage. Preserve material scale, edge continuity and structural family. New UI compares base vs selected variant without touching stored images.
- Terrain prompts follow MTS grounded dark fantasy material language and strict **literal canvas edge tileability**. This is a texture asset workflow, not a plan to show tile-grid seams in the world. Albedo (square PNG) is the only required output. New normal/height-map generation is deferred until the real game visual result is approved. Historical PNG/normal data stay stored and exportable.
- Terrain uses **its own IndexedDB** `OsmanTerrainStudioAssets`, separate from object asset storage. JSON export/import is manual, warns before overwriting matching assets, and never migrates Object Studio IndexedDB/localStorage.
- The Terrain Studio 'GitHub aktarım manifesti indir' button currently downloads the **full local JSON backup**, not a server upload. Nothing is automatically pushed to GitHub.
- `server/terrain-save.ts` is a server-only **not-deployed** backend draft. Its preconditions are a verified Supabase user session belonging to an explicit configured owner UID, restricted GitHub credential stored as Edge secret, strict 3-material path/size/type allowlists, and no preexisting-file replacement. The write path is `assets/terrain/drafts/...`; draft presence does not imply art approval. This code must never be bundled into public Pages. The server was deliberately not deployed because valid owner authentication/configured secret access and permission scoping have not been verified. It is not a working sync button.
- GitHub upload acceptance still needs owner auth and a real end-to-end authorized PNG push, observed new commit/blob and safe error handling; never embed PAT or Supabase service-role key in HTML. The existing Supabase agent GitHub control plane is **not** implicitly a safe browser upload service.

## Important art and geometry boundary

Height maps are *candidate displacement inputs* for a later terrain or object mesh pipeline; normal maps describe lighting gradients. Neither are fully integrated game shaders in this version, and a normal map alone does not sculpt geometry. Trees and boulders must remain readable at target Android distance, with no shadows baked into the transparent PNG.

## Build / test

`npm run verify` builds a self-contained `dist/index.html`, `dist/latest.html` and `dist/build.json`. Build system is a strict first-party ESM bundler (no external dependency, no CDN). Set `BUILD_SHA` for real commit-stamped builds. Tests cover catalog/variants/production contract, build stamping and JavaScript syntax.

## Deployment

Main branch Pages workflow publishes the object studio under `/oyun/object-studio/` and, for URL continuity, re-publishes existing World Builder root previews from the frozen experiment source branch. The legacy experiment Pages workflow can overwrite a main publication if later run; coordinate subsequent world preview updates before shipping. The studio's deployed `build.json` is checked with timestamp+`cache: no-store`; reloads use `latest.html?build=<sha>`; artwork is never cached as a Pages asset.
