#!/usr/bin/env python3
"""Build deterministic, precomposited 25D tree/object + ground-shadow atlases.

Input: user-authored source PNGs already in game/love/assets/terrain25d.
Output: 8 independent 3-hour atlas PNGs and a lookup manifest.
This is an OFFLINE asset build; there is no frame-time shadow geometry.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageChops

HOURS = tuple(range(0, 24, 3))
CELL = 512
COLS = 4
PIVOT = (256, 400)
TREE = {"oak", "broadleaf", "conifer", "dead_tree"}

def sun(hour):
    arc = (hour - 6) / 12
    daylight = max(0, min(1, math.sin(arc * math.pi)))
    angle = -math.pi * .65 + arc * math.pi * 1.3
    wx, wy = -math.cos(angle), -math.sin(angle)
    sx, sy = (wx-wy) / math.sqrt(2), (wx+wy) / (2*math.sqrt(2))
    magnitude = math.hypot(sx, sy)
    sx, sy = sx/magnitude, sy/magnitude
    length = max(.32, min(2.65, .32+1.05*(1-daylight)/(daylight+.31)))
    cast = (.42+.58*daylight) if daylight>0 else 0
    return sx, sy, length, cast

def tile(source, family, hour):
    canvas = Image.new("RGBA", (CELL, CELL))
    px, py = PIVOT
    sx, sy, length, cast = sun(hour)
    if cast:
        # Source alpha produces the same silhouette identity as the live
        # renderer; project it to the ground using a compact transformed mask.
        alpha = source.getchannel("A")
        height = .74 if family in TREE else .45
        width = 125
        depth = max(12, int(125 * length * height * .65))
        flattened = alpha.resize((width, depth), Image.Resampling.BILINEAR)
        # Fixed sun direction within each atlas time slot.
        rotation = math.degrees(math.atan2(-sx, sy))
        rotated = flattened.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
        intensity = round(95 * cast)
        rotated = rotated.point(lambda v: (v * intensity) // 255)
        # Shadow extends away from the sprite's ground pivot.
        off_x = round(sx * depth * .42)
        off_y = round(sy * depth * .42)
        x = px - rotated.width//2 + off_x
        y = py - rotated.height//2 + off_y
        mask = Image.new("L", (CELL, CELL))
        mask.paste(rotated, (x, y))
        color = Image.new("RGBA", (CELL,CELL), (8, 12, 11, 255))
        canvas.paste(color, (0,0), mask)
    # Original authored PNG stays unchanged and above its own shadow.
    canvas.alpha_composite(source, (px-64, py-124))
    return canvas

def build(root, output):
    manifest=json.loads((root/"manifest.json").read_text())
    objects=sorted((a for a in manifest["assets"] if a["kind"]=="object"),
                   key=lambda a:a["id"])
    if not objects:
        raise ValueError("no authored objects")
    page_by_name={p["filename"]:p for p in manifest["atlas_pages"]}
    source_by_page={}
    results=[]
    output.mkdir(parents=True,exist_ok=True)
    for a in objects:
        page=page_by_name[a["atlas_page"]]
        refs=page.get("sources", [])
        if not refs:
            raise ValueError("missing source mapping for "+a["id"])
        u=a["uv_rect"]
        target_x=round(u[0]*page["width"])
        target_y=round(u[1]*page["height"])
        found=[s for s in refs if s["x"]==target_x and s["y"]==target_y]
        if len(found)!=1:
            raise ValueError("ambiguous source tile for "+a["id"])
        source=root/found[0]["path"]
        if not source.is_file():
            raise FileNotFoundError(source)
        im=Image.open(source).convert("RGBA")
        if im.size!=(128,128):
            raise ValueError("non-128px authored tile "+str(source))
        source_by_page[a["id"]]=im
    rows=math.ceil(len(objects)/COLS)
    for hour in HOURS:
        atlas=Image.new("RGBA",(COLS*CELL, rows*CELL))
        for i,a in enumerate(objects):
            part=tile(source_by_page[a["id"]],a["family"],hour)
            atlas.alpha_composite(part, ((i%COLS)*CELL,(i//COLS)*CELL))
        filename=f"objects_shadow_{hour:02d}.png"
        path=output/filename
        atlas.save(path, optimize=True)
        results.append({"hour":hour,"filename":filename,
                        "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    index={a["id"]:{"u":(i%COLS)*CELL,"v":(i//COLS)*CELL,
                     "width":CELL,"height":CELL,"pivot":list(PIVOT)}
           for i,a in enumerate(objects)}
    lookup={"version":1,"slot_hours":list(HOURS),"cell":CELL,
            "width":COLS*CELL,"height":rows*CELL,"pages":results,"objects":index}
    (output/"objects_shadow_manifest.json").write_text(
        json.dumps(lookup,sort_keys=True,indent=2)+"\n")
    return lookup

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",type=Path,default=Path("game/love/assets/terrain25d"))
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    out=build(args.source,args.output)
    print(f"TAMU_STATIC_SHADOW_ATLASES_OK slots={len(out['pages'])} objects={len(out['objects'])}")
