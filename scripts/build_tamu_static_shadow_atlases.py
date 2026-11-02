#!/usr/bin/env python3
"""Offline 32x32 alpha-derived shadow masks from the authored RGBA atlas.

Eight fixed three-hour pages; source object RGBA atlas is never modified.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

HOURS=tuple(range(0,24,3))
CELL=32
COLS=8

def solar(hour):
    arc=(hour-6)/12
    daylight=max(0,min(1,math.sin(arc*math.pi)))
    az=-math.pi*.65+arc*math.pi*1.3
    wx,wy=-math.cos(az),-math.sin(az)
    sx,sy=(wx-wy)/math.sqrt(2),(wx+wy)/(2*math.sqrt(2))
    mag=math.hypot(sx,sy)
    return sx/mag,sy/mag,max(.32,min(2.65,.32+1.05*(1-daylight)/(daylight+.31))),(.42+.58*daylight) if daylight else 0

def mask_for(source,family,hour):
    sx,sy,length,cast=solar(hour)
    tile=Image.new("RGBA",(CELL,CELL))
    if cast==0:
        return tile
    # The mask starts with the REAL variant alpha; never substitute an ellipse.
    alpha=source.getchannel("A").resize((32,32),Image.Resampling.BOX)
    is_tree=family in ("oak","broadleaf","conifer","dead_tree")
    width=18 if is_tree else 12
    depth=min(27,max(5,round(12*length*(1 if is_tree else .65))))
    projected=alpha.resize((width,depth),Image.Resampling.BILINEAR)
    angle=math.degrees(math.atan2(-sx,sy))
    projected=projected.rotate(angle,Image.Resampling.BILINEAR,expand=True)
    opacity=round(105*cast)
    projected=projected.point(lambda v:v*opacity//255)
    mask=Image.new("L",(CELL,CELL))
    # Shadow's pivot is (16,24); keep the foot contact near ground.
    dx=round(sx*min(8,depth*.27))
    dy=round(sy*min(5,depth*.2))
    mask.paste(projected,(16-projected.width//2+dx,24-projected.height//2+dy))
    tile.putalpha(mask)
    return tile

def build(root,output):
    manifest=json.loads((root/"manifest.json").read_text())
    assets=sorted((a for a in manifest["assets"] if a["kind"]=="object"),key=lambda a:a["id"])
    pages={p["filename"]:p for p in manifest["atlas_pages"]}
    sources={}
    for a in assets:
        p=pages[a["atlas_page"]]
        if p["filename"] not in sources:
            src=root/p["filename"]
            raw=src.read_bytes()
            if p.get("sha256"):
                assert hashlib.sha256(raw).hexdigest()==p["sha256"],src
            sources[p["filename"]]=Image.open(src).convert("RGBA")
    variants={}
    for a in assets:
        p=pages[a["atlas_page"]]
        x=round(a["uv_rect"][0]*p["width"])
        y=round(a["uv_rect"][1]*p["height"])
        w=round(a["uv_rect"][2]*p["width"])
        h=round(a["uv_rect"][3]*p["height"])
        assert (w,h)==(128,128),(a["id"],w,h)
        variants[a["id"]]=sources[a["atlas_page"]].crop((x,y,x+w,y+h))
    output.mkdir(parents=True,exist_ok=True)
    rows=math.ceil(len(assets)/COLS)
    entries={}
    for i,a in enumerate(assets):
        entries[a["id"]]={"u":(i%COLS)*CELL,"v":(i//COLS)*CELL}
    results=[]
    for hour in HOURS:
        atlas=Image.new("RGBA",(COLS*CELL,rows*CELL))
        for i,a in enumerate(assets):
            shadow=mask_for(variants[a["id"]],a["family"],hour)
            atlas.alpha_composite(shadow,((i%COLS)*CELL,(i//COLS)*CELL))
        name=f"shadows_{hour:02d}.png"
        dst=output/name
        atlas.save(dst,optimize=True)
        results.append({"hour":hour,"filename":name,"sha256":hashlib.sha256(dst.read_bytes()).hexdigest()})
    result={"version":3,"resolution":CELL,"width":COLS*CELL,"height":rows*CELL,
            "hours":list(HOURS),"pages":results,"objects":entries,"pivot":[16,24]}
    (output/"objects_shadow_manifest.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    return result

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--source",type=Path,default=Path("game/love/assets/terrain25d"))
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()
    m=build(a.source,a.output)
    print(f"TAMU_LOWRES_SHADOW_OK pages={len(m['pages'])} objects={len(m['objects'])}")
