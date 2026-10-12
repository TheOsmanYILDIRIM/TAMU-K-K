"""Generate BJD single-body diagnostic and Adventurer 33-frame joint targets.
Not a completed skin/retarget: no BJD armature exists in the downloaded FBX.
"""
import bpy, pathlib, json, zipfile, math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
out=pathlib.Path("rendered/chambersu_rig2d");out.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile("input/chambersu.zip") as z:
    src=[x for x in z.namelist() if x.lower().endswith(".fbx")]
    assert len(src)==1
    assert not pathlib.PurePosixPath(src[0]).is_absolute()
    assert ".." not in pathlib.PurePosixPath(src[0]).parts
    z.extract(src[0],"input/unpacked")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str((pathlib.Path("input/unpacked")/src[0]).resolve()))
meshes=[o for o in bpy.data.objects if o.type=="MESH"]
assert len(meshes)>=30
# Choose body with chest at middle X. Group objects by X-nearest chest center,
# while retaining only those inside an empirically bounded body radius.
chests=sorted([o for o in meshes if o.name.startswith("chestMesh")],key=lambda o:(o.matrix_world.translation.x,o.name))
assert len(chests)==3
centers=[(o.matrix_world @ (sum((Vector(c) for c in o.bound_box),Vector())/8)) for o in chests]
mid=centers[1]
chest_gap=min((centers[1]-centers[0]).length,(centers[2]-centers[1]).length)
assert chest_gap>0.05
# nearest chest in XZ/Y 3D and radius can distinguish 3 independent mannequins.
def center(o):return o.matrix_world @ (sum((Vector(c) for c in o.bound_box),Vector())/8)
keep=[o for o in meshes if min(range(3),key=lambda k:(center(o)-centers[k]).length)==1]
assert len(keep)>=12, len(keep)
for o in meshes:o.hide_render=o not in keep
# geometry-derived pivots, named by actual rigid mesh bounds
def bbox(o):
    corners=[o.matrix_world @ Vector(c) for c in o.bound_box]
    return [[float(min(p[k] for p in corners)) for k in range(3)],
            [float(max(p[k] for p in corners)) for k in range(3)]]
part=[{"name":o.name,"center":list(center(o)),"bounds":bbox(o),"vertex_count":len(o.data.vertices)} for o in keep]
# Source animation: import rig for positions and 33 frames; hide it during BJD render.
bpy.ops.import_scene.gltf(filepath=str(pathlib.Path("assets/walk_source/adventurer.glb").resolve()))
rig=next(o for o in bpy.data.objects if o.type=="ARMATURE")
acts=[a for a in bpy.data.actions if "walk" in a.name.lower()]
assert acts,"Adventurer Walk action absent"
action=sorted(acts,key=lambda a:a.name)[0]
rig.animation_data_create();rig.animation_data.action=action
for track in rig.animation_data.nla_tracks:track.mute=True
frame_start=int(round(action.frame_range[0]));frame_end=int(round(action.frame_range[1]))
frames=list(range(frame_start,min(frame_end+1,frame_start+33)))
assert len(frames)==33,len(frames)
names=["Hips","UpperLeg.L","LowerLeg.L","Foot.L","UpperLeg.R","LowerLeg.R","Foot.R"]
assert all(n in rig.pose.bones for n in names)
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE_NEXT" if bpy.app.version>=(4,2) else "BLENDER_EEVEE"
scene.render.resolution_x=512;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG";scene.render.film_transparent=True
loc=[p for o in keep for p in (o.matrix_world @ Vector(c) for c in o.bound_box)]
lo=Vector([min(p[i] for p in loc) for i in range(3)])
hi=Vector([max(p[i] for p in loc) for i in range(3)])
co=(lo+hi)/2;diam=max((hi-lo).length,1)
cd=bpy.data.cameras.new("Rig2DReference");cam=bpy.data.objects.new("Rig2DReference",cd)
scene.collection.objects.link(cam);scene.camera=cam;cd.type="ORTHO";cd.ortho_scale=diam*1.45
cam.location=co+Vector((1,-1,1)).normalized()*diam*2.5
cam.rotation_euler=(co-cam.location).to_track_quat("-Z","Y").to_euler()
ld=bpy.data.lights.new("Rig2DArea","AREA");light=bpy.data.objects.new("Rig2DArea",ld);scene.collection.objects.link(light)
light.location=co+Vector((diam,-diam,diam*2));light.rotation_euler=(co-light.location).to_track_quat("-Z","Y").to_euler()
ld.energy=1100;ld.size=max(diam,1)
world=bpy.data.worlds.new("Rig2DWorld");world.use_nodes=True;scene.world=world
samples=[]
for f in frames:
    scene.frame_set(f)
    joints={}
    for n in names:
        bone=rig.pose.bones[n]
        pos=rig.matrix_world @ bone.head
        joints[n]=[round(float(v),5) for v in pos]
    samples.append({"frame":f,"joints_3d":joints})
for o in bpy.data.objects:
    if o.type=="MESH" and o not in keep:o.hide_render=True
scene.frame_set(frame_start)
scene.render.filepath=str((out/"isolated_body.png").resolve())
bpy.ops.render.render(write_still=True)
result={"schema_version":1,"selected_variant":"middle_chest_by_world_x","variant_chest_centers":[list(c) for c in centers],
        "selection_algorithm":"nearest 3D chest center; MUST visually validate part ownership",
        "selected_mesh_count":len(keep),"parts":part,"source_action":action.name,
        "motion_frames":samples,"retarget_status":"joint_targets_only_not_rigged",
        "limitations":["No BJD skeleton; no actual pose deformation","3D joint targets not retargeted to BJD pivots",
        "Foot contact, slip, body-seam and occlusion still unverified"]}
(out/"rig2d_manifest.json").write_text(json.dumps(result,indent=2))
print("RIG2D_REFERENCE_SUCCESS",len(keep),len(samples),action.name)
