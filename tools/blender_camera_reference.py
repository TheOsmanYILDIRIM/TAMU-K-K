import bpy, math, os, json
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);return m
skin=material('Neutral warm gray',(0.64,0.60,0.55)); cloth=material('Neutral slate',(0.38,0.43,0.45))
def ellipsoid(name,loc,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);return o
def link(name,a,b,r,mat):
 a,b=Vector(a),Vector(b);mid=(a+b)*0.5
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=mid)
 o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
ellipsoid('Head',(0,0,1.72),(.13,.115,.18),skin)
ellipsoid('Torso',(0,0,1.24),(.26,.15,.39),cloth)
ellipsoid('Pelvis',(0,0,.93),(.21,.14,.14),cloth)
for s in [-1,1]:
 x=s*.31
 link('UpperArm', (x,0,1.43),(x*1.12,0,1.12),.075,skin)
 link('Forearm',(x*1.12,0,1.12),(x*1.12,-.04,.89),.062,skin)
 ellipsoid('Hand',(x*1.12,-.04,.85),(.07,.06,.10),skin)
 link('Thigh',(s*.12,0,.90),(s*.14,0,.51),.11,cloth)
 link('Shin',(s*.14,0,.51),(s*.14,-.015,.14),.078,cloth)
 ellipsoid('Foot',(s*.14,-.075,.08),(.105,.18,.08),cloth)
world=bpy.context.scene.world;world.color=(0.7,0.7,0.7)
def area(loc,power,size):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
area((3,-4,7),450,5)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2,0) else 'BLENDER_EEVEE'
scene.render.resolution_x=512;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
os.makedirs('rendered',exist_ok=True)
for label,az in [('front',0),('right',90),('back',180),('left',270)]:
 a=math.radians(az);e=math.radians(60);d=6
 bpy.ops.object.camera_add(location=(d*math.sin(a)*math.cos(e),-d*math.cos(a)*math.cos(e),1+d*math.sin(e)))
 cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.65
 scene.camera=cam;scene.render.filepath=os.path.abspath('rendered/'+label+'.png');bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
with open('rendered/camera.json','w') as f:json.dump({'projection':'ORTHO','elevation_degrees':60,'azimuth_degrees':{'front':0,'right':90,'back':180,'left':270},'size':[512,768],'transparent':True},f,indent=2)
