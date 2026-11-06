#!/usr/bin/env python3
"""Offline construction/terrain 2.5D geometry snapshot. No Godot/PCK/APK."""
import argparse
from math import sqrt
from pathlib import Path

X = 1 / sqrt(2)
Y = X / 2
PIVOT = (64, 92)
NATIVE_SCALE = 0.5

def project(x, y, z=0, ground=0):
    return ((x-y)*X, (x+y)*Y - z - ground*0.35)

def polygon(points, ox, oy, factor=4):
    return " ".join(f"{ox+factor*project(*p)[0]:.3f},{oy+factor*project(*p)[1]:.3f}" for p in points)

def draw(foundation, ground, ox, oy):
    a,b,c,d = (-16,-16), (16,-16), (16,16), (-16,16)
    base=[(x,y,0,ground) for x,y in (a,b,c,d)]
    top=[(x,y,4,ground) for x,y in (a,b,c,d)]
    return (f'<polygon points="{polygon(base,ox,oy)}" fill="#6a966f" stroke="#e8d26f" stroke-width="2"/>'
            +f'<polygon points="{polygon([base[1],base[2],top[2],top[1]],ox,oy)}" fill="#866041"/>'
            +f'<polygon points="{polygon([base[2],base[3],top[3],top[2]],ox,oy)}" fill="#a77b53"/>'
            +f'<polygon points="{polygon(top,ox,oy)}" fill="#d6a16b" stroke="#5e4736" stroke-width="2"/>')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output",type=Path,default=Path("building_alignment_quickcheck.svg"))
    ap.add_argument("--terrain-height",type=float,default=12.0)
    args=ap.parse_args()
    h=args.terrain_height
    assert NATIVE_SCALE == 1/2
    assert PIVOT == (64,92)
    assert abs(project(32,0,4,h)[1]-(32*Y-4-h*0.35))<1e-9
    assert abs(project(0,0,0,h)[1] + h*0.35)<1e-9
    # This SVG is geometry-only; it is never an actual Godot screenshot.
    svg=('<svg xmlns="http://www.w3.org/2000/svg" width="700" height="490" viewBox="0 0 700 490">'
        '<rect width="700" height="490" fill="#182024"/>'
        '<text x="25" y="38" fill="white" font-size="21">TAMU construction / terrain quickcheck</text>'
        '<text x="25" y="66" fill="#c6d6d0" font-size="14">Synthetic terrain, native 0.7071 / 0.3536 projection, no PCK</text>'
        +draw(True,h,350,260)
        +f'<text x="25" y="448" fill="#eacb94" font-size="16">Terrain height={h:g}, building base z=0, top z=4</text>'
        '</svg>')
    args.output.write_text(svg,encoding="utf-8")
    print(f"TAMU_BUILDING_VISUAL_QUICKCHECK_OK {args.output}")
if __name__=="__main__":
    main()
