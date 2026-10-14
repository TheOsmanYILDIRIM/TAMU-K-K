from PIL import Image, ImageFilter
from pathlib import Path
import json,zipfile,hashlib
P=Path('rendered/mixamo_se_full_grid')
files=[]
for n in range(1,33):
 name=f'SE_{n:02d}.png'
 source=Image.open(P/name).convert('RGBA')
 alpha=source.getchannel('A')
 assert alpha.getbbox(),name
 protected=alpha.point(lambda a:255 if a>0 else 0).filter(ImageFilter.MaxFilter(17))
 overlay=Image.new('RGBA',source.size,(0,0,0,0))
 pixels=overlay.load();block=protected.load()
 w,h=source.size
 for y in range(0,h,48):
  for x in range(w):
   if not block[x,y]:pixels[x,y]=(255,0,255,255)
 for x in range(0,w,48):
  for y in range(h):
   if not block[x,y]:pixels[x,y]=(255,0,255,255)
 assert all(not (a and b) for a,b in zip(overlay.getchannel('A').tobytes(),protected.tobytes()))
 Image.alpha_composite(source,overlay).save(P/name)
 files.append({'file':name,'source_frame':n,'sha256':hashlib.sha256((P/name).read_bytes()).hexdigest()})
manifest=json.loads((P/'render_manifest.json').read_text())
manifest.update({'grid_color':'#FF00FF','grid_spacing_px':48,'grid_alpha_clearance_px':8,
 'output':'32 individual SE frames, grid only','frames':files})
(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
with zipfile.ZipFile(P/'SE_32_frames_grid.zip','w',zipfile.ZIP_DEFLATED) as z:
 for entry in files:z.write(P/entry['file'],entry['file'])
 z.write(P/'manifest.json','manifest.json')
with zipfile.ZipFile(P/'SE_32_frames_grid.zip') as z:
 assert len(z.namelist())==33
 assert z.testzip() is None
print('SE_32_GRID_ZIP_VERIFIED')
