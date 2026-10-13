import bpy,json,pathlib,hashlib,math
from mathutils import Vector
P=pathlib.Path("rendered/mixamo_walking");P.mkdir(parents=True,exist_ok=True)
src=pathlib.Path("input/Walking.fbx")
assert src.stat().st_size==1839568
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src.resolve()))
scene=bpy.context.scene
meshes=[o for o in bpy.data.objects if o.type=="MESH"]
rigs=[o for o in bpy.data.objects if o.type=="ARMATURE"]
actions=list(bpy.data.actions)
assert meshes and rigs and actions,(len(meshes),len(rigs),len(actions))
r=rigs[0]
if not r.animation_data:r.animation_data_create()
act=r.animation_data.action or max(actions,key=lambda a:a.frame_range[1]-a.frame_range[0])
r.animation_data.action=act
for track in r.animation_data.nla_tracks:track.mute=True
start,end=map(lambda v:int(round(v)),act.frame_range)
assert end>start
scene.frame_set(start)
def vec(v):return [round(float(x),6) for x in v]
report={"source_sha256":hashlib.sha256(src.read_bytes()).hexdigest(),"blender":bpy.app.version_string,
"fps":scene.render.fps,"fps_base":scene.render.fps_base,
"timeline":[scene.frame_start,scene.frame_end],"action_frame_range":[start,end],
"mesh_count":len(meshes),"armature_count":len(rigs),
"meshes":[{"name":o.name,"vertices":len(o.data.vertices),"faces":len(o.data.polygons),"uv_layers":len(o.data.uv_layers),
"vertex_groups":len(o.vertex_groups),"weighted_vertices":sum(1 for v in o.data.vertices if v.groups),
"armature_modifiers":[m.object.name for m in o.modifiers if m.type=="ARMATURE" and m.object]} for o in meshes],
"rigs":[{"name":o.name,"bones":[{"name":b.name,"parent":b.parent.name if b.parent else None,"deform":b.use_deform,
"head":vec(b.head_local),"tail":vec(b.tail_local)} for b in o.data.bones]} for o in rigs],
"actions":[{"name":a.name,"frame_range":vec(a.frame_range)} for a in actions],
"selected_action":act.name,"sampled_frames":[]}
joint_names=[b.name for b in r.pose.bones if any(x in b.name.lower() for x in ("hip","leg","foot","toe"))]
indices=sorted(set(int(round(start+(end-start)*k/8)) for k in range(9)))
for f in indices:
 scene.frame_set(f)
 report["sampled_frames"].append({"frame":f,"joints":{n:vec(r.matrix_world@r.pose.bones[n].head) for n in joint_names}})
scene.frame_set(start)
scene.render.engine="BLENDER_EEVEE_NEXT" if bpy.app.version>=(4,2) else "BLENDER_EEVEE"
scene.render.resolution_x=512;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG";scene.render.film_transparent=True
bb=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
low=Vector([min(v[i] for v in bb) for i in range(3)])
high=Vector([max(v[i] for v in bb) for i in range(3)])
center=(low+high)/2;diam=max((high-low).length,1)
camdata=bpy.data.cameras.new("Iso45");cam=bpy.data.objects.new("Iso45",camdata)
scene.collection.objects.link(cam);scene.camera=cam;camdata.type="ORTHO";camdata.ortho_scale=diam*1.45
cam.location=center+Vector((1,-1,1)).normalized()*diam*2.5
cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
ld=bpy.data.lights.new("Softbox","AREA");light=bpy.data.objects.new("Softbox",ld);scene.collection.objects.link(light)
light.location=center+Vector((diam,-diam,diam*2))
light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
ld.energy=1000;ld.size=diam
world=bpy.data.worlds.new("ReferenceWorld");world.use_nodes=True;scene.world=world
for i,f in enumerate(indices):
 scene.frame_set(f)
 scene.render.filepath=str((P/("walking_%02d.png"%i)).resolve())
 bpy.ops.render.render(write_still=True)
(P/"audit.json").write_text(json.dumps(report,indent=2))
print("MIXAMO_WALK_AUDIT_SUCCESS",len(meshes),len(rigs),len(actions),start,end,scene.render.fps)
