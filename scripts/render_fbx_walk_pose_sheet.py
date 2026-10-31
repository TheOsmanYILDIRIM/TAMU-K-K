#!/usr/bin/env python3
"""Render 8 actual Walking.fbx pose samples as a side-profile skeleton reference.
Adventurer GLB supplies the target character's proportions, not fake walk poses.
Run inside Blender: blender -b --python scripts/render_fbx_walk_pose_sheet.py -- --repo .
"""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

def main():
    argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo",default=".")
    ap.add_argument("--output",default="ci-output/walking-pose-frames")
    args=ap.parse_args(argv)
    repo=Path(args.repo).resolve()
    dst=(repo/args.output).resolve()
    dst.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(repo/"Adventurer by Quaternius - 5EGWBMpuXq.glb"))
    glb_meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not glb_meshes: raise RuntimeError("No GLB character meshes")
    coords=[o.matrix_world @ Vector(c) for o in glb_meshes for c in o.bound_box]
    glb_h=max(c.z for c in coords)-min(c.z for c in coords)
    glb_w=max(c.x for c in coords)-min(c.x for c in coords)
    if glb_h<=0: raise RuntimeError("Invalid GLB proportions")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(repo/"Walking.fbx"),automatic_bone_orientation=False)
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    if not rigs: raise RuntimeError("Walking FBX has no animated armature")
    rig=max(rigs,key=lambda o:len(o.pose.bones))
    actions=list(bpy.data.actions)
    action=next((a for a in actions if "walk" in a.name.lower()),None)
    if action is None: action=max(actions,key=lambda a:a.frame_range[1]-a.frame_range[0]) if actions else None
    if action is None: raise RuntimeError("Walking.fbx lacks an action")
    rig.animation_data_create()
    rig.animation_data.action=action
    if hasattr(rig.animation_data,"action_slot") and getattr(action,"slots",None):
        rig.animation_data.action_slot=action.slots[0]
    first,last=action.frame_range
    if last-first<4: raise RuntimeError("FBX animation too short")
    names=[b.name for b in rig.pose.bones]
    print("TAMU_FBX_BONES",json.dumps(names))
    print("TAMU_GLB_PROPORTIONS",glb_h,glb_w)
    print("TAMU_FBX_ACTION",action.name,first,last)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"  # CPU headless runner; Eevee needs libEGL
    scene.cycles.samples=4
    for layer in scene.view_layers: layer.cycles.use_denoising=False
    scene.render.resolution_x=256;scene.render.resolution_y=384
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.film_transparent=False
    scene.world.color=(1,1,1)
    scene.view_settings.view_transform="Standard"
    scene.render.image_settings.color_depth="8"
    for obj in list(scene.objects):
        if obj.type=="MESH": bpy.data.objects.remove(obj,do_unlink=True)
    # Use +X camera to obtain strict profile of the animation, never a 45° diagonal view.
    # For differing bone orientation, choose horizontal axis showing maximum pose excursion.
    points=[]
    for i in range(8):
        scene.frame_set(round(first+(last-first)*i/8))
        points.extend([rig.matrix_world @ b.head for b in rig.pose.bones])
        points.extend([rig.matrix_world @ b.tail for b in rig.pose.bones])
    xs=[p.x for p in points]; ys=[p.y for p in points];zs=[p.z for p in points]
    hor_axis = 0 if max(ys)-min(ys)>=max(xs)-min(xs) else 1
    min_z,max_z=min(zs),max(zs)
    center=Vector(((min(xs)+max(xs))/2,(min(ys)+max(ys))/2,(min_z+max_z)/2))
    src_h=max_z-min_z
    # Scale FBX world measurements to the GLB character's physical height.
    scale=glb_h/max(src_h,1e-6)
    scene.render.film_transparent=True
    mat=bpy.data.materials.new("TAMU skeleton black")
    mat.diffuse_color=(.018,.02,.024,1)
    mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear()
    out=nodes.new("ShaderNodeOutputMaterial")
    emission=nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value=(.012,.015,.019,1)
    emission.inputs["Strength"].default_value=1
    mat.node_tree.links.new(emission.outputs[0],out.inputs["Surface"])
    nodes2=mat
    camera_data=bpy.data.cameras.new("Side orthographic")
    camera_data.type="ORTHO"
    camera_data.ortho_scale=glb_h*1.35
    camera=bpy.data.objects.new("Side orthographic",camera_data)
    scene.collection.objects.link(camera);scene.camera=camera
    view=Vector((1,0,0)) if hor_axis==0 else Vector((0,1,0))
    camcenter=Vector((0,0,glb_h*.53))
    camera.location=camcenter+view*glb_h*3
    camera.rotation_euler=(camcenter-camera.location).to_track_quat("-Z","Y").to_euler()
    def segment(a,b,r=.012):
        d=b-a
        if d.length<1e-5: return None
        bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r*glb_h,depth=d.length,location=(a+b)*.5)
        obj=bpy.context.object;obj.rotation_euler=d.to_track_quat("Z","Y").to_euler()
        obj.data.materials.append(mat);return obj
    def joint(p,r=.018):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=r*glb_h,location=p)
        bpy.context.object.data.materials.append(mat)
        return bpy.context.object
    metadata=[]
    last_points=None
    for i in range(8):
        at=round(first+(last-first)*i/8)
        scene.frame_set(at)
        # Deformed armature pose positions are native FBX animation matrices.
        skeleton=[]
        for b in rig.pose.bones:
            a=(rig.matrix_world @ b.head-center)*scale
            end=(rig.matrix_world @ b.tail-center)*scale
            a.z+=glb_h*.53;end.z+=glb_h*.53
            if (end-a).length>.008*glb_h:
                skeleton.append((a,end,b.name))
        if len(skeleton)<10: raise RuntimeError("Not enough pose bones for reference")
        current=[(str(n),round(a.y if hor_axis==0 else a.x,4),round(a.z,4)) for a,b,n in skeleton]
        if current==last_points: raise RuntimeError("FBX walk cycle has identical adjacent frames")
        last_points=current
        render_objects=[]
        for a,b,n in skeleton:
            z=segment(a,b); 
            if z:render_objects.append(z)
            render_objects.append(joint(a))
        scene.render.filepath=str(dst/f"frame_{i+1:02d}.png")
        bpy.ops.render.render(write_still=True)
        metadata.append({"frame":i+1,"fbx_frame":at,"bones":len(skeleton)})
        for obj in render_objects:bpy.data.objects.remove(obj,do_unlink=True)
    (dst/"pose_metadata.json").write_text(json.dumps({
       "source_model":"Adventurer by Quaternius - 5EGWBMpuXq.glb",
       "source_motion":"Walking.fbx",
       "motion_action":action.name,"glb_height":glb_h,
       "camera_profile_degrees":0,"frames":metadata
    },indent=2))
    print("TAMU_FBX_WALK_8_POSES_OK",len(metadata),dst)
if __name__=="__main__":main()
