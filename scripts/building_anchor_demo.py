#!/usr/bin/env python3
"""Create a proof with six matched roof/wall lines, not image-driven crop guessing."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw
from building_anchor_contract import house_2x2_plan, to_manifest, screen, Point
from building_default_assets import render as render_default, Painter, WOOD, PIVOT, SIZE

def render_shape(kind, rotation):
    if kind in ('gable_up','gable_down'):
        p=Painter(rotation)
        tri=([(0,-16,0),(0,16,0),(0,16,12)] if kind=='gable_up'
             else [(0,-16,0),(0,16,0),(0,-16,12)])
        p.polygon(tri,WOOD['face_y'],WOOD['line'],0.65)
        p.line([tri[0],tri[1]],WOOD['light'],0.7)
        return p.finish()
    return render_default({'visual':{'shape':kind,'material':'wood'}},rotation)


ZOOM = 3
W,H = 1040,790
CENTER = (520,490)


def pos2d(point):
    x,y=screen(point)
    return (round(CENTER[0]+(x-PIVOT[0])*ZOOM),
            round(CENTER[1]+(y-PIVOT[1])*ZOOM))


def assemble(pieces, dest, overlay=False):
    image=Image.new('RGBA',(W,H),(0,0,0,0))
    # Cache one source for each geometric category / rotation.
    cache={}
    # Distinct sources are physically placed at each instance's own world coords.
    for p in sorted(pieces,key=lambda q:(q['layer'],q['x']+q['y'],q['x'],q['y'])):
        key=(p['kind'],p['rotation'])
        if key not in cache:
            cache[key]=render_shape(*key).resize((SIZE*ZOOM,SIZE*ZOOM),Image.Resampling.NEAREST)
        sx,sy=pos2d(Point(p['x'],p['y'],p['z']))
        left=sx-PIVOT[0]*ZOOM
        top=sy-PIVOT[1]*ZOOM
        image.alpha_composite(cache[key],(left,top))
    if overlay:
        plan=house_2x2_plan()
        dr=ImageDraw.Draw(image)
        for e in plan['wall_top']:
            a,b=pos2d(e.a),pos2d(e.b)
            dr.line([a,b],fill=(0,230,160,255),width=4)
            for q in [a,b]:dr.ellipse([q[0]-5,q[1]-5,q[0]+5,q[1]+5],fill=(250,235,100,255),outline=(10,20,22,255),width=1)
        for e in plan['ridge'][::2]:
            a,b=pos2d(e.a),pos2d(e.b)
            dr.line([a,b],fill=(255,110,85,255),width=4)
            for q in [a,b]: dr.ellipse([q[0]-5,q[1]-5,q[0]+5,q[1]+5],fill=(255,190,145,255))
        dr.rectangle((14,14,590,92),fill=(20,26,31,234))
        dr.text((26,24),'TAMU KOK | ANKRAJ KONTROLU', fill=(238,238,222,255))
        dr.text((26,46),'YESIL: Cati sacagi = duvar ust cizgisi (z=30)',fill=(103,240,181,255))
        dr.text((26,68),'TURUNCU: 2 cati paneli = ortak mahya (z=42)',fill=(255,169,132,255))
    image.save(dest)
    return {'output':dest.name,'instances':len(pieces),'views_cached':len(cache)}


def make_review(output):
    plan=house_2x2_plan()
    output.mkdir(parents=True,exist_ok=True)
    stages={
        '01_foundation': [p for p in plan['pieces'] if p['layer']<=1],
        '02_walls': [p for p in plan['pieces'] if p['layer']<=2],
        '03_roof':plan['pieces']
    }
    records=[]
    for name,pieces in stages.items():
        records.append(assemble(pieces,output/(name+'.png')))
    records.append(assemble(plan['pieces'],output/'04_anchor_overlay.png',overlay=True))
    # A four-panel side-by-side technical review — the PNGs above stay separately available.
    strip=Image.new('RGB',(4*480,480),(22,27,30))
    dr=ImageDraw.Draw(strip)
    names=[('01_foundation','TEMEL + ZEMIN'),('02_walls','DUVAR KABUGU'),
           ('03_roof','CATI + DUVAR'),('04_anchor_overlay','ESLESTIRME CIZGILERI')]
    for i,(name,label) in enumerate(names):
        src=Image.open(output/(name+'.png')).convert('RGBA')
        box=Image.new('RGBA',src.size,(27,34,37,255))
        box.alpha_composite(src)
        # no resizing of source sprite assets, only presentation.
        scale=min(470/box.width,445/box.height)
        thumb=box.resize((int(box.width*scale),int(box.height*scale)),Image.Resampling.LANCZOS)
        x=i*480+(480-thumb.width)//2
        y=32+(448-thumb.height)//2
        strip.paste(thumb.convert('RGB'),(x,y))
        dr.text((i*480+14,10),label,fill=(235,237,222))
    strip.save(output/'05_comparison_strip.png')
    meta=to_manifest(plan)
    meta['preview_records']=records
    (output/'house_anchor_manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return meta

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=Path('/mnt/data/TAMU_Anchor_Alignment'))
    args=parser.parse_args()
    m=make_review(args.output)
    print(json.dumps({'pieces':len(m['pieces']),'matched_lines':len(m['matches']),
                      'all_errors':[r['error_world'] for r in m['matches']],
                      'output':str(args.output)}))
