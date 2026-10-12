import bpy, zipfile, pathlib, json, hashlib, os, math
from mathutils import Vector
ROOT=pathlib.Path("rendered/chambersu_audit"); ROOT.mkdir(parents=True,exist_ok=True)
ZIP=pathlib.Path("input/chambersu.zip")
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assert ZIP.is_file()
with zipfile.ZipFile(ZIP) as z:
    names=z.namelist()
    assert len(names)<3000
    assert all(not n.startswith("/") and ".." not in pathlib.PurePosixPath(n).parts for n in names)
    formats=[n for n in names if n.lower().endswith((".blend",".glb",".gltf",".fbx"))]
    assert formats,"No importable model in archive"
    z.extractall("input/unpacked")
chosen=sorted(formats,key=lambda n:({".blend":0,".glb":1,".gltf":2,".fbx":3}.get(pathlib.Path(n).suffix.lower(),9),len(n)))[0]
source=pathlib.Path("input/unpacked")/chosen
bpy.ops.wm.read_factory_settings(use_empty=True)
ext=source.suffix.lower()
if ext==".blend:
    pass
