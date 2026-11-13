#!/usr/bin/env python3
"""Build a clean, isolated *Android application* from TAMU's native 3D pilot.

The full existing TAMU project, authored world, mod catalog, project.godot,
Stage6 exports, 2.5D runtime, and signing configs are never modified.
Called *after* a pinned, SHA-verified vendor download in GitHub Actions.
"""
import argparse
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "tamu-3d-android-src"
REQUIRED_FOLDERS = (
    "addons/terrain_3d",
    "addons/phantom_camera",
    "addons/JehenoThirdPersonController",
    "addons/gloot",
    "assets/tamu_3d",
)
REQUIRED_FILES = (
    "scripts/tamu_3d_pilot.gd",
    "scenes/tamu_3d_pilot.tscn",
)


def make_isolated_project():
    if OUT.exists():
        raise RuntimeError("Refusing to overwrite an existing build directory")
    OUT.mkdir(parents=True)
    for relative in REQUIRED_FOLDERS:
        src = ROOT / relative
        if not src.is_dir():
            raise RuntimeError("Missing vendored folder: " + relative)
        shutil.copytree(src, OUT / relative)
    for relative in REQUIRED_FILES:
        src = ROOT / relative
        if not src.is_file():
            raise RuntimeError("Missing source file: " + relative)
        dest = OUT / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)

    # Proof of platform support: do not claim "Android Terrain3D ready"
    # without the Android-native GDExtension built for the same ABI.
    terrain = OUT / "addons/terrain_3d"
    native = terrain / "bin/libterrain.android.debug.arm64.so"
    ext = terrain / "terrain.gdextension"
    if not native.is_file() or native.stat().st_size < 10000:
        raise RuntimeError("Terrain3D Android arm64 native library missing")
    if not ext.is_file() or b"android.debug.arm64" not in ext.read_bytes():
        raise RuntimeError("Terrain3D GDExtension Android manifest missing")

    (OUT / "project.godot").write_text(
        'config_version=5\n'
        '[application]\n'
        'config/name="TAMU 3D Deneme"\n'
        'run/main_scene="res://scenes/tamu_3d_pilot.tscn"\n'
        'config/features=PackedStringArray("4.6", "Mobile")\n'
        '\n[display]\n'
        'window/size/viewport_width=720\n'
        'window/size/viewport_height=1280\n'
        'window/handheld/orientation=1\n'
        'window/stretch/mode="canvas_items"\n'
        'window/stretch/aspect="expand"\n'
        '\n[autoload]\n'
        'PhantomCameraManager="*res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd"\n'
        '\n[physics]\n'
        '3d/physics_engine="Jolt Physics"\n'
        '\n[rendering]\n'
        'textures/vram_compression/import_etc2_astc=true\n'
        'renderer/rendering_method="mobile"\n'
        'renderer/rendering_method.mobile="mobile"\n'
        'renderer/rendering_method.web="gl_compatibility"\n'
        'rendering_device/fallback_to_opengl3=true\n',
        encoding="utf-8",
    )

    (OUT / "export_presets.cfg").write_text(
        '[preset.0]\n'
        'name="Android"\n'
        'platform="Android"\n'
        'runnable=true\n'
        'advanced_options=false\n'
        'dedicated_server=false\n'
        'custom_features=""\n'
        'export_filter="all_resources"\n'
        'include_filter=""\n'
        'exclude_filter=""\n'
        'export_path="TAMU_3D_Preview_ARM64.apk"\n'
        'script_export_mode=2\n'
        '\n[preset.0.options]\n'
        'gradle_build/use_gradle_build=false\n'
        'package/unique_name="org.osman.tamu.preview3d"\n'
        'package/name="TAMU 3D Deneme"\n'
        'package/signed=true\n'
        'version/code=1\n'
        'version/name="0.1"\n'
        'architectures/armeabi-v7a=false\n'
        'architectures/arm64-v8a=true\n',
        encoding="utf-8",
    )

    # Fail if any existing 2D/authoring files entered the isolated distribution.
    for forbidden in ("game", "chunks", "assets/terrain25d", "scripts/main.gd",
                      "data", "user_data", "export_presets_original.cfg"):
        if (OUT / forbidden).exists():
            raise RuntimeError("Unexpected legacy content in APK staging: " + forbidden)
    print("TAMU3D_ANDROID_SOURCE_READY out=%s" % OUT)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true", required=True)
    parser.parse_args()
    make_isolated_project()
