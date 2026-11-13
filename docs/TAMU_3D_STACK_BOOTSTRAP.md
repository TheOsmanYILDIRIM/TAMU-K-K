# TAMU 3D ready-stack — 2026-11-13 isolated prototype

## Scope and safety

This branch was created from \`feature/tamu-modular-production-and-farming-20261106\`
at \`6217a2564baebbf2eed9131067103c15f738bac3\`.
**Not** a merge into \`main\`. The old 2.5D startup scene,
\`scripts/main.gd\`, \`project.godot\`, authored source chunk coordinates,
832 stable world object IDs, Stage6 saves and character sources are unchanged.

The additional scene is \`res://scenes/tamu_3d_pilot.tscn\`.
It is a **3D technology integration prototype**, NOT a migrated TAMU game.
Do not claim 3D mobile FPS, save parity, authored R2 parity, dynamic
in-game construction, or playable production mechanics until tested separately.

## Install and test with GitHub Actions

Workflow: [TAMU 3D pinned vendor stack](../.github/workflows/tamu-3d-stack.yml)
on the experimental branch, triggered by push or manual dispatch after
workflow registration. It automatically:

1. Fetches MIT Godot add-ons from the release URL or **specific commit SHAs**.
2. Fetches three CC0 GLBs via **specific Git commit and Git blob SHA-1**
   and records SHA-256 hashes in \`assets/tamu_3d/vendor_manifest.json\`.
3. Rewrites the outdated absolute project prefix in upstream Jeheno
   controller scene/script references **inside only the downloaded folder**.
4. Temporarily enables Jolt Physics and project editor plug-ins in the
   CI workspace (never changes the repository's original \`project.godot\`).
5. Downloads Godot 4.6 stable Linux, imports resources and starts the
   real \`tamu_3d_pilot.tscn\` Godot SceneTree smoke contract.
6. Uploads the add-on/model bundle and log artifacts **only when validated**.
   A passing native smoke does not prove a working Android APK or device FPS.

To install the verified workflow artifact into a separate working copy,
unzip \`tamu-3d-stack-godot46-pinned\` at the repository root, retaining
its \`addons\`, \`assets\`, \`scripts\`, and \`scenes\` structure.
In Godot **4.6** enable Terrain3D, Asset Placer, Phantom Camera and GLoot
in Project Settings > Plugins, and choose Jolt Physics for 3D.
Open \`scenes/tamu_3d_pilot.tscn\` directly. This must not be made the
production main scene before the separate acceptance gate.

## Exact upstream links / license

| Purpose | Source | Pinned version | License |
|---|---|---|---|
| Terrain | https://github.com/TokisanGames/Terrain3D/releases/download/v1.1.0-stable/Terrain3D_v1.1.0-stable.zip | 1.1.0 stable, 45,665,295-byte release ZIP | MIT |
| Editor placement | https://github.com/levinzonr/godot-asset-placer | 1dbf9fd782566780d6a6c52bd4197f448622f0aa (1.6.0) | MIT |
| Camera | https://github.com/ramokz/phantom-camera | d20277eb0f9f7f0068e7aed7d7fe777ab72a0f07 (0.11.0.4) | MIT |
| Character controller | https://github.com/Jeh3no/Godot-Third-Person-Controller | 380d949d2324a4ee6264d96753217ddfbaaab9ab | MIT |
| Inventory pilot | https://github.com/peter-kish/gloot | ce88b7adc7b952b4df8ebe4836339de334d0d0cc (3.0.2) | MIT |
| CC0 nature and character GLBs | https://github.com/Station-Sciences/bot-crossing/tree/9f7dc6536aacbce2203bb705e3f0cf1772ea3fb7/public/assets | \`forest.glb\`, \`nature.glb\`, \`crew.glb\`, pinned Git blob hashes | CC0, original KayKit/Kenney |
| Optional expanded humanoid animation library | https://quaternius.itch.io/universal-animation-library-2 | 2.1 Standard | CC0 |

The Quaternius package requires an interactive itch.io download. It is
**NOT** automatically downloaded or bundled by the workflow. The playable
third-person controller ships its own animation assets, and the optional
CC0 \`crew.glb\` is included for future retargeting. Do not substitute
paid Source/Pro packages or claim the full 130+ animations are included.

## Plugin responsibilities

- **Terrain3D:** native terrain geometry + one flat starter region and
  simple single-color albedo. Real TAMU region height data must be
  converted and validated later; no procedural world is silently saved.
- **Asset Placer:** install and enable editor brush/collection tool;
  it does not run in the exported game.
- **Phantom Camera:** separate camera host and glued fixed-angle camera.
- **Jeheno:** use its existing FSM \`player_character_scene.tscn\` and animations.
  These desktop input bindings still require mobile touch calibration.
- **Jolt Physics:** Godot 4.6 built-in, no separate plug-in download.
- **NavigationServer3D:** build a minimal pilot navigation region.
  Does not replace TAMU creature pathfinding yet.
- **GLoot:** creates a pilot inventory only. Do NOT migrate or overwrite
  TAMU authoritative Stage6 inventory, world IDs, or user save files.

## Acceptance gates

Source-only: exact SHA/provenance links, pinned versions, Python parse,
no changes to existing TAMU production files.

Native CI: vendor install, actual Godot editor import and SceneTree
startup. A failed import, missing native Terrain3D extension, script path
error, or absent asset is a **failure**; there is no silent placeholder
fallback.

Not yet tested/accepted: physical Android, Mobile/Vulkan/Compatibility FPS,
real Fısıltı Ormanı 3D elevation and 832 object positions,
3D collisions and camera touch, inventory/save migration, package
export/signing, Quaternius retargeting and 3D vegetation LOD comparison.
