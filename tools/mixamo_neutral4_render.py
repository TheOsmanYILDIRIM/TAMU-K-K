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
 target=Vector((0.12*outward,0.0,-1.0)).normalized()
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
# Deterministic shadow-free material color; no cast lighting.
for material in bpy.data.materials:
 material.use_nodes=True
 nodes=material.node_tree.nodes;links=material.node_tree.links
 principal=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
 base=principal.inputs.get('Base Color') if principal else None
 original=base.links[0].from_socket if base and base.is_linked else None
 color=tuple(base.default_value) if base else tuple(material.diffuse_color)
 emission=nodes.new('ShaderNodeEmission')
 emission.inputs['Color'].default_value=color
 emission.inputs['Strength'].default_value=1.0
 if original:links.new(original,emission.inputs['Color'])
 output=next((n for n in nodes if n.type=='OUTPUT_MATERIAL'),None)
 if not output:output=nodes.new('ShaderNodeOutputMaterial')
 for link in list(output.inputs['Surface'].links):links.remove(link)
 links.new(emission.outputs[0],output.inputs['Surface'])
world=bpy.data.worlds.new('NeutralWorld');world.use_nodes=True;scene.world=world
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
directions={'NE':(1,1),'NW':(-1,1),'SW':(-1,-1),'SE':(1,-1)}
for label,(x,y) in directions.items():
 cam.location=center+Vector((x,y,math.sqrt(2))).normalized()*diam*2.8
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str((P/(label+'_rest.png')).resolve())
 bpy.ops.render.render(write_still=True)
manifest={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
'pose':'DERIVED_NATURAL_STANDING_FROM_REST','walking_action_used':False,'arm_adjustments':pose_report,
'camera':'orthographic','elevation_deg':45,'direction_vectors':directions,
'lighting':'emission_albedo_no_directional_shadows','frame_size':[1024,1024],
'warning':'Procedurally lowered upper arms from rest pose; visual inspection required before AI design.'}
(P/'render_manifest.json').write_text(json.dumps(manifest,indent=2))
print('NEUTRAL4_RENDER_SUCCESS',list(directions))
