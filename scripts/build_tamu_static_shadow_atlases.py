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
CELL = 256
SHADOW_RES = 32
COLS = 4
PIVOT = (128, 192)
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
        # Downsample shadow alpha to a strict 32x32 source mask FIRST.
        # Only the original RGBA object sprite retains full resolution.
        alpha = source.getchannel("A").resize((SHADOW_RES, SHADOW_RES),
                                                Image.Resampling.BOX)
        height = .74 if family in TREE else .45
        width = max(2, round(125 / CELL * SHADOW_RES))
        depth = max(2, round(125 * length * height * .65 / CELL * SHADOW_RES))
        flattened = alpha.resize((width, depth), Image.Resampling.BILINEAR)
        rotation = math.degrees(math.atan2(-sx, sy))
        rotated = flattened.rotate(rotation, resample=Image.Resampling.BILINEAR, expand=True)
        intensity = round(95 * cast)
        rotated = rotated.point(lambda v: (v * intensity) // 255)
        off_x = round(sx * depth * .42)
        off_y = round(sy * depth * .42)
        x = round(px / CELL * SHADOW_RES) - rotated.width//2 + off_x
        y = round(py / CELL * SHADOW_RES) - rotated.height//2 + off_y
        mask_low = Image.new("L", (SHADOW_RES, SHADOW_RES))
        mask_low.paste(rotated, (x, y))
        mask = mask_low.resize((CELL, CELL), Image.Resampling.BILINEAR)
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
    atlas_images={}
    results=[]
    output.mkdir(parents=True,exist_ok=True)
    for a in objects:
        page=page_by_name[a["atlas_page"]]
        if page["filename"] not in atlas_images:
            atlas_path=root/page["filename"]
            if not atlas_path.is_file():
                raise FileNotFoundError(atlas_path)
            atlas_images[page["filename"]]=Image.open(atlas_path).convert("RGBA")
        original=atlas_images[page["filename"]]
        u=a["uv_rect"]
        target_x=round(u[0]*page["width"])
        target_y=round(u[1]*page["height"])
        width=round(u[2]*page["width"])
        height=round(u[3]*page["height"])
        if width!=128 or height!=128:
            raise ValueError("non-128px object atlas cell "+a["id"])
        im=original.crop((target_x,target_y,target_x+width,target_y+height))
        if im.size!=(128,128):
            raise ValueError("invalid crop "+a["id"])
        source_by_page[a["id"]]=im
    pages=[]
    index={}
    for i,a in enumerate(objects):
        local=i%16
        index[a["id"]]={"u":(local%COLS)*CELL,"v":(local//COLS)*CELL,
                         "width":CELL,"height":CELL,"pivot":list(PIVOT),
                         "page":i//16}
    for hour in HOURS:
        for part in range(math.ceil(len(objects)/16)):
            subset=objects[part*16:(part+1)*16]
            rows=math.ceil(len(subset)/COLS)
            atlas=Image.new("RGBA",(COLS*CELL,rows*CELL))
            for i,a in enumerate(subset):
                atlas.alpha_composite(tile(source_by_page[a["id"]],a["family"],hour),
                                      ((i%COLS)*CELL,(i//COLS)*CELL))
            filename=f"objects_shadow_{hour:02d}_{part}.png"
            path=output/filename
            atlas.save(path,optimize=True)
            pages.append({"hour":hour,"part":part,"filename":filename,
                          "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    lookup={"version":2,"slot_hours":list(HOURS),"cell":CELL,"shadow_resolution":SHADOW_RES,
            "width":COLS*CELL,"height":COLS*CELL,"pages":pages,"objects":index}
    (output/"objects_shadow_manifest.json").write_text(
        json.dumps(lookup,sort_keys=True,indent=2)+"\n")
    return lookup

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",type=Path,default=Path("game/love/assets/terrain25d"))
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    out=build(args.source,args.output)
    print(f"TAMU_STATIC_SHADOW_ATLASES_OK pages={len(out['pages'])} objects={len(out['objects'])}")
