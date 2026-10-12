import bpy, zipfile, pathlib, json, hashlib, math
from mathutils import Vector
ROOT=pathlib.Path("rendered/chambersu_audit")
ROOT.mkdir(parents=True,exist_ok=True)
ZIP=pathlib.Path("input/chambersu.zip")
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
assert ZIP.is_file()
with zipfile.ZipFile(ZIP) as z:
    entries=z.infolist()
    assert len(entries)<3000
    for item in entries:
        p=pathlib.PurePosixPath(item.filename)
        assert not p.is_absolute() and ".." not in p.parts and item.file_size<300_000_000
    choices=[x.filename for x in entries if x.filename.lower().endswith((".blend",".glb",".gltf",".fbx"))]
    assert choices, "ZIP contains no supported 3D scene"
    z.extractall("input/unpacked")
priority={".blend":0,".glb":1,".gltf":2,".fbx":3}
chosen=sorted(choices,key=lambda n:(priority[pathlib.Path(n).suffix.lower()],len(n)))[0]
source=pathlib.Path("input/unpacked")/chosen
bpy.ops.wm.read_factory_settings(use_empty=True)
ext=source.suffix.lower()
if ext==".blend":
    bpy.ops.wm.open_mainfile(filepath=str(source.resolve()),load_ui=False)
elif ext in (".glb",".gltf"):
    bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
else:
    bpy.ops.import_scene.fbx(filepath=str(source.resolve()))
meshes=[o for o in bpy.data.objects if o.type=="MESH"]
rigs=[o for o in bpy.data.objects if o.type=="ARMATURE"]
assert meshes, "No meshes found"
def mesh_info(o):
    return {"name":o.name,"vertices":len(o.data.vertices),"faces":len(o.data.polygons),
            "uv_layers":len(o.data.uv_layers),
            "weighted_vertices":sum(bool(v.groups) for v in o.data.vertices),
            "groups":[g.name for g in o.vertex_groups],
            "armature_modifiers":[m.object.name for m in o.modifiers if m.type=="ARMATURE" and m.object],
            "parent":o.parent.name if o.parent else None}
def rig_info(o):
    return {"name":o.name,"bones":[{"name":b.name,"parent":b.parent.name if b.parent else None,
        "head":list(b.head_local),"tail":list(b.tail_local),"deform":b.use_deform} for b in o.data.bones]}
report={"source_zip_sha256":sha(ZIP),"chosen_source":chosen,"source_sha256":sha(source),
        "archive_files":[{"name":x.filename,"size":x.file_size} for x in entries],
        "mesh_count":len(meshes),"armature_count":len(rigs),
        "meshes":[mesh_info(o) for o in meshes],"armatures":[rig_info(o) for o in rigs],
        "actions":[{"name":a.name,"frame_range":list(a.frame_range)} for a in bpy.data.actions],
        "retarget_status":"not_executed_requires_bone_mapping"}
bones=[b.name for rig in rigs for b in rig.data.bones]
for label,tokens in {"hips":["hip","pelvis"],"upperleg":["thigh","upperleg"],"lowerleg":["shin","calf","lowerleg"],"feet":["foot","ankle"],"toe":["toe"]}.items():
    report.setdefault("bone_matches",{})[label]=[n for n in bones if any(t in n.lower() for t in tokens)]
# Read Adventurer independently as a separate source to compare name coverage, without replacing BJD scene.
adv=pathlib.Path("assets/walk_source/adventurer.glb")
if adv.exists():
    report["adventurer_sha256"]=sha(adv)
    bpy.ops.import_scene.gltf(filepath=str(adv.resolve()))
    advrigs=[o for o in bpy.data.objects if o.type=="ARMATURE" and o not in rigs]
    report["adventurer_armatures"]=[rig_info(o) for o in advrigs]
    report["adventurer_actions"]=[a.name for a in bpy.data.actions]
    for o in list(bpy.data.objects):
        if o.type=="MESH" and o not in meshes: bpy.data.objects.remove(o,do_unlink=True)
    for o in advrigs: bpy.data.objects.remove(o,do_unlink=True)
(ROOT/"audit.json").write_text(json.dumps(report,indent=2))
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE_NEXT" if bpy.app.version>=(4,2) else "BLENDER_EEVEE"
scene.render.resolution_x=512
scene.render.resolution_y=768
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.film_transparent=True
for obj in meshes: obj.hide_render=False
vertices=[o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in vertices) for i in range(3)])
hi=Vector([max(v[i] for v in vertices) for i in range(3)])
center=(lo+hi)/2
diam=max((hi-lo).length,1)
camera_data=bpy.data.cameras.new("AuditCamera")
camera=bpy.data.objects.new("AuditCamera",camera_data)
scene.collection.objects.link(camera)
scene.camera=camera
camera_data.type="ORTHO"
camera_data.ortho_scale=diam*1.4
camera.location=center+Vector((1,-1,1)).normalized()*diam*2.6
camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
world=bpy.data.worlds.new("AuditWorld")
world.use_nodes=True
scene.world=world
ld=bpy.data.lights.new("AuditArea","AREA")
light=bpy.data.objects.new("AuditArea",ld)
scene.collection.objects.link(light)
light.location=center+Vector((diam,-diam,diam*2))
light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
ld.energy=1000
ld.size=max(diam,1)
scene.render.filepath=str((ROOT/"neutral.png").resolve())
bpy.ops.render.render(write_still=True)
print("CHAMBERSU_AUDIT_SUCCESS",len(meshes),len(rigs),chosen)
