#!/usr/bin/env python3
"""Build TAMU's editable, deterministic 128x128/<=64-color isometric default kit.

Canonical input is exported from game/love/systems/building_parts.lua by
scripts/export_building_parts.lua. Geometry is computed, never cropped from art.
Every view shares world-space 32-unit sockets and a pixel pivot (64,92).
No prompts, user pictures, 3rd-party textures or GPU work are involved.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 128
SUPERSAMPLE = 3
PIVOT = (64, 92)
PPU = 2.0
CELL = 32
DIRECTIONS = ('south', 'west', 'north', 'east')
# No global randomness; all facets and line rhythm are deterministic.
WOOD = {'top': (164, 113, 70), 'light': (193, 143, 94),
        'face_x': (116, 74, 48), 'face_y': (137, 89, 55),
        'line': (76, 47, 34), 'nail': (70, 60, 50)}
STONE = {'top': (154, 151, 137), 'light': (188, 180, 161),
         'face_x': (91, 92, 87), 'face_y': (115, 111, 99),
         'line': (69, 70, 66), 'nail': (73, 72, 67)}
ROOF = {'top': (116, 97, 83), 'light': (151, 128, 110),
        'face_x': (77, 64, 60), 'face_y': (91, 77, 67),
        'line': (55, 50, 47), 'nail': (66, 60, 53)}


def rot(x, y, r):
    return ((x, y), (-y, x), (-x, -y), (y, -x))[r]


def iso(x, y, z, r=0):
    x, y = rot(x, y, r)
    return (PIVOT[0] + (x - y) / math.sqrt(2) * PPU,
            PIVOT[1] + ((x + y) / (2 * math.sqrt(2)) - z) * PPU)


class Painter:
    def __init__(self, rotation):
        self.rotation = rotation
        self.im = Image.new('RGBA', (SIZE*SUPERSAMPLE, SIZE*SUPERSAMPLE), (0, 0, 0, 0))
        self.dr = ImageDraw.Draw(self.im)

    def pts(self, coords):
        return [(round(sx*SUPERSAMPLE), round(sy*SUPERSAMPLE))
                for sx, sy in (iso(*v, self.rotation) for v in coords)]

    def polygon(self, coords, fill, outline=None, width=0):
        pts = self.pts(coords)
        self.dr.polygon(pts, fill=fill)
        if outline:
            self.dr.line(pts+[pts[0]], fill=outline, width=max(1, int(width*SUPERSAMPLE)), joint='curve')

    def line(self, coords, fill, width=0.6):
        self.dr.line(self.pts(coords), fill=fill,
                     width=max(1, round(width*SUPERSAMPLE)), joint='curve')

    def block(self, x1, x2, y1, y2, z1, z2, palette, surface=None, rhythm='none'):
        # Camera sees WORLD +X and +Y faces, independently of the part's
        # orientation. Rotate local face normals BEFORE selecting the visible
        # side. The old code always painted local +X/+Y; 180-degree walls
        # showed their hidden face through the silhouette.
        r=self.rotation
        xf=x2 if r in (0,1) else x1
        yf=y2 if r in (0,3) else y1
        xcolor='face_x' if r%2==0 else 'face_y'
        ycolor='face_y' if r%2==0 else 'face_x'
        sides=[
            ([(xf,y1,z1),(xf,y2,z1),(xf,y2,z2),(xf,y1,z2)],xcolor),
            ([(x1,yf,z1),(x2,yf,z1),(x2,yf,z2),(x1,yf,z2)],ycolor)
        ]
        for face,key in sides:
            self.polygon(face,palette[key],palette['line'],0.35)
        if rhythm == 'stone':
            for z in range(math.ceil(z1)+4, math.ceil(z2),4):
                if z>=z2: break
                self.line([(xf,y1,z),(xf,y2,z)],palette['line'],0.5)
                self.line([(x1,yf,z),(x2,yf,z)],palette['line'],0.5)
            for x in range(math.ceil(x1)+8, math.ceil(x2),8):
                self.line([(x,yf,z1),(x,yf,z2)],palette['line'],0.35)
            for y in range(math.ceil(y1)+8, math.ceil(y2),8):
                self.line([(xf,y,z1),(xf,y,z2)],palette['line'],0.35)
        top_palette = surface or palette
        self.polygon([(x1,y1,z2),(x2,y1,z2),(x2,y2,z2),(x1,y2,z2)],
                     top_palette['top'],palette['line'],0.4)
        if rhythm=='plank':
            # Identical world-period phase across all 32-unit neighbors.
            for y in range(math.ceil(y1 / 4)*4,math.floor(y2/4)*4+1,4):
                if y1 < y < y2:
                    self.line([(x1,y,z2+0.02),(x2,y,z2+0.02)],palette['line'],0.55)
            for x in range(math.ceil(x1/16)*16,math.floor(x2/16)*16+1,16):
                if x1<x<x2:
                    # Subtle stagger; uses no per-sprite random state.
                    self.line([(x,y1+4,z2+0.02),(x,y1+8,z2+0.02)],palette['face_y'],0.4)
        if rhythm=='stone':
            for x in range(math.ceil(x1/8)*8,math.floor(x2/8)*8+1,8):
                if x1<x<x2:
                    self.line([(x,y1,z2+0.02),(x,y2,z2+0.02)],palette['face_y'],0.4)
            for y in range(math.ceil(y1/8)*8,math.floor(y2/8)*8+1,8):
                if y1<y<y2:
                    self.line([(x1,y,z2+0.02),(x2,y,z2+0.02)],palette['face_y'],0.4)

    def finish(self):
        # Premultiplied alpha resampling prevents black RGB bleed around edges.
        resized = self.im.convert('RGBa').resize((SIZE,SIZE),Image.Resampling.LANCZOS).convert('RGBA')
        alpha = resized.getchannel('A')
        # Dither-free palette of at most 63 RGB values (transparency is separate).
        rgb = resized.convert('RGB').quantize(colors=63,method=Image.Quantize.FASTOCTREE,
                                             dither=Image.Dither.NONE).convert('RGB')
        out = Image.merge('RGBA', (*rgb.split(),alpha))
        # Fully transparent texels must not hold hidden decorative colors.
        px = out.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if px[x,y][3]==0: px[x,y]=(0,0,0,0)
        return out


def wall(p,kind,material,height=24):
    pal=WOOD if material=='wood' else STONE
    # Opening silhouettes are actual transparent gaps, not painted black.
    if kind=='doorway':
        p.block(-16,-12,-1,1,0,height,pal,rhythm='stone' if material=='stone' else 'none')
        p.block(12,16,-1,1,0,height,pal,rhythm='stone' if material=='stone' else 'none')
        p.block(-12,12,-1,1,height-5,height,pal,rhythm='stone' if material=='stone' else 'none')
        return
    if kind=='window':
        p.block(-16,16,-1,1,0,7,pal,rhythm='stone' if material=='stone' else 'none')
        p.block(-16,-11,-1,1,7,18,pal,rhythm='stone' if material=='stone' else 'none')
        p.block(11,16,-1,1,7,18,pal,rhythm='stone' if material=='stone' else 'none')
        p.block(-16,16,-1,1,18,height,pal,rhythm='stone' if material=='stone' else 'none')
        p.block(-12,12,-1.3,1.3,7,8,pal)
        return
    if kind in ('railing','fence','fence_gate'):
        height=12
        if kind=='fence_gate':
            p.block(-16,-13,-1.3,1.3,0,height,pal)
            p.block(13,16,-1.3,1.3,0,height,pal)
            p.block(-11,11,-0.7,0.7,2,10,pal)
            p.line([(-11,1,2),(11,1,10)],pal['light'],0.8)
        else:
            for xx in (-15,15):
                p.block(xx-1.4,xx+1.4,-1.3,1.3,0,height,pal)
            for zz in (4,9):
                p.block(-15,15,-1.0,1.0,zz,zz+1.3,pal)
            if kind=='railing':
                p.block(-15,15,-1.6,1.6,11,12,pal)
        return
    p.block(-16,16,-1,1,0,height,pal,
            rhythm='stone' if material=='stone' else 'none')
    if material=='wood':
        # The visible external face changes when the wall turns. 180-degree
        # back-facing panels must not bleed front detail through the timber.
        face=1.04 if p.rotation in (0,3) else -1.04
        for xx in (-10,-2,6,14):
            p.line([(xx,face,1),(xx,face,height-1)],pal['line'],0.55)
        for zz in (2,height-2):
            p.line([(-15,face,zz),(15,face,zz)],pal['light'],0.6)


def slope(p,material,height=12):
    pal=ROOF if material=='wood' else STONE
    x1,x2,y1,y2=-16,16,-16,16
    # A roof part is the COVERING, not a solid triangular gable wall.
    # Only the visible thin fascia is drawn at whichever x-edge faces the
    # camera. Gable infill belongs to another structural piece.
    face_x=x2 if p.rotation in (0,1) else x1
    p.polygon([(face_x,y1,height),(face_x,y2,0),
               (face_x,y2,-0.7),(face_x,y1,height-0.7)],
              pal['face_x'],pal['line'],0.4)
    if p.rotation in (0,3):
        p.polygon([(x1,y2,0),(x2,y2,0),(x2,y2,-0.7),(x1,y2,-0.7)],
                  pal['face_y'])
    p.polygon([(x1,y1,height),(x2,y1,height),(x2,y2,0),(x1,y2,0)],
              pal['top'],pal['line'],0.6)
    for yy in range(-12,16,4):
        zz=height*(16-yy)/32
        p.line([(x1,yy,zz+0.04),(x2,yy,zz+0.04)],
               pal['line'],0.55)
    for xx in (-8,0,8):
        p.line([(xx,y1,height+0.02),(xx,y2,0.02)],
               pal['face_y'],0.4)


def stairs(p,material):
    pal=WOOD if material=='wood' else STONE
    # Back steps first, then lower front steps; each tread fits the 32x32 footprint.
    for i in range(6):
        y1=-16+i*(32/6)
        y2=-16+(i+1)*(32/6)
        z2=24-i*4
        p.block(-15,15,y1,y2,0,z2,pal,rhythm='plank')


def render(definition,rotation):
    kind=definition['visual']['shape']
    material=definition['visual']['material']
    pal=WOOD if material=='wood' else STONE
    p=Painter(rotation)
    if kind=='foundation':
        p.block(-16,16,-16,16,0,4,STONE,surface=pal,
                rhythm='stone' if material=='stone' else 'plank')
    elif kind=='floor':
        p.block(-16,16,-16,16,0,2,pal,
                rhythm='plank' if material=='wood' else 'stone')
    elif kind in ('wall','window','doorway','halfwall','railing','fence','fence_gate'):
        wall(p,kind,material,12 if kind in ('halfwall','railing','fence','fence_gate') else 24)
    elif kind=='post':
        p.block(-1.5,1.5,-1.5,1.5,0,24,pal)
        p.block(-2.2,2.2,-2.2,2.2,22,24,pal)
    elif kind=='roof_flat':
        p.block(-16,16,-16,16,0,2,ROOF,rhythm='plank')
    elif kind=='roof_slope':
        slope(p,material)
    elif kind=='stairs':
        stairs(p,material)
    else:
        raise ValueError('undefined building shape: '+repr(kind))
    return p.finish()


def rgba_colors(image):
    return len({pixel[:3] for pixel in image.get_flattened_data() if pixel[3]>0})


def compose(elements, name, output, zoom=3):
    """Proven world-projected assembly from distinct sprites, not one stretched tile."""
    W,H=740,580
    center=(W//2,H//2+36)
    out=Image.new('RGBA',(W,H),(0,0,0,0))
    # Stable front-to-back order using projected world-center depth.
    sorted_items=sorted(elements,key=lambda e:(e[1]+e[2],e[1],e[2]))
    positions=[]
    for file,x,y,z in sorted_items:
        img=Image.open(file).convert('RGBA')
        w=round(SIZE*zoom)
        img=img.resize((w,w),Image.Resampling.NEAREST)
        px,py=iso(x,y,z)
        sx,sy=(center[0]+round((px-PIVOT[0])*zoom),
               center[1]+round((py-PIVOT[1])*zoom))
        left,top=sx-round(PIVOT[0]*zoom),sy-round(PIVOT[1]*zoom)
        out.alpha_composite(img,(left,top))
        positions.append({'file':file.name,'world':[x,y,z],'pixel_origin':[sx,sy]})
    out.save(output)
    return positions


def contact_sheet(entries, sprites, output):
    from PIL import ImageFont
    cellw,cellh=177,176
    cols=8
    rows=math.ceil(len(entries)/cols)
    im=Image.new('RGB',(cols*cellw,rows*cellh),(24,28,30))
    draw=ImageDraw.Draw(im)
    for i,e in enumerate(entries):
        x,y=(i%cols)*cellw,(i//cols)*cellh
        im.paste((36,40,42),(x+3,y+3,x+cellw-3,y+cellh-3))
        sprite=sprites[e['filename']]
        # Checker background is for REVIEW ONLY, never in saved sprite RGBA.
        bg=Image.new('RGBA',(128,128),(45,50,52,255))
        bg.alpha_composite(sprite)
        im.paste(bg.convert('RGB'),(x+24,y+3))
        label=f"{e['def_id'].replace('tamu:','')} / {e['direction']}"
        draw.text((x+8,y+135),label,fill=(224,219,209))
    im.save(output)


def build(catalog,outdir):
    defs=catalog.get('definitions') or catalog
    if not isinstance(defs,dict) or len(defs)!=19:
        raise ValueError(f'expected 19 canonical building definitions; got {len(defs)}')
    outdir.mkdir(parents=True,exist_ok=True)
    sprites_path=outdir/'sprites'
    sprites_path.mkdir(exist_ok=True)
    entries=[]
    sprites={}
    ids=sorted(defs)
    for id in ids:
        defn=defs[id]
        if defn['id']!=id or defn['rotation_steps']!=4:
            raise ValueError('invalid source definition '+id)
        for rotation,direction in enumerate(DIRECTIONS):
            filename=id.replace(':','_')+'_'+direction+'.png'
            im=render(defn,rotation)
            colors=rgba_colors(im)
            if im.mode!='RGBA' or im.size!=(128,128) or colors>64:
                raise AssertionError(f'sprite contract failed: {filename} {colors}')
            if not any(p[3]==0 for p in im.get_flattened_data()) or not any(p[3]>0 for p in im.get_flattened_data()):
                raise AssertionError(f'alpha missing: {filename}')
            dest=sprites_path/filename
            im.save(dest,optimize=True)
            sprites[filename]=im
            index=len(entries)
            entries.append({'def_id':id,'rotation':rotation,'direction':direction,
                'filename':filename,'atlas_rect':[(index%8)*SIZE,(index//8)*SIZE,SIZE,SIZE],
                'anchor':list(PIVOT),'colors':colors,
                'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
                'kind':defn['visual']['shape'],'material':defn['visual']['material']})
    atlas=Image.new('RGBA',(8*SIZE,math.ceil(len(entries)/8)*SIZE),(0,0,0,0))
    for e in entries:
        rect=e['atlas_rect']
        atlas.paste(sprites[e['filename']],(rect[0],rect[1]))
    atlas_path=outdir/'building_default_atlas.png'
    atlas.save(atlas_path,optimize=True)
    # Never draw outlines/trims into the four inner boundaries: adjacent
    # foundations use the same source tiles and the world projection below.
    fname='tamu_foundation_wood_south.png'
    tile=sprites_path/fname
    assemblies={}
    assembly_coords=[(tile,0,0,0),(tile,32,0,0),(tile,0,32,0),(tile,32,32,0)]
    assemblies['2x2']=compose(assembly_coords,'2x2',outdir/'foundation_2x2.png')
    l_coords=[(tile,0,0,0),(tile,32,0,0),(tile,0,32,0)]
    assemblies['L']=compose(l_coords,'L',outdir/'foundation_L.png')
    sheet=outdir/'all_76_views.png'
    contact_sheet(entries,sprites,sheet)
    canonical=json.dumps(defs,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
    atlas_sha=hashlib.sha256(atlas_path.read_bytes()).hexdigest()
    manifest={
      'schema_version':1,'generator':'tamu-building-default-polygon-v1',
      'asset_status':'procedural_placeholder',
      'definition_sha256':hashlib.sha256(canonical).hexdigest(),
      'canvas':[SIZE,SIZE],'max_visible_rgb_colors':64,
      'anchor':list(PIVOT),'world_unit':CELL,'iso_pixels_per_unit':PPU,
      'directions':list(DIRECTIONS),
      'atlas':{'filename':atlas_path.name,'size':list(atlas.size),'sha256':atlas_sha},
      'entries':entries,'assembly_2x2':assemblies['2x2'],
      'assembly_L':assemblies['L'],
      'note':'Geometric code-only defaults; no original art, prompt or approved production textures.'
    }
    (outdir/'building_default_manifest.json').write_text(
       json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return manifest


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--catalog',required=True,type=Path,
                    help='JSON exported from canonical Lua Parts.all()')
    ap.add_argument('--output',required=True,type=Path)
    args=ap.parse_args()
    manifest=build(json.loads(args.catalog.read_text('utf-8')),args.output)
    print(f"BUILDING_DEFAULT_ASSETS_OK defs=19 sprites={len(manifest['entries'])} "
          f"atlas={manifest['atlas']['size']} sha={manifest['atlas']['sha256']}")

if __name__=='__main__': main()
