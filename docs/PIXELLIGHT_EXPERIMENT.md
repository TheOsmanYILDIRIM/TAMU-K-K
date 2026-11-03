# TAMU — PixelLight 2D 1.0.2 (genuine addon, isolated)

**Branch:** `experiment/pixellight2d-godot46-20261103` — independent of the native player rig work.
**Source:** user-provided `pixellight-2d-addon-only.zip`, SHA256 `4c340874bfd1ed0b36c03f382a4908abd7fb6bd83a1a26b0e3d10620274b64de`.
All 13 files under `addons/pixel_light_2d/` retain the original Git blob SHA, including MIT license. Demo-town art from the larger ZIP is **not** distributed.
The previously divergent experiment branch was reconciled onto main `eff29ae8` with merge commit `cf7cb3407d4a89d666fe5b5adc17cf25ae12c997`; main itself remains untouched.

## Real CI acceptance

- Native Godot **4.6 GL Compatibility** import and Xvfb scene: `TAMU_PIXELLIGHT_VISUAL_OK normal_maps=2 occluders=1 source=original_addon_1.0.2`.
- The screenshot `pixellight-preview.png` was opened and inspected: three baseline/normal/normal+base-occluder sprites visibly differ.
- Standalone PCK export: `PIXELLIGHT_PCK_CONTENT_OK 33984`, isolated headless pack boot. Test was completed successfully on GitHub Actions [#41737969032](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41737969032), head `2d01a61faccec9c79e110d9811517dde90dfa166`.
- Artifact `tamu-pixellight-isolated-pck` ID `13278734069`, provider digest `sha256:7a90b77544b97407d40e4f7dc1f9d9c3de846c3bf9ce8f2fc448d4ddf083233d`. Contains isolated PCK, SHA256SUMS and visual screenshot.
- This is a desktop renderer/PCK test, **not** real Android compatibility or FPS proof. Known non-fatal Godot preset warnings were emitted during this isolated run; scrutinize them before production export.

## Scope and safety gates

The experiment uses synthetic tree-shaped sprites and runs separately from the TAMU authored world, main scene, HUD, save, Yaprakkulak and solar time. No mass generation of normal maps or 832 R2 occluders is enabled in production. Existing per-object solar shadow cannot be combined blindly with LightOccluder2D or a second CanvasModulate; otherwise overlapping shadows/lighting and heavy mobile draw costs are likely.

**Next acceptance:** inspect pixel-art/2.5D tree/rock art against original authored atlas (do not ship demo art), choose a bounded visible-object sample and compare GL Compatibility Android CPU/GPU p50/p95/p99, draw calls, memory, tree-base shadow anchoring and the existing sun system. Until that gate is satisfied, keep PixelLight opt-in and isolated; no unconditional main-scene lighting.
