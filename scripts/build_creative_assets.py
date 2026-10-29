#!/usr/bin/env python3
"""Compact 34-view atlas from the canonical Lua part catalog and fixed stair art."""
import argparse,hashlib,json,tempfile
from pathlib import Path
from PIL import Image
from building_default_assets import build as produce_76
DIRECTIONS=('south','west','north','east')
OMNI={'foundation','floor','post','roof_flat'}
DUAL={'railing','fence','fence_gate'}

def generate(destination,catalog,repo=Path('.')):
 destination=Path(destination);destination.mkdir(parents=True,exist_ok=True)
 definitions=catalog.get('definitions',catalog)
 with tempfile.TemporaryDirectory() as temp:
  base=Path(temp)
  original=produce_76(catalog,base)
  refs={(e['def_id'],e['rotation']):e for e in original['entries']}
  ids=sorted(k for k in definitions if k.endswith('_wood'))
  assert len(ids)==13,'13 canonical wood definitions required'
  sources=[]
  for def_id in ids:
   shape=definitions[def_id]['visual']['shape']
   rotations=(0,) if shape in OMNI else (0,1) if shape in DUAL else (0,1,2,3)
   for r in rotations:
    src=refs[def_id,r]
    im=Image.open(base/'sprites'/src['filename']).convert('RGBA')
    if shape=='stairs':
     # Replace incomplete legacy geometry with four solid 3D stair models.
     fixed=Path(repo)/'game/love/assets'/('creative_stairs_'+DIRECTIONS[r]+'.png')
     im=Image.open(fixed).convert('RGBA')
    colors={p[:3] for p in im.get_flattened_data() if p[3]>0}
    assert im.size==(128,128) and len(colors)<=64
    sources.append((def_id,r,shape,im,len(colors)))
  assert len(sources)==34
  atlas=Image.new('RGBA',(1024,640),(0,0,0,0));entries=[]
  for index,(def_id,r,shape,im,count) in enumerate(sources):
   x,y=(index%8)*128,(index//8)*128
   atlas.alpha_composite(im,(x,y))
   entries.append({'def_id':def_id,'rotation':r,'direction':DIRECTIONS[r],
                   'shape':shape,'atlas_rect':[x,y,128,128],
                   'colors':count,'anchor':[64,92]})
  atlas_path=destination/'creative_build_atlas.png';atlas.save(atlas_path,optimize=True)
  meta={'schema_version':1,'canvas':[128,128],'max_visible_rgb_colors':64,
        'anchor':[64,92],'iso_pixels_per_unit':2,
        'atlas':{'filename':atlas_path.name,'size':[1024,640],
          'sha256':hashlib.sha256(atlas_path.read_bytes()).hexdigest()},
        'entries':entries,'source':'deterministic 34-view subset of 19 canonical defs with solid stairs'}
  (destination/'creative_build_manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
  print('TAMU_CREATIVE_ATLAS_OK 13 types 34 views sha='+meta['atlas']['sha256'])
  return meta
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True)
 p.add_argument('--repo',type=Path,default=Path('.'))
 p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();generate(a.output,json.loads(a.catalog.read_text('utf-8')),a.repo)
