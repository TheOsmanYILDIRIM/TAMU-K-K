import bpy,math,pathlib,json
from mathutils import Vector
P=pathlib.Path('rendered/mixamo_iso4');P.mkdir(parents=True,exist_ok=True)
src=pathlib.Path('input/Walking.fbx');assert src.stat().st_size>1000000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src.resolve()))
scene=bpy.context.scene
meshes=[o for o in bpy.data.objects if o.type=='MESH']
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
act=rig.animation_data.action;assert act and len(rig.data.bones)>=60
start,end=map(lambda x:int(round(x)),act.frame_range);assert end-start+1==32
scene.frame_set(start)
bb=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in bb) for i in range(3)]);hi=Vector([max(v[i] for v in bb) for i in range(3)])
center=(lo+hi)/2;diam=max((hi-lo).length,1)
camdata=bpy.data.cameras.new('ISO45');cam=bpy.data.objects.new('ISO45',camdata)
scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=diam*1.40
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2) else 'BLENDER_EEVEE'
scene.render.resolution_x=384;scene.render.resolution_y=576;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
# Shadow-free, view-invariant albedo output for AI asset reference.
# Preserve imported material base colors/texture links where present.
for material in bpy.data.materials:
 material.use_nodes=True
 nodes=material.node_tree.nodes;links=material.node_tree.links
 principled=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
 base=principled.inputs.get('Base Color') if principled else None
 original_link=base.links[0] if base and base.is_linked else None
 color=tuple(base.default_value) if base else tuple(material.diffuse_color)
 emission=nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=color
 emission.inputs['Strength'].default_value=1.0
 if original_link:links.new(original_link.from_socket,emission.inputs['Color'])
 output=next((n for n in nodes if n.type=='OUTPUT_MATERIAL'),None)
 if not output:output=nodes.new('ShaderNodeOutputMaterial')
 for link in list(output.inputs['Surface'].links):links.remove(link)
 links.new(emission.outputs[0],output.inputs['Surface'])
world=bpy.data.worlds.new('NeutralWorld');world.use_nodes=True;scene.world=world
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0.0
# Four camera azimuths 90 degrees apart; each elevated 45 degrees.
directions={'NE':(1,1),'NW':(-1,1),'SW':(-1,-1),'SE':(1,-1)}
indices=list(range(start,start+32,4))
for label,(x,y) in directions.items():
 folder=P/label;folder.mkdir(exist_ok=True)
 cam.location=center+Vector((x,y,math.sqrt(2))).normalized()*diam*2.7
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for i,frame in enumerate(indices):
  scene.frame_set(frame)
  scene.render.filepath=str((folder/('frame_%02d.png'%i)).resolve())
  bpy.ops.render.render(write_still=True)
(P/'render_manifest.json').write_text(json.dumps({'directions':list(directions),'source_frames':indices,'camera_elevation_deg':45,'camera_azimuth_vectors':directions,'frame_count_per_direction':8,'lighting':'unlit_emission_albedo_no_cast_shadows'},indent=2))
print('ISO4_RENDER_SUCCESS',len(directions),len(indices))
