"""Experimental physically moving rigid 3D BJD pieces, projected into 2D 33 frames.
Produces diagnostics, never claims validated retarget/contact.
"""
import bpy, bmesh, pathlib, json, zipfile, math, hashlib, traceback
from mathutils import Vector, Matrix
OUT=pathlib.Path('rendered/chambersu_walk33');OUT.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile('input/chambersu.zip') as z:
    names=[i.filename for i in z.infolist() if i.filename.lower().endswith('.fbx')]
    assert len(names)==1
    assert not pathlib.PurePosixPath(names[0]).is_absolute() and '..' not in pathlib.PurePosixPath(names[0]).parts
    z.extract(names[0],'input/unpacked')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str((pathlib.Path('input/unpacked')/names[0]).resolve()))
objects=[o for o in bpy.data.objects if o.type=='MESH']
chests=sorted((o for o in objects if o.name.startswith('chestMesh')),key=lambda o:o.matrix_world.translation.x)
assert len(chests)==3
def center(o):
    return o.matrix_world @ (sum((Vector(c) for c in o.bound_box),Vector())/8)
chest_centers=[center(o) for o in chests]
keep=[o for o in objects if min(range(3),key=lambda k:(center(o)-chest_centers[k]).length)==1]
assert 30<=len(keep)<=50
for o in objects:o.hide_render=o not in keep
mid=chest_centers[1]
# Blender 'separate by loose parts' changes underlying geometry only; never blend bone weights here.
split_names=('tightMesh','kneeMesh','calfMesh','footMesh')
split_report=[]
for obj in list(keep):
    if not obj.name.startswith(split_names):continue
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True);bpy.context.view_layer.objects.active=obj
    pre=set(bpy.data.objects)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='LOOSE')
    bpy.ops.object.mode_set(mode='OBJECT')
    new=[o for o in bpy.data.objects if o not in pre and o.type=='MESH']
    for x in new:
        x.hide_render=False
        keep.append(x)
    split_report.append({'original':obj.name,'result_count':1+len(new)})
# Discover duplicate embedded left/right geometry from all component centers.
by_type={}
for o in keep:
    base=o.name.split('.')[0]
    if base in split_names:
        by_type.setdefault(base,[]).append(o)
for base,arr in by_type.items():
    arr.sort(key=lambda o:(center(o).x,center(o).y))
# Export component counts; fail if legs cannot be independently classified, rather than animate wrong.
classification={}
for base in split_names:
    arr=by_type.get(base,[])
    # pick two largest components, provided they lie on opposite sides of the pelvis.
    arr=sorted(arr,key=lambda o:len(o.data.vertices),reverse=True)
    pair=arr[:2]
    classification[base]=[{'name':o.name,'center':list(center(o)),'vertices':len(o.data.vertices)} for o in arr]
    assert len(pair)==2, 'Cannot independently isolate two '+base+' segments'
    assert (center(pair[0]).x-mid.x)*(center(pair[1]).x-mid.x)<0, 'Segments do not straddle pelvis: '+base
# Additional parts may form joints; choose only two largest per category for moving.
movables=[]
for base in split_names:
    two=sorted(by_type[base],key=lambda o:len(o.data.vertices),reverse=True)[:2]
    for side,obj in zip(('L','R'),sorted(two,key=lambda o:center(o).x,reverse=True)):
        movables.append((base,side,obj))
# Load source walking animation after BJD segmentation.
bpy.ops.import_scene.gltf(filepath=str(pathlib.Path('assets/walk_source/adventurer.glb').resolve()))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
action=next(a for a in bpy.data.actions if 'walk' in a.name.lower())
rig.animation_data_create();rig.animation_data.action=action
for track in rig.animation_data.nla_tracks:track.mute=True
source_meshes=[o for o in bpy.data.objects if o.type=='MESH' and o not in keep]
for o in source_meshes:o.hide_render=True
names=['Hips','UpperLeg.L','LowerLeg.L','Foot.L','UpperLeg.R','LowerLeg.R','Foot.R']
assert all(n in rig.pose.bones for n in names)
def joints(f):
    bpy.context.scene.frame_set(f)
    return {n:rig.matrix_world@rig.pose.bones[n].head.copy() for n in names}
frames=list(range(int(action.frame_range[0]),int(action.frame_range[0])+33))
assert frames[-1]<=int(action.frame_range[1])
first=joints(frames[0])
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version>=(4,2) else 'BLENDER_EEVEE'
scene.render.resolution_x=384;scene.render.resolution_y=576
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.eevee.taa_render_samples=16
loc=[o.matrix_world@Vector(c) for o in keep for c in o.bound_box]
low=Vector([min(v[k] for v in loc) for k in range(3)])
high=Vector([max(v[k] for v in loc) for k in range(3)])
origin=(low+high)/2;diam=max((high-low).length,1.)
cd=bpy.data.cameras.new('WalkIso45');cam=bpy.data.objects.new('WalkIso45',cd)
scene.collection.objects.link(cam);scene.camera=cam;cd.type='ORTHO';cd.ortho_scale=diam*1.6
cam.location=origin+Vector((1,-1,1)).normalized()*diam*2.6
cam.rotation_euler=(origin-cam.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('WalkWorld');world.use_nodes=True;scene.world=world
ld=bpy.data.lights.new('WalkSoft','AREA');light=bpy.data.objects.new('WalkSoft',ld);scene.collection.objects.link(light)
light.location=origin+Vector((diam,-diam,diam*2))
light.rotation_euler=(origin-light.location).to_track_quat('-Z','Y').to_euler()
ld.energy=950;ld.size=diam
original={o.name:o.matrix_world.copy() for _,_,o in movables}
center_original={o.name:center(o) for _,_,o in movables}
def source_pair(base,side):
    if base=='tightMesh':return 'UpperLeg.'+side,'LowerLeg.'+side
    if base=='kneeMesh':return 'UpperLeg.'+side,'LowerLeg.'+side
    if base=='calfMesh':return 'LowerLeg.'+side,'Foot.'+side
    return 'LowerLeg.'+side,'Foot.'+side
# Scale translation based on BJD leg: first-frame knees and ankles are not reinterpreted
# as native BJD joints; 0.7 is an explicit experimental motion scaling.
motion_scale=0.7
stats=[]
for idx,f in enumerate(frames):
    current=joints(f)
    maxrot=0
    for base,side,o in movables:
        a,b=source_pair(base,side)
        v0=first[b]-first[a];v1=current[b]-current[a]
        assert v0.length>1e-5 and v1.length>1e-5
        rotation=v0.rotation_difference(v1)
        angle=rotation.angle
        # Prevent implausible 180-degree source-axis inversions
        assert angle<math.radians(135)
        maxrot=max(maxrot,math.degrees(angle))
        pivot=center_original[o.name]
        displacement=(current[a]-first[a])*motion_scale
        worldmat=(Matrix.Translation(pivot+displacement)@rotation.to_matrix().to_4x4()
                  @Matrix.Translation(-pivot)@original[o.name])
        o.matrix_world=worldmat
    scene.render.filepath=str((OUT/('walk_%02d.png'%idx)).resolve())
    bpy.ops.render.render(write_still=True)
    stats.append({'frame':f,'max_rotation_deg':round(maxrot,4)})
# Restore originals to avoid output mixups
for _,_,o in movables:o.matrix_world=original[o.name]
report={'schema_version':1,'source_action':action.name,'frame_count':33,'selected_mesh_count':len(keep),
        'component_split':split_report,'classification':classification,
        'moved_rigid_components':[{'category':base,'side':side,'object':o.name,
                                   'pivot_heuristic':'component_boundbox_center'} for base,side,o in movables],
        'frames':stats,'retarget_level':'experimental_3d_component_rotation_no_true_anatomical_pivot',
        'limits':['Vertex island split is not proof of correct anatomy',
        'Rotations follow source segment vectors; translations scaled heuristically',
        'No actual knee hinge or foot toe contact solution',
        'No measured projected seam, collision, or foot slip; do not claim solved']}
(OUT/'walk_report.json').write_text(json.dumps(report,indent=2))
print('BJD_WALK33_SUCCESS',len(movables),len(stats))
