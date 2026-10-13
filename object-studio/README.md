# Osman World Object Studio

A small mobile-first, fully local browser workspace for authoring seven core isometric game prop families for three biomes. Inspired by Mineclonia Texture Studio's material realism, alpha/silhouette protection, asset-specific production prompts, and non-destructive editing discipline. This is a **production controller**, not an image generator or an online cloud uploader.

## Scope

- Three base biomes: meadow, forest, rocky. Water/path are world features, not additional biome classes.
- Three tree (T-01..03) and four rock (R-01..04) core models.
- Per-object **form** × **surface** variations, with biome preview independent of the actual asset ID.
- Stages 00 art direction, 01 reference, 02 creative transparent square PNG, 03 Image A structure + Image B style correction, 04 optional normal/height materials, 05 explicit user approval. No layer separation: trees and rocks use one complete RGBA sprite.
- Each prompt is per asset; no generic prompt fallback for uncovered assets.
- Main output is 1024×1024 PNG RGBA with isolated alpha. The app accepts square 256–4096 PNG but warns if not 1024. Historic layer images remain in local storage/backups for recovery but are not part of the active workflow.
- The image stays local in IndexedDB `OsmanObjectStudioAssets` / `png-assets`; metadata stays in `osman:object-studio:v1:metadata`. Prior MTS and World Builder DBs are never opened or changed.
- Export a **full JSON backup including binary images**; import explicitly merges and warns that conflicting variant keys replace. No automatic remote upload.
- Independent stage approval; it never silently marks missing art as complete.
- Browser preview renders correct 45° ground projection, schematic silhouettes when no art, real PNG alpha-silhouette projected soft ground shadow (no fixed ellipse), editable scale/pivot, square alpha check, normal and height images.

## Important art and geometry boundary

Height maps are *candidate displacement inputs* for a later terrain or object mesh pipeline; normal maps describe lighting gradients. Neither are fully integrated game shaders in this version, and a normal map alone does not sculpt geometry. Trees and boulders must remain readable at target Android distance, with no shadows baked into the transparent PNG.

## Build / test

`npm run verify` builds a self-contained `dist/index.html`, `dist/latest.html` and `dist/build.json`. Build system is a strict first-party ESM bundler (no external dependency, no CDN). Set `BUILD_SHA` for real commit-stamped builds. Tests cover catalog/variants/production contract, build stamping and JavaScript syntax.

## Deployment

Main branch Pages workflow publishes the object studio under `/oyun/object-studio/` and, for URL continuity, re-publishes existing World Builder root previews from the frozen experiment source branch. The legacy experiment Pages workflow can overwrite a main publication if later run; coordinate subsequent world preview updates before shipping. The studio's deployed `build.json` is checked with timestamp+`cache: no-store`; reloads use `latest.html?build=<sha>`; artwork is never cached as a Pages asset.
