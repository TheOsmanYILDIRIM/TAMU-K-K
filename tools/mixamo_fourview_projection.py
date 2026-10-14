#!/usr/bin/env python3
"""Four-view image projection ONTO the actual animated Mixamo FBX mesh.

Proof-of-concept: static per-corner UVs assigned in a single reference pose;
the same skinned vertex mesh then plays the original Walking animation.
This is NOT generated 3D geometry, nor does a 2D reference change silhouette.
"""
import bpy
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

DEST = Path("rendered/mixamo_fourview_projection")
REFS = DEST / "references"
FBX = Path("input/Walking.fbx")
# These must match the source pose convention; view order itself is an assumption.
DIRECTIONS = {"SE": (1, -1), "SW": (-1, -1), "NE": (1, 1), "NW": (-1, 1)}
VIEW_SIZE = 512


def new_camera(scene, center, diameter, name):
    data = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    data.type = "ORTHO"
    data.ortho_scale = diameter * 1.30
    return obj


def set_view(obj, target, diameter, xy):
    x, y = xy
    obj.location = target + Vector((x, y, math.sqrt(2))).normalized() * diameter * 2.8
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def bind_pose_geometry(meshes):
    """Read evaluated/skinned reference pose, keeping original vertex indices."""
    dg = bpy.context.evaluated_depsgraph_get()
    result = {}
    for obj in meshes:
        eo = obj.evaluated_get(dg)
        em = eo.to_mesh()
        try:
            if len(em.vertices) != len(obj.data.vertices) or len(em.polygons) != len(obj.data.polygons):
                raise RuntimeError("Topology changed under skinning; cannot safely bind UV")
            pts = [eo.matrix_world @ vertex.co for vertex in em.vertices]
            normals = [(eo.matrix_world.to_3x3().inverted().transposed() @ poly.normal).normalized()
                       for poly in em.polygons]
            result[obj.name] = {"points": pts, "normals": normals}
        finally:
            eo.to_mesh_clear()
    return result


def mapped_uv(p, bounds, reference_bbox):
    # Input camera y increases upwards; PIL reference bbox y increases downwards.
    xmin, ymin, xmax, ymax = bounds
    bx0, by0, bx1, by1 = reference_bbox
    x = (p.x - xmin) / max(1.0e-6, xmax - xmin)
    y = (p.y - ymin) / max(1.0e-6, ymax - ymin)
    u = (bx0 + x * (bx1 - bx0)) / VIEW_SIZE
    v = (VIEW_SIZE - by1 + y * (by1 - by0)) / VIEW_SIZE
    return (max(0.001, min(0.999, u)), max(0.001, min(0.999, v)))


def transparent_alpha(img, uv):
    px = max(0, min(img.size[0] - 1, int(uv[0] * img.size[0])))
    py = max(0, min(img.size[1] - 1, int(uv[1] * img.size[1])))
    return img.pixels[(py * img.size[0] + px) * 4 + 3]


def seam_count(mesh):
    edge_materials = {}
    for face in mesh.polygons:
        for edge in face.edge_keys:
            key = tuple(sorted(edge))
            edge_materials.setdefault(key, []).append(face.material_index)
    joined = [a for a in edge_materials.values() if len(a) == 2]
    cuts = sum(1 for a in joined if a[0] != a[1])
    return cuts, len(joined)


def main():
    if not FBX.is_file() or FBX.stat().st_size != 1839568:
        raise RuntimeError("Pinned Walking.fbx missing or size mismatch")
    prepare = json.loads((DEST / "prepare_manifest.json").read_text())
    for name in DIRECTIONS:
        for suffix in ("_albedo.png", "_reference.png"):
            if not (REFS / (name + suffix)).is_file():
                raise RuntimeError(f"Missing reference file {name}{suffix}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(FBX.resolve()))
    scene = bpy.context.scene
    rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    meshes = sorted((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: o.name)
    if not rig or not meshes or len(rig.data.bones) < 60:
        raise RuntimeError("Mixamo rig/mesh not found")
    act = rig.animation_data.action if rig.animation_data else None
    if not act:
        raise RuntimeError("No active Walking action in FBX")
    start, end = map(lambda x: int(round(x)), act.frame_range)
    if end - start + 1 != 32:
        raise RuntimeError(f"Unexpected action range {start}..{end}")
    scene.frame_set(start)
    skinned = bind_pose_geometry(meshes)
    points = [p for o in meshes for p in skinned[o.name]["points"]]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (low + high) * 0.5
    diameter = max((high - low).length, 0.01)
    scene.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2) else "BLENDER_EEVEE"
    scene.render.resolution_x = VIEW_SIZE
    scene.render.resolution_y = VIEW_SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Transparent_Projection_World")
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0
    scene.world = world

    camera = new_camera(scene, center, diameter, "IsometricSE")
    scene.camera = camera
    bounds = {}
    projectors = {}
    for name, xy in DIRECTIONS.items():
        set_view(camera, center, diameter, xy)
        projectors[name] = camera.matrix_world.copy()
        xy_proj = [world_to_camera_view(scene, camera, p) for p in points]
        bounds[name] = [min(p.x for p in xy_proj), min(p.y for p in xy_proj),
                        max(p.x for p in xy_proj), max(p.y for p in xy_proj)]
    # Build four viewport-image materials, not a flat camera billboard.
    mats = {}
    for name in DIRECTIONS:
        mat = bpy.data.materials.new("CharacterProjection_" + name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        emission = nodes.new("ShaderNodeEmission")
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str((REFS / (name + "_albedo.png")).resolve()))
        tex.extension = "EXTEND"
        uv = nodes.new("ShaderNodeUVMap")
        uv.uv_map = "CHAR_" + name
        links.new(uv.outputs["UV"], tex.inputs["Vector"])
        links.new(tex.outputs["Color"], emission.inputs["Color"])
        links.new(emission.outputs[0], out.inputs["Surface"])
        mats[name] = mat
    ref_images = {n: bpy.data.images.load(str((REFS / (n + "_reference.png")).resolve())) for n in DIRECTIONS}
    labels = list(DIRECTIONS)
    metrics = {}
    for obj in meshes:
        geo = skinned[obj.name]
        faces = obj.data.polygons
        verts = geo["points"]
        obj.data.materials.clear()
        for name in labels:
            obj.data.materials.append(mats[name])
        uv_layers = {}
        for name in labels:
            uv_layers[name] = obj.data.uv_layers.get("CHAR_" + name) or obj.data.uv_layers.new(name="CHAR_" + name)
        # Assign all UV channels per mesh loop from the *posed* vertex position.
        for loop in obj.data.loops:
            p = verts[loop.vertex_index]
            for name in labels:
                camera.matrix_world = projectors[name]
                raw = world_to_camera_view(scene, camera, p)
                rect = prepare["views"][name]["aligned_bbox"]
                uv_layers[name].data[loop.index].uv = mapped_uv(raw, bounds[name], rect)
        counts = Counter()
        uncovered = 0
        # Material preference from real posed face normal, with 2D silhouette support.
        for face_index, poly in enumerate(faces):
            normal = geo["normals"][face_index]
            midpoint = sum((verts[vi] for vi in poly.vertices), Vector()) / len(poly.vertices)
            scores = {}
            alphas = {}
            for name in labels:
                camera.matrix_world = projectors[name]
                to_view = (camera.location - midpoint).normalized()
                facing = max(-1.0, min(1.0, normal.dot(to_view)))
                raw = world_to_camera_view(scene, camera, midpoint)
                uv = mapped_uv(raw, bounds[name], prepare["views"][name]["aligned_bbox"])
                alpha = transparent_alpha(ref_images[name], uv)
                alphas[name] = alpha
                scores[name] = facing + (0.30 if alpha > 0.15 else -0.30)
            choice = max(labels, key=lambda name: scores[name])
            poly.material_index = labels.index(choice)
            counts[choice] += 1
            if alphas[choice] <= 0.15:
                uncovered += 1
        cuts, total_edges = seam_count(obj.data)
        metrics[obj.name] = {
            "vertices": len(verts), "faces": len(faces), "assigned_faces": dict(counts),
            "material_boundary_edges": cuts, "shared_edges": total_edges,
            "boundary_ratio": round(cuts / max(1, total_edges), 5),
            "reference_alpha_uncovered_faces": uncovered,
            "reference_alpha_uncovered_ratio": round(uncovered / max(1, len(faces)), 5),
            "retains_armature_modifier": any(m.type == "ARMATURE" and m.object == rig for m in obj.modifiers)
        }
        if not metrics[obj.name]["retains_armature_modifier"]:
            raise RuntimeError(f"Skinning was lost on {obj.name}")
    set_view(camera, center, diameter, DIRECTIONS["SE"])
    scene.camera = camera
    frames = [start + 4 * i for i in range(8)]
    DEST.mkdir(parents=True, exist_ok=True)
    # Blender source file is uploaded as Actions artifact, not committed binary.
    scene.frame_set(start)
    bpy.ops.wm.save_as_mainfile(filepath=str((DEST / "fourview_projected.blend").resolve()))
    for i, frame in enumerate(frames):
        scene.frame_set(frame)
        scene.render.filepath = str((DEST / ("SE_%02d.png" % i)).resolve())
        bpy.ops.render.render(write_still=True)
    report = {
        "schema": 1,
        "reference_sha256": prepare["proxy_sha256"],
        "full_original_sha256": prepare["full_source_sha256"],
        "fbx_sha256": hashlib.sha256(FBX.read_bytes()).hexdigest(),
        "blender_version": bpy.app.version_string,
        "frame_range": [start, end], "sampled_frames": frames, "camera": "SE: (1,-1,sqrt(2))",
        "rig": rig.name, "bone_count": len(rig.data.bones), "mesh_metrics": metrics,
        "view_assumptions": prepare["view_assignment_assumption"],
        "method": "Reference-pose projected per-loop UV maps; posed deforming Mixamo mesh; four angular face materials; opaque extended source albedo",
        "limitations": [
            "No physical clothing or hair mesh; mannequin silhouette is unchanged",
            "Reference images are shaded oblique illustrations, not calibrated orthographic scans",
            "Four projection islands meet at discrete material edges; UV seams and texture ambiguity expected",
            "Walking deformation may expose unobserved shoulders, crotch, inner limbs, and soles",
            "Lossy 320px proxy is for pipeline validation only",
            "No foot-ground contact inference or real-device test"
        ]
    }
    (DEST / "projection_diagnostics.json").write_text(json.dumps(report, indent=2) + "\n")
    print("FOURVIEW_WALK_RENDER_SUCCESS", len(frames), len(meshes), metrics)


if __name__ == "__main__":
    main()
