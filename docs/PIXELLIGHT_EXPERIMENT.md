# TAMU PixelLight 2D 1.0.2 isolated integration

Branch: `experiment/pixellight2d-godot46-20261103`.
Godot 4.6 / GL Compatibility, Android target.

The experimental scene is `res://scenes/pixellight_experiment.tscn`. The user-supplied addon-only ZIP is MIT-licensed; demo-town artwork in the larger ZIP must not be redistributed.

## Acceptance gates

- Commit the original plugin's complete `addons/pixel_light_2d/` directory with license (not yet uploaded).
- Keep existing main scene, saved data, HUD, solar clock, Yaprakkulak and original authored atlases unchanged.
- Verify plugin import in Godot 4.6 and a screenshot comparison of baseline / normals / base occluder.
- Add plugin resources to PCK export allowlist. PCK production requires canonical CI asset generation, Godot 4.6 export templates, successful isolated pack boot and verified artifact checksum.
- Physical Android GL Compatibility frametime and visual acceptance remain distinct.

Status: isolated scene is committed; addon source and PCK export are **not completed**. Never present the test scene alone as functional plugin integration or a validated PCK.
