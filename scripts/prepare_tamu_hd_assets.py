"""Extract the two user-uploaded TAMU ZIPs and build 512px/mobile material atlases.
Safe, deterministic extraction: no path traversal or shell interpretation.
Source images are not repainted, only the runtime atlas is resized.
"""
from pathlib import Path
from zipfile import ZipFile
from PIL import Image
import hashlib, json, shutil, sys

ROOT=Path(__file__).resolve().parents[1]
ZIPS=[ROOT/"TAMU_Doga_Assetleri_Bolum_1_Terrain_20261112.zip",
      ROOT/"TAMU_Doga_Assetleri_Bolum_2_Agaclar_20261112.zip"]
TREE_IDS=["fractureborn_oak","skyward_forest_oak","stormslope_beech",
          "marshkeeper_alder","rootbound_hornbeam","ironwind_pine",
          "ashskin_birch","borderwatch_ash"]
MATERIAL_IDS=["forest_grass","forest_rocky","forest_sparse_litter",
              "forest_roots_litter","conifer_needle_litter","forest_moss_pebbles"]
TARGET=ROOT/"assets"
for zip_path in ZIPS:
    if not zip_path.is_file():
        sys.exit(f"MISSING_INPUT_ZIP {zip_path}")
    with ZipFile(zip_path) as z:
        bad=z.testzip()
        if bad: sys.exit(f"CRC_FAILED {bad}")
        for member in z.infolist():
            rel=Path(member.filename)
            parts=rel.parts
            if member.is_dir(): continue
            if len(parts)!=3 or parts[0] not in ("trees","terrain") or parts[2] not in ("albedo.png","height.png","normal.png"):
                continue
            valid= TREE_IDS if parts[0]=="trees" else MATERIAL_IDS
            if parts[1] not in valid: sys.exit(f"UNEXPECTED_FILE {rel}")
            if parts[0]=="trees" and parts[2]=="height.png":
                sys.exit(f"UNEXPECTED_TREE_HEIGHT {rel}")
            dst=TARGET / rel
            dst.parent.mkdir(parents=True,exist_ok=True)
            with z.open(member) as src, dst.open("wb") as out:
                shutil.copyfileobj(src,out)
for name in TREE_IDS:
    for kind in ("albedo","normal"):
        p=TARGET/"trees"/name/(kind+".png")
        if not p.is_file():sys.exit(f"MISSING_TREE_IMAGE {p}")
        with Image.open(p) as im:
            assert im.size==(1254,1254) and im.mode=="RGBA",(p,im.size,im.mode)
for name in MATERIAL_IDS:
    sizes=[]
    for kind in ("albedo","height","normal"):
        p=TARGET/"terrain"/name/(kind+".png")
        if not p.is_file():sys.exit(f"MISSING_TERRAIN_IMAGE {p}")
        with Image.open(p) as im:
            sizes.append(im.size)
    assert len(set(sizes))==1 and sizes[0]==(1536,1536),(name,sizes)

OUT=TARGET/"terrain"/"material_atlas"
OUT.mkdir(parents=True,exist_ok=True)
for channel in ("albedo","normal","height"):
    atlas=Image.new("RGB",(1536,1024))
    for i,name in enumerate(MATERIAL_IDS):
        with Image.open(TARGET/"terrain"/name/(channel+".png")) as img:
            tile=img.convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
            atlas.paste(tile,((i%3)*512,(i//3)*512))
    atlas.save(OUT/(channel+".png"),optimize=True)
manifest={"schema":"tamu.hd-materials.v1","tile_size":512,"atlas":[3,2],
          "terrain_order":MATERIAL_IDS,"tree_ids":TREE_IDS,
          "notes":"Experimental shader relighting; height is low-relief shading only. UV seams not yet verified."}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("TAMU_HD_ASSETS_EXTRACT_OK terrain=6 trees=8")
print("TAMU_HD_ATLAS_OK size=1536x1024")
