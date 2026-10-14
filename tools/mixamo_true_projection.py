import bpy,json,pathlib,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=pathlib.Path('rendered/mixamo_true_projection');OUT.mkdir(parents=True,exist_ok=True)
src=pathlib.Path('input/Walking.fbx');assert src.stat().st_size>1000000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src.resolve()))
scene=bpy.context.scene
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.data.objects if o.type=='MESH']
assert len(meshes)==2 and len(rig.data.bones)>=60
act=rig.animation_data.action
start,end=map(lambda x:int(round(x)),act.frame_range)
assert end-start+1==32
scene.frame_set(start)
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in corners) for i in range(3)])
hi=Vector([max(v[i] for v in corners) for i in range(3)])
center=(lo+hi)*0.5;diam=max((hi-lo).length,1.)
cd=bpy.data.cameras.new('Iso45');cam=bpy.data.objects.new('Iso45',cd)
scene.collection.objects.link(cam);scene.camera=cam;cd.type='ORTHO';cd.ortho_scale=diam*1.45
cam.location=center+Vector((1,-1,1)).normalized()*diam*2.5
cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
W,H=384,576
scene.render.resolution_x=W;scene.render.resolution_y=H;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2) else 'BLENDER_EEVEE'
ld=bpy.data.lights.new('Soft','AREA');light=bpy.data.objects.new('Soft',ld)
scene.collection.objects.link(light);light.location=center+Vector((diam,-diam,diam*2))
light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
ld.energy=1000;ld.size=diam
world=bpy.data.worlds.new('World');world.use_nodes=True;scene.world=world
def proj(p):
 q=world_to_camera_view(scene,cam,p)
 cp=cam.matrix_world.inverted()@p
 return [round(float(q.x*W),5),round(float((1-q.y)*H),5),round(float(-cp.z),5)]
result={'schema':1,'fps':scene.render.fps,'size':[W,H],'camera_matrix':[list(map(float,row)) for row in cam.matrix_world],'topology':{},'frames':[]}
for o in meshes:
 o.data.calc_loop_triangles()
 uv=o.data.uv_layers.active
 result['topology'][o.name]={'triangles':[{'v':list(t.vertices),'uv':[[float(uv.data[li].uv.x),float(uv.data[li].uv.y)] for li in t.loops] if uv else None} for t in o.data.loop_triangles],
 'weights':[[[o.vertex_groups[g.group].name,round(float(g.weight),5)] for g in v.groups] for v in o.data.vertices]}
for i,f in enumerate(range(start,end+1)):
 scene.frame_set(f);dg=bpy.context.evaluated_depsgraph_get()
 item={'frame':f,'bones':{},'meshes':{}}
 for b in rig.pose.bones:
  mat=rig.matrix_world@b.matrix
  item['bones'][b.name]={'matrix':[list(map(float,row)) for row in mat],'head':proj(rig.matrix_world@b.head),'tail':proj(rig.matrix_world@b.tail)}
 for o in meshes:
  eo=o.evaluated_get(dg);em=eo.to_mesh()
  try:item['meshes'][o.name]=[proj(eo.matrix_world@v.co) for v in em.vertices]
  finally:eo.to_mesh_clear()
 scene.render.filepath=str((OUT/('reference_%02d.png'%i)).resolve())
 bpy.ops.render.render(write_still=True)
 result['frames'].append(item)
(OUT/'projection.json').write_text(json.dumps(result,separators=(',',':')))
print('TRUE_PROJECTION_SUCCESS',len(result['frames']),len(result['topology']))
