import bpy,json,pathlib,math
from mathutils import Vector
OUT=pathlib.Path('rendered/mixamo_skin2d');OUT.mkdir(parents=True,exist_ok=True)
src=pathlib.Path('input/Walking.fbx');assert src.stat().st_size>1000000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src.resolve()))
scene=bpy.context.scene
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.data.objects if o.type=='MESH']
act=rig.animation_data.action
start,end=map(lambda v:int(round(v)),act.frame_range)
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
scene.view_layers[0].update()
assert abs(cam.matrix_world.translation.length)>0.01, 'camera matrix was not evaluated'
def mat(m):return [list(map(float,row)) for row in m]
bind={b.name:(rig.matrix_world@b.matrix_local).inverted() for b in rig.data.bones}
data={'schema':2,'size':[384,576],'ortho_scale':float(cd.ortho_scale),'camera_inverse':mat(cam.matrix_world.inverted()),'bind_inverse':{n:mat(m) for n,m in bind.items()},'meshes':{},'frames':[]}
for o in meshes:
 o.data.calc_loop_triangles()
 uv=o.data.uv_layers.active
 tris=[]
 for t in o.data.loop_triangles:
  material=o.material_slots[o.data.polygons[t.polygon_index].material_index].material if o.material_slots else None
  color=list(material.diffuse_color) if material else [0.8,0.55,0.5,1]
  tris.append({'v':list(t.vertices),'uv':[[float(uv.data[li].uv.x),float(uv.data[li].uv.y)] for li in t.loops] if uv else None,'color':color})
 data['meshes'][o.name]={'vertices':[list(map(float,o.matrix_world@v.co)) for v in o.data.vertices],
 'weights':[[[o.vertex_groups[g.group].name,float(g.weight)] for g in v.groups] for v in o.data.vertices],
 'triangles':tris}
for f in range(start,end+1):
 scene.frame_set(f)
 data['frames'].append({'frame':f,'bones':{b.name:mat(rig.matrix_world@b.matrix) for b in rig.pose.bones}})
(OUT/'skin2d.json').write_text(json.dumps(data,separators=(',',':')))
print('SKIN2D_EXPORT_SUCCESS',len(data['frames']),[(k,len(v['vertices'])) for k,v in data['meshes'].items()])
