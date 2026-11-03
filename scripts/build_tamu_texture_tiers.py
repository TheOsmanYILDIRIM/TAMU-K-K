
#!/usr/bin/env python3
"""TAMU lossless-source texture quality tiers. Requires Pillow and canonical manifest."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from PIL import Image

SOURCE_SIZE = 384
BASE_SIZE = 128
GRID_COLS, GRID_ROWS, CELL_BASE, GUTTER_BASE = 14, 12, 132, 2
ORIGINALS = {
    "grass": "terrain_grass_contact_sheet_{tag}.png",
    "forest": "forest_floor_contact_sheet_{tag}_original.png",
    "dirt": "dirt_path_contact_dirt{tag}_original.png",
    "rock": "rock{tag}_{code}.png",
    "wetland": "Riverbank_Wetland_{tag}_Original.png",
}
ROCK_CODES = {"A": "122944", "B": "122943", "C": "122942"}

def origin_for(asset):
    family, name = asset["family"], asset["original_filename"]
    if family in ("grass", "forest"):
        m = re.search(r"(12\d{4})_r([1-3])c([1-4])_(\d{2})", name)
        if not m:
            raise ValueError(f"Unknown source layout: {family}/{name}")
        tag, row, col, number = m.groups()
        row, col, number = int(row), int(col), int(number)
        if (row-1)*4+col != number:
            raise ValueError(f"Row/column disagree: {name}")
    else:
        m = re.search(r"(?:dirt|rock|Wetland_)([ABC])_(\d{2})", name, re.I)
        if not m:
            raise ValueError(f"Unknown source layout: {family}/{name}")
        tag, number = m.groups()
        tag = tag.upper()
        number = int(number)
        row, col = divmod(number-1, 4)
        row += 1
        col += 1
    if row not in range(1,4) or col not in range(1,5):
        raise ValueError(f"Out of range: {name}")
    if family=="rock":
        sheet_name = ORIGINALS[family].format(tag=tag,code=ROCK_CODES[tag])
    else:
        sheet_name = ORIGINALS[family].format(tag=tag)
    return sheet_name, ((col-1)*SOURCE_SIZE, (row-1)*SOURCE_SIZE,
                        col*SOURCE_SIZE, row*SOURCE_SIZE)

def tile_for(asset, sources, cache):
    sheet, box = origin_for(asset)
    if sheet not in cache:
        path=sources/sheet
        if not path.exists():
            raise FileNotFoundError(f"Missing original source: {path}")
        im=Image.open(path).convert("RGB")
        if im.size != (1536, 1152):
            raise ValueError(f"Invalid source sheet {sheet}: {im.size}")
        cache[sheet]=im
    return cache[sheet].crop(box)

def build(manifest, sources, dest, size):
    if size not in (128,256,384):
        raise ValueError("Terrain tiers: 128/256/384")
    assets=[x for x in manifest["assets"] if x.get("kind")=="terrain" and x.get("atlas_page")=="atlas_00.png"]
    if len(assets)!=168:
        raise ValueError(f"Expected exactly 168 terrain materials, got {len(assets)}")
    factor=size/BASE_SIZE
    cell=size+int(4*factor)
    gutter=int(GUTTER_BASE*factor)
    aw,ah=GRID_COLS*cell,GRID_ROWS*cell
    atlas=Image.new("RGB",(aw,ah))
    cache={}
    occupied=set()
    mappings=[]
    for asset in assets:
        tile=tile_for(asset,sources,cache)
        if size!=SOURCE_SIZE:
            tile=tile.resize((size,size),Image.Resampling.LANCZOS)
        u=asset["uv_rect"]
        col=round((float(u[0])*1848-2)/132)
        row=round((float(u[1])*1584-2)/132)
        if col not in range(14) or row not in range(12) or (col,row) in occupied:
            raise ValueError(f"Invalid or duplicate atlas location: {asset['original_filename']}: {col,row}")
        occupied.add((col,row))
        x,y=col*cell+gutter,row*cell+gutter
        atlas.paste(tile,(x,y))
        if gutter:
            atlas.paste(tile.crop((0,0,1,size)).resize((gutter,size)),(x-gutter,y))
            atlas.paste(tile.crop((size-1,0,size,size)).resize((gutter,size)),(x+size,y))
            atlas.paste(tile.crop((0,0,size,1)).resize((size,gutter)),(x,y-gutter))
            atlas.paste(tile.crop((0,size-1,size,size)).resize((size,gutter)),(x,y+size))
            for xx,srcx in [(x-gutter,0),(x+size,size-1)]:
                for yy,srcy in [(y-gutter,0),(y+size,size-1)]:
                    atlas.paste(tile.crop((srcx,srcy,srcx+1,srcy+1)).resize((gutter,gutter)),(xx,yy))
        new_u=(x/aw,y/ah,size/aw,size/ah)
        if max(abs(float(a)-float(b)) for a,b in zip(new_u,u))>0.00001:
            raise ValueError(f"UV drift: {asset['original_filename']} {new_u} != {u}")
        mappings.append({"name":asset["original_filename"],
                         "source":origin_for(asset)[0],
                         "source_crop":origin_for(asset)[1],
                         "atlas_col":col,"atlas_row":row})
    if len(occupied)!=168:
        raise ValueError("Missing or duplicate UV slots")
    dest.mkdir(parents=True,exist_ok=True)
    output=dest/f"atlas_00_terrain_{size}.png"
    atlas.save(output,format="PNG",optimize=True)
    mix=blend_terrain(atlas,assets,size)
    mix_output=dest/f"atlas_00_terrain_mix_{size}.png"
    mix.save(mix_output,format="PNG",optimize=True)
    with Image.open(output) as verify:
        verify.verify()
    digest=hashlib.sha256(output.read_bytes()).hexdigest()
    report={"terrain_tiles":168,"tier_px":size,"color_mode":"RGB8","quantization":False,
            "atlas_size":[aw,ah],"atlas_bytes":output.stat().st_size,
            "sha256":digest,"mixed_atlas_bytes":mix_output.stat().st_size,
            "mixed_atlas_sha256":hashlib.sha256(mix_output.read_bytes()).hexdigest(),
            "asset_mapping":mappings}
    (dest/f"terrain_{size}_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    return report


def blend_terrain(atlas, assets, size):
    """Full-color deterministic high-res material transition; never quantizes RGB."""
    from PIL import ImageChops, ImageStat
    from math import pi, sin
    factor=size/BASE_SIZE
    cell=size+int(4*factor)
    gutter=int(GUTTER_BASE*factor)
    pairs={"grass":"dirt","forest":"dirt","dirt":"grass","rock":"forest"}
    strengths={"grass":0.32,"forest":0.29,"dirt":0.28,"rock":0.23}
    src=atlas.copy()
    result=atlas.copy()
    families={}
    for a in assets:
        families.setdefault(a["family"],[]).append(a)
    def pos(a):
        u,v=a["uv_rect"][:2]
        col=round((float(u)*1848-2)/132)
        row=round((float(v)*1584-2)/132)
        return (col*cell+gutter,row*cell+gutter)
    mask=Image.new("L",(BASE_SIZE,BASE_SIZE))
    px=mask.load()
    # Periodic, smooth, source independent alpha field.
    for y in range(BASE_SIZE):
        for x in range(BASE_SIZE):
            u,v=x/BASE_SIZE,y/BASE_SIZE
            val=0.5+0.22*sin(2*pi*u)+0.19*sin(2*pi*v)+0.09*sin(2*pi*(u+v))
            px[x,y]=round(255*max(0,min(1,val)))
    if size != BASE_SIZE:
        mask=mask.resize((size,size),Image.Resampling.BICUBIC)
    for a in assets:
        family=a["family"]
        if family not in pairs:
            continue
        x,y=pos(a)
        other=families[pairs[family]][(round((x-gutter)/cell)*19+round((y-gutter)/cell)*23)%len(families[pairs[family]])]
        ox,oy=pos(other)
        first=src.crop((x,y,x+size,y+size))
        second=src.crop((ox,oy,ox+size,oy+size))
        m=ImageChops.offset(mask, (x*17+y*13)%size, (y*29+x*7)%size)
        alpha=m.point(lambda z: min(255,round(z*strengths[family])))
        out=Image.composite(second,first,alpha)
        result.paste(out,(x,y))
        if gutter:
            result.paste(out.crop((0,0,1,size)).resize((gutter,size)),(x-gutter,y))
            result.paste(out.crop((size-1,0,size,size)).resize((gutter,size)),(x+size,y))
            result.paste(out.crop((0,0,size,1)).resize((size,gutter)),(x,y-gutter))
            result.paste(out.crop((0,size-1,size,size)).resize((size,gutter)),(x,y+size))
            for xx,sx in ((x-gutter,0),(x+size,size-1)):
                for yy,sy in ((y-gutter,0),(y+size,size-1)):
                    result.paste(out.crop((sx,sy,sx+1,sy+1)).resize((gutter,gutter)),(xx,yy))
    return result

def build_objects(src_atlas,dest):
    img=Image.open(src_atlas).convert("RGBA")
    if img.size!=(4096,4096):
        raise ValueError(f"Object master atlas must be 4096 square: {img.size}")
    dest.mkdir(parents=True,exist_ok=True)
    report={}
    for s in (512,384,256):
        obj=img if s==512 else img.resize((s*8,s*8),Image.Resampling.LANCZOS)
        path=dest/f"atlas_objects_{s}.png"
        obj.save(path,optimize=True)
        with Image.open(path) as check:
            check.verify()
        report[str(s)]={"size":[s*8,s*8],"bytes":path.stat().st_size,
                        "sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
    (dest/"objects_quality_report.json").write_text(json.dumps(report,indent=2))
    return report

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--manifest",type=Path,help="Canonical 228-asset manifest.json")
    ap.add_argument("--sources",type=Path,default=Path("."))
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--objects-atlas",type=Path)
    args=ap.parse_args()
    if args.manifest:
        manifest=json.loads(args.manifest.read_text())
        for s in (384,256,128):
            print(json.dumps(build(manifest,args.sources,args.output,s),ensure_ascii=False)[:250])
    if args.objects_atlas:
        print(build_objects(args.objects_atlas,args.output))
    if not args.manifest and not args.objects_atlas:
        ap.error("Specify --manifest and/or --objects-atlas")

if __name__=="__main__":
    main()
