"""Build TAMU's low-sampling HD mobile materials from existing checked-in sources.

- Preserve the native 14x12 (132px per slot, 2px gutter) terrain UV contract.
- Copy original atlas for wetland; only 137 land slots are HD-repainted.
- Mix height-derived gradients into decoded tangent normals OFFLINE.
- Re-encode and renormalize 8 paired tree normals at 768px, source 1254px untouched.
- No scene geometry, canonical source names, collision or gameplay changes.
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image
import hashlib
import json
import math
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets"
OLD = ROOT / "game/love/assets/terrain25d"
OUT = BASE / "terrain/hd_fast_atlas"
MOBILE = BASE / "trees/mobile_768"
FAMILIES = ("forest_grass", "forest_rocky", "forest_sparse_litter",
            "forest_roots_litter", "conifer_needle_litter", "forest_moss_pebbles")
TREES = ("fractureborn_oak", "skyward_forest_oak", "stormslope_beech",
         "marshkeeper_alder", "rootbound_hornbeam", "ironwind_pine",
         "ashskin_birch", "borderwatch_ash")
SLOTS_X, SLOTS_Y, STRIDE, TILE, PAD = 14, 12, 132, 128, 2
SIZE = (SLOTS_X * STRIDE, SLOTS_Y * STRIDE)
MOBILE_SIZE = (768, 768)
MAGIC = b"\x89PNG\r\n\x1a\n"

def open_image(path: Path, mode: str) -> Image.Image:
    if path.suffix.lower() == ".png" and path.open("rb").read(8) != MAGIC:
        raise ValueError(f"Not a genuine PNG: {path}")
    with Image.open(path) as im:
        im.load()
        return im.convert(mode)

def checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def padded(tile: Image.Image) -> Image.Image:
    # Mirror edge colors into all four gutters: avoid stale-atlas texture bleeding.
    array = np.asarray(tile)
    return Image.fromarray(np.pad(array, ((PAD, PAD),(PAD, PAD),(0,0)),
                                    mode="edge").astype(np.uint8), tile.mode)

def height_augmented_normal(normal: Image.Image, height: Image.Image) -> Image.Image:
    n = np.asarray(normal.convert("RGB"),dtype=np.float32) / 127.5 - 1.0
    h = np.asarray(height.convert("L"),dtype=np.float32) / 255.0
    dx = (np.roll(h,-1,axis=1)-np.roll(h,1,axis=1))*0.5
    dy = (np.roll(h,-1,axis=0)-np.roll(h,1,axis=0))*0.5
    # Height remains a low-relief directional perturbation, never displacement.
    n[:,:,0] -= np.clip(dx*3.0,-0.22,0.22)
    n[:,:,1] -= np.clip(dy*3.0,-0.22,0.22)
    n[:,:,2] = np.maximum(n[:,:,2],0.20)
    n /= np.maximum(np.linalg.norm(n,axis=2,keepdims=True),1e-5)
    rgb = np.clip(np.rint((n*0.5+0.5)*255.0),0,255).astype(np.uint8)
    alpha = np.full((*rgb.shape[:2],1),255,dtype=np.uint8)
    return Image.fromarray(np.concatenate((rgb,alpha),axis=2),"RGBA")

def terrain_index(family: str, x: int, y: int) -> int:
    return {"grass":0,"rock":1,"dirt":2}.get(family,
        (3 + (x + y*3) % 3) if family == "forest" else -1)

def bake_terrain() -> dict:
    old = open_image(OLD/"atlas_00.png", "RGB")
    if old.size != SIZE:
        raise ValueError(f"Unexpected legacy atlas dimensions {old.size} vs {SIZE}")
    manifest = json.loads((OLD/"manifest.json").read_text())
    albedo = old.copy()
    # Alpha 0 on wetland means no relighting; preserve original water look.
    neutral = np.empty((SIZE[1], SIZE[0],4),dtype=np.uint8)
    neutral[:,:,:] = [128,128,255,0]
    normal_atlas = Image.fromarray(neutral,"RGBA")
    cache = {}
    inputs = {}
    for i,name in enumerate(FAMILIES):
        path = BASE/"terrain"/name
        trio = [path/(c+".png") for c in ("albedo","normal","height")]
        for p in trio:
            if not p.is_file():
                raise FileNotFoundError(p)
            inputs[str(p.relative_to(ROOT))] = checksum(p)
        tile_color = open_image(trio[0],"RGB").resize((TILE,TILE),Image.Resampling.LANCZOS)
        tile_normal = open_image(trio[1],"RGB").resize((TILE,TILE),Image.Resampling.LANCZOS)
        tile_height = open_image(trio[2],"L").resize((TILE,TILE),Image.Resampling.LANCZOS)
        cache[i] = (padded(tile_color),
                    padded(height_augmented_normal(tile_normal,tile_height)))
    seen = {}
    counts = {name:0 for name in FAMILIES}
    wetland = 0
    for entry in manifest["assets"]:
        if entry.get("kind") != "terrain" or entry.get("atlas_page") != "atlas_00.png":
            continue
        u,v,*_ = entry["uv_rect"]
        x = math.floor(float(u)*SLOTS_X)
        y = math.floor(float(v)*SLOTS_Y)
        if not 0<=x<SLOTS_X or not 0<=y<SLOTS_Y or (x,y) in seen:
            raise ValueError(f"Duplicate/out-of-grid terrain slot: {(x,y)}")
        seen[(x,y)] = str(entry["family"])
        index = terrain_index(str(entry["family"]),x,y)
        if index < 0:
            if entry["family"] != "wetland":
                raise ValueError(f"Unknown family {entry['family']}")
            wetland += 1
            continue
        rgba, nrm = cache[index]
        albedo.paste(rgba,(x*STRIDE,y*STRIDE))
        normal_atlas.paste(nrm,(x*STRIDE,y*STRIDE))
        counts[FAMILIES[index]] += 1
    if len(seen) != 168 or wetland != 31 or sum(counts.values()) != 137:
        raise ValueError(f"Terrain slot coverage mismatch seen={len(seen)} wet={wetland} land={counts}")
    OUT.mkdir(parents=True,exist_ok=True)
    albedo.save(OUT/"albedo.png", optimize=True)
    normal_atlas.save(OUT/"normal.png", optimize=True)
    return {"slots":len(seen),"wetland_preserved":wetland,"new_land":sum(counts.values()),
            "materials":counts,"source_sha256":inputs,
            "packed_sha256":{p.name:checksum(p) for p in (OUT/"albedo.png", OUT/"normal.png")}}

def bake_trees() -> dict:
    MOBILE.mkdir(parents=True,exist_ok=True)
    result = {}
    for name in TREES:
        src = BASE/"trees"/name
        a = open_image(src/"albedo.png","RGBA")
        n = open_image(src/"normal.png","RGBA")
        if a.size != (1254,1254) or n.size != a.size:
            raise ValueError(f"Tree source mismatch: {name}, {a.size}, {n.size}")
        a = a.resize(MOBILE_SIZE,Image.Resampling.LANCZOS)
        n = n.resize(MOBILE_SIZE,Image.Resampling.LANCZOS)
        n_rgb = np.asarray(n,dtype=np.uint8)[:,:,:3].astype(np.float32)/127.5-1.0
        n_rgb[:,:,2] = np.maximum(n_rgb[:,:,2],0.12)
        n_rgb /= np.maximum(np.linalg.norm(n_rgb,axis=2,keepdims=True),1e-6)
        vals = np.clip(np.rint((n_rgb*0.5+0.5)*255),0,255).astype(np.uint8)
        vals = np.concatenate([vals,np.asarray(a,dtype=np.uint8)[:,:,3:4]],axis=2)
        folder = MOBILE/name
        folder.mkdir(parents=True,exist_ok=True)
        a.save(folder/"albedo.png",optimize=True)
        Image.fromarray(vals,"RGBA").save(folder/"normal.png",optimize=True)
        result[name] = {"size":[768,768],
                        "source_normal":checksum(src/"normal.png"),
                        "mobile_albedo":checksum(folder/"albedo.png"),
                        "mobile_normal":checksum(folder/"normal.png")}
    return result

def main():
    terrain = bake_terrain()
    trees = bake_trees()
    manifest = {
        "schema":"tamu.hd-fast-materials.v1","terrain":terrain,"trees":trees,
        "runtime_samples":"terrain: albedo+normal only (height baked into normal)",
        "source_tree_size":[1254,1254],"runtime_tree_size":[768,768],
        "notes":"Legacy wetland albedo unchanged, no canonical gameplay/collision modified."}
    (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    # Verify generated files and alpha contract; fail workflow instead of shipping bad data.
    for path in list(OUT.glob("*.png"))+list(MOBILE.glob("*/*.png")):
        assert path.read_bytes()[:8] == MAGIC, path
        with Image.open(path) as image:
            image.verify()
    assert all(np.array_equal(np.asarray(open_image(MOBILE/n/"albedo.png","RGBA"))[:,:,3],
                              np.asarray(open_image(MOBILE/n/"normal.png","RGBA"))[:,:,3])
               for n in TREES)
    print("TAMU_HD_FAST_ATLAS_READY slots=168 land=137 wetland=31 maps=2 size=1848x1584")
    print("TAMU_HD_FAST_TREES_READY species=8 size=768x768 normals=8")
    print("TAMU_HD_FAST_SOURCE_PNG_OK terrain_source=18 tree_source=16")
if __name__=="__main__":
    main()
