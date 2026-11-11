"""Fast CC0 tree true-orthographic 30-degree reference without Blender."""
import json, math, os
import numpy as np
import trimesh
from matplotlib import pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.colors import to_rgba

scene = trimesh.load("source/tree_oak.glb", force="scene")
triangles, colors = [], []
for node in scene.graph.nodes_geometry:
    transform, name = scene.graph[node]
    mesh = scene.geometry[name]
    mesh = mesh.copy()
    mesh.apply_transform(transform)
    tri = mesh.triangles
    triangles.append(tri)
    if hasattr(mesh.visual, "face_colors") and len(mesh.visual.face_colors) == len(tri):
        colors.extend(np.asarray(mesh.visual.face_colors, dtype=float) / 255)
    else:
        colors.extend([[0.43, 0.52, 0.33, 1]] * len(tri))
assert triangles, "Missing 3D mesh"
triangles = np.concatenate(triangles)
colors = np.asarray(colors)
center = (triangles.min(axis=(0,1)) + triangles.max(axis=(0,1))) / 2
triangles -= center
elev = math.radians(30)
azim = math.radians(45)
towards = np.array([math.cos(elev)*math.cos(azim), math.cos(elev)*math.sin(azim), math.sin(elev)])
right = np.array([-math.sin(azim), math.cos(azim), 0.])
up = np.cross(towards, right)
up /= np.linalg.norm(up)
p = np.stack((triangles @ right, triangles @ up), axis=-1)
depth = triangles.mean(axis=1) @ towards
# Far faces first; simple opaque painter approach for shape calibration.
order = np.argsort(depth)
xy = p[order]
color = colors[order]
fig = plt.figure(figsize=(8,8),dpi=128)
ax = fig.add_axes([0.02,0.02,0.96,0.96])
ax.set_facecolor((1,1,1,0))
poly = PolyCollection(xy, facecolors=color, edgecolors="none", antialiased=False)
ax.add_collection(poly)
extent = max(float(np.ptp(p[:,:,0])),float(np.ptp(p[:,:,1])))
xc = float((p[:,:,0].min()+p[:,:,0].max())/2)
yc = float((p[:,:,1].min()+p[:,:,1].max())/2)
ax.set_xlim(xc-extent*.66,xc+extent*.66)
ax.set_ylim(yc-extent*.66,yc+extent*.66)
ax.set_aspect("equal")
ax.axis("off")
os.makedirs("tree-camera-refs",exist_ok=True)
out="tree-camera-refs/oak_ortho_elev_30.png"
fig.savefig(out,transparent=True,dpi=128,pad_inches=0)
with open("tree-camera-refs/camera_manifest.json","w") as f:
    json.dump({"source":"Kenney CC0 tree_oak.glb","elevation":30,"azimuth":45,"camera":"ORTHOGRAPHIC","renderer":"matplotlib mesh triangles","note":"Geometry calibration only, not photoreal material reference."},f,indent=2)
print("TAMU_CAMERA_REFERENCE_RENDER_OK",out,os.path.getsize(out))
