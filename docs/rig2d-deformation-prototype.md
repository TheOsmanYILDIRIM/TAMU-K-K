# Adventurer 2D rig deformation prototype (local demo, 2026-10-12)

Source model: original Adventurer GLB, SHA256 `4a8639cd8eee9d8a150464edc25eb0536ced464790704a64e40c8620d99f66db`.
The verified Blender reference generator at `tools/blender_rig_reference_v1.py` produces a neutral 512x768 reference, six isolated leg/foot RGBA PNGs and 33 frames of projected bone positions. Successful run: https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/38276909845

A standalone **local offline HTML** playback prototype was produced using these artifacts. It includes canvas triangle-mesh skinning based on projected hip/knee/foot bone movement, frame slider, animation FPS controls, wireframe overlay and full-character ghost reference. The local source package and runnable HTML are attached to the ChatGPT conversation, **not yet committed to GitHub**. In particular, this file does NOT claim that an interactive viewer is deployed through Pages or CI.

Measured initial nearest-reference joint-projection coverage using 8 selected poses (0, 7, 10, 12, 17, 22, 25, 28): mean 10.969 px, max 28.508 px. These are **pose-space distances**, not skin seam quality or foot-ground slip estimates. Neither seam quality nor contact slip has been independently measured.

Outstanding:
1. Integrate offline JS viewer + Python bundler with this experimental branch and CI (no writes to main/backup).
2. Validate the actual HTML playback in a browser and review triangle seams, occlusions and ghost overlap.
3. Infer foot contact times or obtain root-motion/world transforms before claiming slip measurement.
4. Improve per-bone mesh splitting and create quantitative texture/occlusion coverage tests.

This is a partial engineering milestone, not proof that a fully deformable Godot game character is ready.
