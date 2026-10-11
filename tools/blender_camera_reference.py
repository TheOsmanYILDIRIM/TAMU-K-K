import bpy, math, os, json
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
source='assets/reference/makehuman_base.obj'
assert os.path.isfile(source), 'Licensed reference model missing'
bpy.ops.wm.obj_import(filepath=os.path.abspath(source), forward_axis='NEGATIVE_Z', up_axis='Y')
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  mat=bpy.data.materials.new('Neutral anatomy reference')
  mat.diffuse_color=(0.65,0.63,0.60,1)
  o.data.materials.clear()
  o.data.materials.append(mat)
  for face in o.data.polygons: face.use_smooth=True
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert meshes, 'No mesh in human reference model'
# Keep imported mesh/skin/textures, normalize whole asset to 1.8 m
bpy.context.view_layer.update()
points=[o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
minimum=Vector([min(p[i] for p in points) for i in range(3)])
maximum=Vector([max(p[i] for p in points) for i in range(3)])
size=maximum-minimum
# Imported glTF is Y-up converted to Blender Z-up
assert size.z>0.01, 'Degenerate human model'
scale=1.8/size.z
center=(minimum+maximum)*0.5
# Scale via top-level objects so skeletal transformations stay intact
for o in list(bpy.context.scene.objects):
 if o.parent is None and o.type not in {'CAMERA','LIGHT'}:
  o.location=(o.location-center)*scale
  o.scale*=scale
bpy.context.view_layer.update()
# Recheck physical bounds and origin before rendering
points=[o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
mn=Vector([min(p[i] for p in points) for i in range(3)])
mx=Vector([max(p[i] for p in points) for i in range(3)])
target=(mn+mx)*0.5
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=512
scene.render.resolution_y=768
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
world=bpy.data.worlds.new('Neutral world')
scene.world=world
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(0.75,0.75,0.75,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0.8
bpy.ops.object.light_add(type='AREA',location=(3,-4,7))
lamp=bpy.context.object
lamp.data.energy=450
lamp.data.shape='DISK'
lamp.data.size=5
lamp.rotation_euler=(target-lamp.location).to_track_quat('-Z','Y').to_euler()
os.makedirs('rendered',exist_ok=True)
for label,az in [('front',0),('right',90),('back',180),('left',270)]:
 a=math.radians(az)
 e=math.radians(60)
 d=6
 pos=target+Vector((d*math.sin(a)*math.cos(e),-d*math.cos(a)*math.cos(e),d*math.sin(e)))
 bpy.ops.object.camera_add(location=pos)
 cam=bpy.context.object
 cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 cam.data.type='ORTHO'
 cam.data.ortho_scale=2.55
 scene.camera=cam
 scene.render.filepath=os.path.abspath('rendered/'+label+'.png')
 bpy.ops.render.render(write_still=True)
 bpy.data.objects.remove(cam,do_unlink=True)
with open('rendered/camera.json','w') as f:
 json.dump({'projection':'ORTHO','elevation_degrees':60,'azimuth_degrees':{'front':0,'right':90,'back':180,'left':270},'size':[512,768],'transparent':True,'asset':'MakeHuman CC0 base human mesh','license':'CC0-1.0','attribution':'MakeHuman Community','source':'https://github.com/makehumancommunity/makehuman/blob/master/makehuman/data/3dobjs/base.obj','model_height_m':1.8},f,indent=2)
