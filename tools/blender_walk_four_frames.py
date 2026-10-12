import bpy, math, json, os, pathlib, sys
from mathutils import Vector

ROOT = pathlib.Path(os.environ.get("WALK_SOURCE", "assets/walk_source"))
OUT = pathlib.Path("rendered/walk4")
OUT.mkdir(parents=True, exist_ok=True)
candidates = [p for p in ROOT.rglob("*") if p.suffix.lower() in {".fbx", ".glb", ".gltf", ".blend"}]
def score(p):
    s = str(p).lower()
    return (int("male" in s or "man" in s or "human" in s) * 20
            + int("character" in s) * 5 + int("walk" in s) * 4
            + int(p.suffix.lower()==".blend") * 2
            - int(any(w in s for w in ("zombie", "monster", "enemy", "goblin", "female"))) * 15)
candidates.sort(key=lambda p:(-score(p),str(p)))
print("CANDIDATES",len(candidates),[str(p) for p in candidates[:12]])
def load(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if p.suffix.lower()==".blend":
        bpy.ops.wm.open_mainfile(filepath=str(p.resolve()))
    elif p.suffix.lower()==".fbx":
        bpy.ops.import_scene.fbx(filepath=str(p.resolve()))
    else:
        bpy.ops.import_scene.gltf(filepath=str(p.resolve()))
def animated_rig():
    rigs=[o for o in bpy.data.objects if o.type=="ARMATURE"]
    for rig in rigs:
        actions=list(bpy.data.actions)
        preferred=[a for a in actions if "walk" in a.name.lower()]
        if preferred:
            return rig,preferred[0],"ACTION"
        tracks=[(strip,track) for track in rig.animation_data.nla_tracks for strip in track.strips] if rig.animation_data else []
        walks=[strip for strip,track in tracks if "walk" in (strip.name+" "+strip.action.name).lower()]
        if walks:
            return rig,walks[0].action,"NLA"
    return None,None,None
chosen=None
for p in candidates[:80]:
    try:
        load(p)
        rig,act,kind=animated_rig()
        if rig and act:
            chosen=(p,rig.name,act.name,kind)
            break
    except Exception as e:
        print("SKIP",str(p),str(e)[:160])
if not chosen:
    raise RuntimeError("No real rig with named walk animation found in checked CC0 source; refuse fake pose frames")
p,rig_name,action_name,kind=chosen
rig=bpy.data.objects[rig_name]
act=bpy.data.actions[action_name]
if not rig.animation_data: rig.animation_data_create()
rig.animation_data.action=act
for tr in rig.animation_data.nla_tracks: tr.mute=True
start,end=map(float,act.frame_range)
if end-start<4: raise RuntimeError("Walk action too short")
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2, 0) else "BLENDER_EEVEE"
scene.render.resolution_x=512
scene.render.resolution_y=768
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.render.film_transparent=True
scene.view_settings.view_transform="Standard"
meshes=[o for o in bpy.data.objects if o.type=="MESH" and o.visible_get()]
if not meshes: raise RuntimeError("No visible mesh")
def bounds():
    pts=[o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    lo=Vector((min(v[i] for v in pts) for i in range(3)))
    hi=Vector((max(v[i] for v in pts) for i in range(3)))
    return (lo+hi)/2, max((hi-lo).length,1.0)
scene.frame_set(round(start))
bpy.context.view_layer.update()
center,diam=bounds()
cam_data=bpy.data.cameras.new("FixedIso45_Orthographic")
cam=bpy.data.objects.new("FixedIso45_Orthographic",cam_data)
scene.collection.objects.link(cam)
scene.camera=cam
cam_data.type="ORTHO"
cam_data.ortho_scale=diam*1.35
elev=math.radians(45)
camera_azimuths = {"front":45, "right":135, "back":225, "left":315}
def set_camera_azimuth(degrees):
    az=math.radians(degrees)
    offset=Vector((math.cos(elev)*math.cos(az),-math.cos(elev)*math.sin(az),math.sin(elev)))*diam*2.5
    cam.location=center+offset
    cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
world=bpy.data.worlds.new("WalkNeutralWorld")
scene.world=world
world.use_nodes=True
world.node_tree.nodes.get("Background").inputs["Color"].default_value=(0.65,0.65,0.65,1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value=0.8
ld=bpy.data.lights.new("Softbox","AREA")
lamp=bpy.data.objects.new("Softbox",ld)
scene.collection.objects.link(lamp)
lamp.location=center+Vector((diam, -diam, diam*2))
ld.energy=850
ld.shape="DISK"
ld.size=max(diam,1)
lamp.rotation_euler=(center-lamp.location).to_track_quat("-Z","Y").to_euler()
frames=[int(round(start+(end-start)*i/4)) for i in range(4)]
pngs=[]
direction_outputs={}
for direction,azimuth in camera_azimuths.items():
    set_camera_azimuth(azimuth)
    bpy.context.view_layer.update()
    names=[]
    for i,frame in enumerate(frames,1):
        scene.frame_set(frame)
        name=f"{direction}_walk_{i:02d}.png"
        scene.render.filepath=str((OUT/name).resolve())
        bpy.ops.render.render(write_still=True)
        names.append(name)
        pngs.append(name)
    direction_outputs[direction]={"azimuth":azimuth,"frames":names}
source_info=json.loads((ROOT/"source.json").read_text()) if (ROOT/"source.json").exists() else {}
meta={"source":str(p),"license":source_info.get("license","unverified"),"source_page":source_info.get("page","unverified"),"rig":rig_name,"action":action_name,"kind":kind,"range":[start,end],"sample_frames":frames,"camera_elevation":45,"camera_azimuths":camera_azimuths,"directions":direction_outputs,"orthographic":True,"resolution":[512,768],"pngs":pngs}
(OUT/"walk_manifest.json").write_text(json.dumps(meta,indent=2))
print("WALK_RENDER_SUCCESS",json.dumps(meta))
