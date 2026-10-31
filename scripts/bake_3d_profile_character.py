#!/usr/bin/env python3
"""Bake the repo's CC0 Quaternius Adventurer GLB into two 45-degree views.
Run: blender -b -t 2 --python scripts/bake_3d_profile_character.py -- --repo .
"""
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile

try:
    import bpy
    from mathutils import Vector
except ImportError as exc:
    raise SystemExit("Requires Blender: blender -b --python ...") from exc


def args_from_blender():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--repo", type=Path, default=Path("."))
    p.add_argument("--output", type=Path)
    p.add_argument("--frames", type=int, default=8)
    p.add_argument("--width", type=int, default=128)
    p.add_argument("--height", type=int, default=192)
    p.add_argument("--fps", type=int, default=12)
    return p.parse_args(argv)


def pick_action(actions, keyword):
    matches = [x for x in actions if keyword in x.name.lower()]
    return sorted(matches, key=lambda x: (len(x.name), x.name))[0] if matches else None


def main():
    args = args_from_blender()
    assert 1 <= args.frames <= 16 and args.width >= 48 and args.height >= 64
    assert 1 <= args.fps <= 60
    repo = args.repo.resolve()
    source = repo / "Adventurer by Quaternius - 5EGWBMpuXq.glb"
    if not source.is_file() or source.read_bytes()[:4] != b"glTF":
        raise SystemExit("Missing or invalid Quaternius GLB in repository root")
    output = (args.output or repo / "game/love/assets/character_side_bake").resolve()
    output.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    bpy.ops.import_scene.gltf(filepath=str(source))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.world.color = (.35, .35, .35)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    rigs = [obj for obj in scene.objects if obj.type == "ARMATURE"]
    if not meshes or not rigs:
        raise SystemExit("Expected a skinned 3D character with mesh and armature")
    actions = list(bpy.data.actions)
    walk = pick_action(actions, "walk")
    idle = pick_action(actions, "idle")
    if not walk:
        raise SystemExit("Missing walk animation in the GLB; refusing fake walk frames")

    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
    hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
    center = (lo + hi) * .5
    height = max(.001, hi.z - lo.z)
    radius = max(.001, hi.x - lo.x, hi.y - lo.y)

    cam_data = bpy.data.cameras.new("TAMU two-view ortho")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(height * 1.6, radius * 2.25)
    camera = bpy.data.objects.new("TAMU two-view ortho", cam_data)
    scene.collection.objects.link(camera)
    scene.camera = camera

    def area_light(name, offset, power):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = 3.0
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = center + Vector(offset) * height
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()

    area_light("Key", (1.4, -2.2, 3), 500)
    area_light("Fill", (-1.7, 1.1, 1.8), 250)

    # Elevation exactly 45 deg: vertical = sqrt(horizontal_x^2+horizontal_y^2).
    # Front/back share the X side. Reflection gives the other two quadrants.
    views = {"front": Vector((1, -1, math.sqrt(2))),
             "back": Vector((1, 1, math.sqrt(2)))}
    rows, rendered = {}, []
    with tempfile.TemporaryDirectory(prefix="tamu-3d-bake-") as tmp:
        for view, offset in views.items():
            camera.location = center + offset.normalized() * max(3, height * 4)
            camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
            for label, action in (("idle", idle), ("walk", walk)):
                if action is None:
                    for rig in rigs:
                        rig.animation_data_clear()
                else:
                    for rig in rigs:
                        rig.animation_data_create()
                        rig.animation_data.action = action
                        if hasattr(rig.animation_data, "action_slot") and action.slots:
                            rig.animation_data.action_slot = action.slots[0]
                for frame in range(args.frames):
                    if action:
                        first, last = action.frame_range
                        scene.frame_set(round(first + (last - first) * frame / args.frames))
                    else:
                        scene.frame_set(1)
                    name = f"{view}_{label}_{frame}"
                    dest = Path(tmp) / (name + ".png")
                    scene.render.filepath = str(dest)
                    bpy.ops.render.render(write_still=True)
                    img = bpy.data.images.load(str(dest), check_existing=False)
                    pixels = array("f", [0]) * (args.width * args.height * 4)
                    img.pixels.foreach_get(pixels)
                    bpy.data.images.remove(img)
                    rendered.append((name, pixels))
                rows[f"{view}_{label}"] = len(rows)

    xmin, ymin, xmax, ymax = args.width, args.height, -1, -1
    for _, data in rendered:
        for y in range(args.height):
            for x in range(args.width):
                if data[(y * args.width + x) * 4 + 3] > .02:
                    xmin, ymin = min(xmin, x), min(ymin, y)
                    xmax, ymax = max(xmax, x), max(ymax, y)
    if xmax < xmin:
        raise SystemExit("Rendered atlas is entirely transparent")
    content_w, content_h = xmax - xmin + 1, ymax - ymin + 1
    if content_w > args.width - 4 or content_h > args.height - 4:
        raise SystemExit("Character exceeds frame; increase scale/canvas or ortho size")
    atlas_width = args.width * args.frames
    atlas_height = args.height * 4
    packed = array("f", [0]) * (atlas_width * atlas_height * 4)
    dx = (args.width - content_w) // 2
    dy = 3  # Blender pixel rows are bottom-up; shared bottom-center foot pivot.
    for name, data in rendered:
        view, label, index = name.rsplit("_", 2)
        row = rows[f"{view}_{label}"]
        for y in range(content_h):
            # Blender Image.pixels is bottom-up, while PNG/LÖVE atlas rows are top-down.
            dst_y = (3 - row) * args.height + dy + y
            dst = (dst_y * atlas_width + int(index) * args.width + dx) * 4
            src = ((y + ymin) * args.width + xmin) * 4
            packed[dst:dst + content_w * 4] = data[src:src + content_w * 4]

    atlas = bpy.data.images.new("TAMU_3D_PROFILE", width=atlas_width,
                                height=atlas_height, alpha=True)
    atlas.pixels.foreach_set(packed)
    png = output / "atlas.png"
    atlas.filepath_raw = str(png)
    atlas.file_format = "PNG"
    atlas.save()
    manifest = {
        "version": 1, "source": source.name,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "atlas": png.name,
        "atlas_sha256": hashlib.sha256(png.read_bytes()).hexdigest(),
        "width": args.width, "height": args.height,
        "frames": args.frames, "fps": args.fps,
        "rows": rows,
        "views": {"SE": ["front", False], "SW": ["front", True],
                  "NE": ["back", False], "NW": ["back", True]},
        "camera_pitch_degrees": 45, "bottom_center_pivot": True,
    }
    (output / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
    print("TAMU_3D_BAKE_OK", png, png.stat().st_size, manifest["atlas_sha256"])


if __name__ == "__main__":
    main()
