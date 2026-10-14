import bpy, math, pathlib, json, hashlib
from mathutils import Vector, Matrix
P=pathlib.Path('rendered/mixamo_neutral4');P.mkdir(parents=True,exist_ok=True)
src=pathlib.Path('input/Walking.fbx');assert src.stat().st_size>1000000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src.resolve()))
scene=bpy.context.scene
meshes=[o for o in bpy.data.objects if o.type=='MESH']
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
assert len(meshes)>=1 and len(rig.data.bones)>=60
# Explicit rest pose, NOT any Walking action frame.
rig.data.pose_position='POSE'
if rig.animation_data:
 rig.animation_data.action=None
 for track in rig.animation_data.nla_tracks:track.mute=True
scene.frame_set(0)
for pb in rig.pose.bones:
 pb.rotation_mode='QUATERNION'
 pb.rotation_quaternion=(1,0,0,0)
 pb.location=(0,0,0)
 pb.scale=(1,1,1)
bpy.context.view_layer.update()
# Lower both arms from source rest T-pose without using any walking frame.
# Rotate each upper arm around its own anatomical shoulder pivot.
pose_report={}
for side in ('Left','Right'):
 bone_name=next((n for n in rig.pose.bones.keys() if n.endswith(side+'Arm') and 'Fore' not in n),None)
 assert bone_name,'Upper arm bone not found: '+side
 pb=rig.pose.bones[bone_name]
 before=(pb.tail-pb.head).normalized()
 # Natural standing: mostly down, slightly outwards from the body.
 outward=1.0 if side=='Left' else -1.0
 target_world=Vector((0.12*outward,0.0,-1.0)).normalized()
 target=(rig.matrix_world.inverted().to_3x3()@target_world).normalized()
 rot=before.rotation_difference(target)
 pivot=pb.head.copy()
 pb.matrix=Matrix.Translation(pivot)@rot.to_matrix().to_4x4()@Matrix.Translation(-pivot)@pb.matrix
 bpy.context.view_layer.update()
 after=(pb.tail-pb.head).normalized()
 assert after.dot(target)>0.96,(bone_name,list(after),list(target))
 pose_report[side]={'bone':bone_name,'before':list(before),'after':list(after),'target':list(target)}
# Standing pose is a manually derived rest-pose correction, not a sourced Idle action.

bb=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in bb) for i in range(3)])
hi=Vector([max(v[i] for v in bb) for i in range(3)])
center=(lo+hi)*0.5;diam=max((hi-lo).length,1.)
cd=bpy.data.cameras.new('ISO45_Neutral');cam=bpy.data.objects.new('ISO45_Neutral',cd)
scene.collection.objects.link(cam);scene.camera=cam
cd.type='ORTHO';cd.ortho_scale=diam*1.16
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2) else 'BLENDER_EEVEE'
scene.render.resolution_x=1024;scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast' if False else 'Medium High Contrast'
# Lit, color-coded anatomy reference. Keep image alpha and camera geometry unchanged.
scene.view_settings.look='Medium High Contrast'
scene.render.film_transparent=True
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2) else 'BLENDER_EEVEE'
palette={
 'head':(0.93,0.71,0.47,1),'neck':(0.92,0.67,0.41,1),
 'torso':(0.17,0.56,0.76,1),'spine':(0.17,0.56,0.76,1),'chest':(0.17,0.56,0.76,1),
 'hips':(0.55,0.38,0.76,1),'pelvis':(0.55,0.38,0.76,1),
 'leftarm':(0.92,0.38,0.31,1),'rightarm':(0.94,0.65,0.22,1),
 'leftforearm':(0.94,0.57,0.43,1),'rightforearm':(0.98,0.77,0.39,1),
 'lefthand':(0.96,0.78,0.59,1),'righthand':(0.96,0.78,0.59,1),
 'leftupleg':(0.24,0.68,0.45,1),'rightupleg':(0.27,0.54,0.86,1),
 'leftleg':(0.43,0.79,0.57,1),'rightleg':(0.49,0.68,0.93,1),
 'leftfoot':(0.20,0.39,0.29,1),'rightfoot':(0.23,0.34,0.57,1)}
# Mixamo FBX commonly contains one skinned mesh. Split faces by strongest
# vertex-group influence into material regions; retain armature deformation.
region_order=['leftforearm','rightforearm','lefthand','righthand','leftarm','rightarm',
 'leftupleg','rightupleg','leftleg','rightleg','leftfoot','rightfoot',
 'head','neck','hips','pelvis','chest','spine','torso']
def region(name):
 n=name.lower().split(':')[-1].replace('_','')
 if 'lefttoe' in n:return 'leftfoot'
 if 'righttoe' in n:return 'rightfoot'
 for key in region_order:
  if key in n:return key
 return 'torso'
mats={}
for key,color in palette.items():
 m=bpy.data.materials.new('ANATOMY_'+key);m.diffuse_color=color;m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF')
 bs.inputs['Base Color'].default_value=color
 bs.inputs['Roughness'].default_value=0.83
 mats[key]=m
for ob in meshes:
 ob.data.materials.clear()
 for key in palette:ob.data.materials.append(mats[key])
 groups={g.index:region(g.name) for g in ob.vertex_groups}
 counts={key:0 for key in palette}
 for poly in ob.data.polygons:
  weights={}
  for vi in poly.vertices:
   for g in ob.data.vertices[vi].groups:
    k=groups.get(g.group,'torso')
    weights[k]=weights.get(k,0)+g.weight
  key=max(weights,key=weights.get) if weights else 'torso'
  poly.material_index=list(palette).index(key)
  counts[key]+=1
 print('ANATOMY_MATERIAL_FACES',ob.name,counts)
# Large area lights create readable surface gradients, not harsh black shadows.
world=bpy.data.worlds.new('NeutralStudioWorld');world.use_nodes=True;scene.world=world
bg=world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value=(0.72,0.79,0.88,1)
bg.inputs['Strength'].default_value=0.65
def area(name,location,power,size):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
 obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj)
 obj.location=center+Vector(location)*diam
 obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
area('Softbox_Key',(-1.5,-2,2.8),850,diam*2.4)
area('Softbox_Fill',(1.8,0.7,1.5),420,diam*2.8)
area('Softbox_Rim',(0.8,2.0,2.4),650,diam*2.0)
directions={'NE':(1,1),'NW':(-1,1),'SW':(-1,-1),'SE':(1,-1)}
for label,(x,y) in directions.items():
 cam.location=center+Vector((x,y,math.sqrt(2))).normalized()*diam*2.8
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str((P/(label+'_rest.png')).resolve())
 bpy.ops.render.render(write_still=True)
manifest={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
'pose':'DERIVED_NATURAL_STANDING_FROM_REST','walking_action_used':False,'arm_adjustments':pose_report,
'camera':'orthographic','elevation_deg':45,'direction_vectors':directions,
'lighting':'principled_bsdf_three_area_studio','anatomy_palette':palette,'frame_size':[1024,1024],
'warning':'Procedurally lowered upper arms from rest pose; visual inspection required before AI design.'}
(P/'render_manifest.json').write_text(json.dumps(manifest,indent=2))
print('NEUTRAL4_RENDER_SUCCESS',list(directions))
