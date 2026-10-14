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
ld=bpy.data.lights.new('Soft','AREA');light=bpy.data.objects.new('Soft',ld);scene.collection.objects.link(light)
ld.energy=1100;ld.size=diam
world=bpy.data.worlds.new('World');world.use_nodes=True;scene.world=world
# Four camera azimuths 90 degrees apart; each elevated 45 degrees.
directions={'NE':(1,1),'NW':(-1,1),'SW':(-1,-1),'SE':(1,-1)}
indices=list(range(start,start+32,4))
for label,(x,y) in directions.items():
 folder=P/label;folder.mkdir(exist_ok=True)
 cam.location=center+Vector((x,y,math.sqrt(2))).normalized()*diam*2.7
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 light.location=center+Vector((diam,-diam,diam*2))
 light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 for i,frame in enumerate(indices):
  scene.frame_set(frame)
  scene.render.filepath=str((folder/('frame_%02d.png'%i)).resolve())
  bpy.ops.render.render(write_still=True)
(P/'render_manifest.json').write_text(json.dumps({'directions':list(directions),'source_frames':indices,'camera_elevation_deg':45,'camera_azimuth_vectors':directions,'frame_count_per_direction':8},indent=2))
print('ISO4_RENDER_SUCCESS',len(directions),len(indices))
