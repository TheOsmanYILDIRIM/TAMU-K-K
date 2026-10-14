from PIL import Image, ImageFilter
from pathlib import Path
import os,json,hashlib,zipfile
root=Path('rendered/mixamo_full32_4dir')
direction=os.environ.get('DIRECTION','SE')
assert direction in ('NE','NW','SE','SW')
P=root/direction
files=[]
for n in range(1,33):
 name=f'frame_{n:02d}.png'
 source=Image.open(P/name).convert('RGBA')
 assert source.size==(1024,1024),(name,source.size)
 alpha=source.getchannel('A')
 bbox=alpha.getbbox()
 assert bbox,name
 protected=alpha.point(lambda a:255 if a>0 else 0).filter(ImageFilter.MaxFilter(17))
 overlay=Image.new('RGBA',source.size,(0,0,0,0))
 pixels=overlay.load();blocked=protected.load()
 w,h=source.size
 for y in range(0,h,48):
  for x in range(w):
   if not blocked[x,y]:pixels[x,y]=(255,0,255,255)
 for x in range(0,w,48):
  for y in range(h):
   if not blocked[x,y]:pixels[x,y]=(255,0,255,255)
 assert not any(a and b for a,b in zip(overlay.getchannel('A').tobytes(),protected.tobytes()))
 Image.alpha_composite(source,overlay).save(P/name)
 files.append({'file':f'{direction}/{name}','frame':n,'source_fbx_frame':n,'bounds':list(bbox),
 'sha256':hashlib.sha256((P/name).read_bytes()).hexdigest()})
manifest=json.loads((P/'render_manifest.json').read_text())
manifest.update({'direction':direction,'grid_color':'#FF00FF','grid_spacing_px':48,
 'grid_alpha_clearance_px':8,'frames':files,'total_frames':32,'frame_alignment':'fixed Blender camera, no independent frame alignment'})
(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('DIRECTION_32_GRID_VERIFIED',direction,len(files))
