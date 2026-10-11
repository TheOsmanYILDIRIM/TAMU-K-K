import bpy, math, os, json, zipfile, tempfile, pathlib, traceback
from mathutils import Vector
archive=pathlib.Path('assets/reference/human-base-meshes.zip')
out=pathlib.Path('rendered');out.mkdir(exist_ok=True)
with zipfile.ZipFile(archive) as z:
    blends=[x for x in z.infolist() if x.filename.lower().endswith('.blend') and not x.filename.startswith('__MACOSX/')]
    assert blends,'No Blender source found'
    # Prefer main character/base scene over small auxiliary libraries.
    blends.sort(key=lambda x: ('human' in x.filename.lower() or 'base' in x.filename.lower(),x.file_size),reverse=True)
    chosen=blends[0]
    with tempfile.TemporaryDirectory() as td:
        # Zip-slip protection
        assert not pathlib.PurePosixPath(chosen.filename).is_absolute() and '..' not in pathlib.PurePosixPath(chosen.filename).parts
        path=pathlib.Path(td,'source.blend')
        with z.open(chosen) as src, open(path,'wb') as dst:
            import shutil;shutil.copyfileobj(src,dst)
        print('OPENING',chosen.filename,'BYTES',chosen.file_size,flush=True)
        bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
meshes=[o for o in bpy.data.objects if o.type=='MESH']
objects=[{'name':o.name,'vertices':len(o.data.vertices),'dimensions':list(o.dimensions),'hidden':o.hide_render} for o in meshes]
out.joinpath('scene_inspection.json').write_text(json.dumps({'source_file':chosen.filename,'meshes':objects[:100],'mesh_count':len(objects)},indent=2))
assert meshes,'No meshes in Blender source'
# Prefer a whole standing human mesh: tall relative to width, sufficiently detailed, non-hidden.
candidates=[o for o in meshes if len(o.data.vertices)>500 and o.dimensions.z>0.1 and o.dimensions.z>o.dimensions.x*1.15]
if not candidates:
    candidates=[o for o in meshes if len(o.data.vertices)>500]
assert candidates,'No human candidate'
candidates.sort(key=lambda o:(o.dimensions.z>o.dimensions.x*1.5,len(o.data.vertices)),reverse=True)
model=candidates[0]
print('SELECTED',model.name,tuple(model.dimensions),len(model.data.vertices),flush=True)
# Hide everything else, including reference stages, for clean single-character render.
for o in bpy.data.objects:
    if o.type=='MESH':o.hide_render=(o!=model)
    elif o.type in {'LIGHT','CAMERA','CURVE','FONT','GREASEPENCIL'}:o.hide_render=True
# Normalize geometry via model matrix rather than destructively changing the original source.
bpy.context.view_layer.update()
pts=[model.matrix_world@Vector(c) for c in model.bound_box]
mn=Vector([min(p[i] for p in pts) for i in range(3)])
mx=Vector([max(p[i] for p in pts) for i in range(3)])
center=(mn+mx)*.5
size=mx-mn
assert size.z>0.01,'Candidate not upright in Z'
# Use a root collection to shift and scale without changing the mesh data.
bpy.ops.object.empty_add(type='PLAIN_AXES')
root=bpy.context.object;root.name='ReferenceNormalizer'
world=model.matrix_world.copy()
model.parent=root
model.matrix_world=world
root.location=-center*(1.8/size.z)
root.scale=(1.8/size.z,)*3
bpy.context.view_layer.update()
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2,0) else 'BLENDER_EEVEE'
scene.render.resolution_x=512;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
world=bpy.data.worlds.new('NeutralWorld');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(0.8,0.8,0.8,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
bpy.ops.object.light_add(type='AREA',location=(3,-4,6))
light=bpy.context.object;light.hide_render=False;light.data.energy=450;light.data.size=5
light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
for label,az in [('front',0),('right',90),('back',180),('left',270)]:
    a=math.radians(az);e=math.radians(45);d=6
    pos=Vector((d*math.sin(a)*math.cos(e),-d*math.cos(a)*math.cos(e),d*math.sin(e)))
    bpy.ops.object.camera_add(location=pos)
    cam=bpy.context.object;cam.hide_render=False
    cam.rotation_euler=(-pos).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=2.7
    scene.camera=cam;scene.render.filepath=str(out.joinpath(label+'.png').resolve())
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam,do_unlink=True)
out.joinpath('camera.json').write_text(json.dumps({'projection':'ORTHO','elevation_degrees':45,'azimuth_degrees':{'front':0,'right':90,'back':180,'left':270},'size':[512,768],'transparent':True,'source':'Blender Human Base Meshes v1.4.1','source_file':chosen.filename,'selected_mesh':model.name},indent=2))
