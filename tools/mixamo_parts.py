import bpy,bmesh,json,pathlib,hashlib,math
from mathutils import Vector
P=pathlib.Path('rendered/mixamo_parts');P.mkdir(parents=True,exist_ok=True)
src=pathlib.Path('input/Walking.fbx')
assert src.stat().st_size==1839568
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src.resolve()))
scene=bpy.context.scene
meshes=[o for o in bpy.data.objects if o.type=='MESH']
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
action=rig.animation_data.action
assert action and len(rig.data.bones)>=60
for track in rig.animation_data.nla_tracks:track.mute=True
start,end=map(lambda x:int(round(x)),action.frame_range)
assert end-start+1==32
regions=['Head','Spine','LeftArm','RightArm','LeftUpLeg','RightUpLeg','LeftLeg','RightLeg','LeftFoot','RightFoot']
def region(name):
 n=name.lower()
 if 'head' in n or 'neck' in n:return 'Head'
 if 'left' in n and ('arm' in n or 'hand' in n or 'shoulder' in n):return 'LeftArm'
 if 'right' in n and ('arm' in n or 'hand' in n or 'shoulder' in n):return 'RightArm'
 for side in ('Left','Right'):
  for part in ('UpLeg','Leg','Foot'):
   if (side+part).lower() in n:return side+part
 return 'Spine'
def scores(mesh,poly):
 out={}
 for vi in poly.vertices:
  for g in mesh.data.vertices[vi].groups:
   if g.group>=len(mesh.vertex_groups):continue
   key=region(mesh.vertex_groups[g.group].name)
   out[key]=out.get(key,0)+g.weight
 return out
scene.frame_set(start)
bb=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in bb) for i in range(3)])
hi=Vector([max(v[i] for v in bb) for i in range(3)])
center=(lo+hi)/2;diam=max((hi-lo).length,1.)
cd=bpy.data.cameras.new('ISO45');cam=bpy.data.objects.new('ISO45',cd)
scene.collection.objects.link(cam);scene.camera=cam;cd.type='ORTHO';cd.ortho_scale=diam*1.45
cam.location=center+Vector((1,-1,1)).normalized()*diam*2.5
cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
ld=bpy.data.lights.new('Soft','AREA');light=bpy.data.objects.new('Soft',ld);scene.collection.objects.link(light)
light.location=center+Vector((diam,-diam,diam*2));light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
ld.energy=1000;ld.size=diam
world=bpy.data.worlds.new('WorldAudit');world.use_nodes=True;scene.world=world
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2) else 'BLENDER_EEVEE'
scene.render.resolution_x=384;scene.render.resolution_y=576;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.eevee.taa_render_samples=16
def project(p):
 from bpy_extras.object_utils import world_to_camera_view
 q=world_to_camera_view(scene,cam,p)
 return [float(q.x*384),float((1-q.y)*576)]
frames=[]
footpaths={'Left':[],'Right':[]}
for i,f in enumerate(range(start,end+1)):
 scene.frame_set(f)
 joints={}
 for side in ('Left','Right'):
  bone=next((b for b in rig.pose.bones if b.name.lower().endswith((side+'Foot').lower())),None)
  assert bone,'Foot bone missing '+side
  pos=rig.matrix_world@bone.head
  footpaths[side].append(list(pos))
  joints[side]=project(pos)
 scene.render.filepath=str((P/('full_%02d.png'%i)).resolve())
 bpy.ops.render.render(write_still=True)
 frames.append({'frame':f,'foot_projection':joints})
scene.frame_set(start)
counts={}
for reg in regions:
 copies=[]
 for original in meshes:
  keep_faces=[p.index for p in original.data.polygons if (max(scores(original,p),key=scores(original,p).get) if scores(original,p) else 'Spine')==reg]
  if not keep_faces:continue
  obj=original.copy();obj.data=original.data.copy();scene.collection.objects.link(obj)
  bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
  bmesh.ops.delete(bm,geom=[face for face in bm.faces if face.index not in set(keep_faces)],context='FACES')
  bm.to_mesh(obj.data);bm.free()
  copies.append(obj);counts[reg]=counts.get(reg,0)+len(keep_faces)
 for o in meshes:o.hide_render=True
 for o in copies:o.hide_render=False
 if copies:
  scene.render.filepath=str((P/('part_'+reg+'.png')).resolve())
  bpy.ops.render.render(write_still=True)
 for obj in copies:bpy.data.objects.remove(obj,do_unlink=True)
 for o in meshes:o.hide_render=False
report={'schema':1,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
 'mesh_count':len(meshes),'bone_count':len(rig.data.bones),'action':action.name,'fps':scene.render.fps,
 'frames':frames,'regions':counts,
 'foot_path_range_world':{k:round(max(Vector(v).z for v in path)-min(Vector(v).z for v in path),6) for k,path in footpaths.items()},
 'foot_max_step_world':{k:round(max((Vector(path[i])-Vector(path[i-1])).length for i in range(1,len(path))),6) for k,path in footpaths.items()},
 'limitations':['Dominant-weight faces split across boundaries; isolated PNG seams are not gap-free.',
 'Foot motion is reported, but stance intervals and ground-contact slip cannot be inferred from foot-head paths alone.',
 'Each full-frame render is original skinned mesh; PNG part images are neutral-frame references only.']}
(P/'manifest.json').write_text(json.dumps(report,indent=2))
print('MIXAMO_PARTS_SUCCESS',len(frames),counts)
