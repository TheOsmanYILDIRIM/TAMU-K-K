"""Deterministic single-view anatomical reference generator. Run with Blender background."""
import bpy, math, json, hashlib, pathlib, bmesh
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

SOURCE = pathlib.Path("assets/walk_source/adventurer.glb")
OUT = pathlib.Path("rendered/rig_ref_v1")
OUT.mkdir(parents=True, exist_ok=True)
EXPECTED = "4a8639cd8eee9d8a150464edc25eb0536ced464790704a64e40c8620d99f66db"
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == EXPECTED, "Incorrect GLB"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE.resolve()))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
action = next(a for a in bpy.data.actions if a.name.endswith("|Walk"))
rig.animation_data_create()
rig.animation_data.action = action
for track in rig.animation_data.nla_tracks: track.mute = True
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
assert meshes, "No meshes"
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2) else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 512, 768
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = "Standard"
scene.frame_set(int(action.frame_range[0]))
corners=[o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
lo=Vector(tuple(min(v[i] for v in corners) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
center=(lo+hi)/2
diam=max((hi-lo).length,1.0)
camera_data=bpy.data.cameras.new("ReferenceIso45")
camera=bpy.data.objects.new("ReferenceIso45",camera_data)
scene.collection.objects.link(camera)
scene.camera=camera
camera_data.type='ORTHO'
camera_data.ortho_scale=diam*1.35
elev=math.radians(45)
az=math.radians(45)
camera.location=center+Vector((math.cos(elev)*math.cos(az),-math.cos(elev)*math.sin(az),math.sin(elev)))*diam*2.5
camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
world=bpy.data.worlds.new("ReferenceWorld")
world.use_nodes=True
world.node_tree.nodes["Background"].inputs["Color"].default_value=(.65,.65,.65,1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value=.8
scene.world=world
light_data=bpy.data.lights.new("ReferenceSoftbox","AREA")
light=bpy.data.objects.new("ReferenceSoftbox",light_data)
scene.collection.objects.link(light)
light.location=center+Vector((diam,-diam,diam*2))
light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
light_data.energy=850
light_data.shape="DISK"
light_data.size=max(diam,1)
target_bones=["Hips","UpperLeg.L","LowerLeg.L","Foot.L","UpperLeg.R","LowerLeg.R","Foot.R"]
assert all(name in rig.pose.bones for name in target_bones), "Required leg bone absent"
first=int(round(action.frame_range[0]))
end=int(round(action.frame_range[1]))
frames=sorted(set([first,first+(end-first)//4,first+(end-first)//2,first+3*(end-first)//4]))
def project(bone):
    b=rig.pose.bones[bone]
    pt=rig.matrix_world @ b.head
    pos=world_to_camera_view(scene,camera,pt)
    return [round(pos.x*512,3),round((1-pos.y)*768,3)]
def capture():
    return {name:project(name) for name in target_bones}
poses=[]
for frame in range(first,end+1):
    scene.frame_set(frame)
    p=capture()
    # Select anatomically distinct samples with 2D knee/ankle displacement; objective is deterministic.
    feature=[v for name in ("UpperLeg.L","LowerLeg.L","Foot.L","UpperLeg.R","LowerLeg.R","Foot.R") for v in p[name]]
    poses.append((frame,p,feature))
def sqdist(a,b):
    return sum((x-y)**2 for x,y in zip(a,b))
chosen=[poses[0]]
while len(chosen)<min(8,len(poses)):
    next_pose=max((p for p in poses if p[0] not in {c[0] for c in chosen}),key=lambda p:(min(sqdist(p[2],c[2]) for c in chosen),-p[0]))
    chosen.append(next_pose)
selected=sorted(p[0] for p in chosen)
# Render only one complete reference; all other time samples are JSON poses, not new textures.
scene.frame_set(first)
scene.render.filepath=str((OUT/"neutral_full.png").resolve())
bpy.ops.render.render(write_still=True)
# Extract geometry by dominant vertex-group influences. Faces overlapping anatomical boundaries
# are intentionally kept in exactly one region; this is a prototype, not a gap-free runtime rig.
parts={}
for name in target_bones[1:]:
    per_part=[]
    for source in meshes:
        if source.name.lower().find("legs") < 0 and source.name.lower().find("feet") < 0:
            continue
        group_ids={g.index:g.name for g in source.vertex_groups}
        if name not in group_ids.values():continue
        selected_faces=[]
        for face in source.data.polygons:
            scores={}
            for vi in face.vertices:
                vertex=source.data.vertices[vi]
                for group in vertex.groups:
                    bone=group_ids.get(group.group)
                    if bone in target_bones[1:]:
                        scores[bone]=scores.get(bone,0.0)+group.weight
            if scores and max(scores,key=scores.get)==name:selected_faces.append(face.index)
        if not selected_faces:continue
        duplicate=source.copy()
        duplicate.data=source.data.copy()
        scene.collection.objects.link(duplicate)
        bm=bmesh.new()
        bm.from_mesh(duplicate.data)
        bm.faces.ensure_lookup_table()
        keep=set(selected_faces)
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES')
        bm.to_mesh(duplicate.data)
        bm.free()
        per_part.append(duplicate)
    if not per_part:
        parts[name]={"status":"no_dominant_faces"}
        continue
    for mesh in meshes:mesh.hide_render=True
    for mesh in per_part:mesh.hide_render=False
    output="part_"+name.replace(".","_")+".png"
    scene.render.filepath=str((OUT/output).resolve())
    bpy.ops.render.render(write_still=True)
    parts[name]={"file":output,"mesh_objects":len(per_part),"status":"rendered"}
    for obj in per_part:
        bpy.data.objects.remove(obj,do_unlink=True)
    for mesh in meshes:mesh.hide_render=False
manifest={
 "schema_version":1,"source_sha256":EXPECTED,"camera":{"elevation":45,"azimuth":45,"orthographic":True,"resolution":[512,768]},
 "animation":action.name,"animation_frame_range":[first,end],"selected_frames":selected,
 "all_motion_frames":[{"frame":f,"joints":j} for f,j,_ in poses],
 "part_reference_frame":first,"parts":parts,"full_image":"neutral_full.png",
 "scope":"one-view anatomical rig reference; not a completed 2D mesh skinned rig",
 "limitations":["Dominant-weight face segmentation may produce seam gaps.","Part images do not expose hidden geometry; additional reference poses may be needed."]
}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2))
print("RIG_REFERENCE_SUCCESS",len(selected),"selected frames",len(parts),"parts")
