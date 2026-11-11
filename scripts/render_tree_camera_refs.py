"""Render true orthographic multi-elevation camera references from a CC0 GLB."""
import bpy
import json
import math
import os
from mathutils import Vector

SOURCE = os.environ.get("TAMU_TREE_GLB", "source/tree_oak.glb")
OUTPUT = os.environ.get("TAMU_OUT", "tree-camera-refs")
os.makedirs(OUTPUT, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert meshes, "GLB has no mesh objects"
points = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
minimum = Vector(tuple(min(v[i] for v in points) for i in range(3)))
maximum = Vector(tuple(max(v[i] for v in points) for i in range(3)))
center = (minimum + maximum) / 2.0
extent = maximum - minimum
assert min(extent) >= 0 and max(extent) > 0.01, "bad bounds"
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.world.color = (0.26, 0.26, 0.26)
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
camera_data = bpy.data.cameras.new("TAMU_Orthographic")
camera = bpy.data.objects.new("TAMU_Orthographic", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = max(extent.x, extent.y, extent.z) * 1.55

light_data = bpy.data.lights.new("Overcast_Area", type="AREA")
light = bpy.data.objects.new("Overcast_Area", light_data)
scene.collection.objects.link(light)
light.location = center + Vector((0, 0, max(extent) * 3.0))
light_data.energy = 900.0
light_data.shape = "DISK"
light_data.size = max(extent) * 6

# Zero camera roll; orthographic axes derived from a single physically consistent 3D model.
azimuth = math.radians(45)
manifest = {"source": SOURCE, "model_bounds_xyz": list(extent), "azimuth_degrees": 45,
            "projection": "ORTHO", "elevations": [20, 30, 40, 50],
            "note": "30 degrees yields 2:1 horizontal diamond axis ratio at yaw 45 deg"}
for elevation in manifest["elevations"]:
    el = math.radians(elevation)
    unit = Vector((math.cos(el)*math.cos(azimuth),
                   math.cos(el)*math.sin(azimuth), math.sin(el)))
    camera.location = center + unit * max(extent) * 3.0
    direction = center - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(os.path.abspath(OUTPUT),
                                         "oak_ortho_elev_%02d.png" % elevation)
    bpy.ops.render.render(write_still=True)
with open(os.path.join(OUTPUT, "camera_manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)
print("TAMU_CAMERA_REFERENCE_RENDER_OK", OUTPUT)
