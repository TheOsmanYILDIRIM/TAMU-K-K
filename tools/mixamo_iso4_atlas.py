from PIL import Image,ImageDraw
import pathlib,json,zipfile
P=pathlib.Path('rendered/mixamo_iso4')
labels=['NE','NW','SW','SE']
S=1024;cell=256;top=256
all_sheets={}
for label in labels:
 frames=[Image.open(P/label/('frame_%02d.png'%i)).convert('RGBA') for i in range(8)]
 clean=Image.new('RGBA',(S,S),(0,0,0,0))
 overlay=Image.new('RGBA',(S,S),(0,0,0,0))
 draw=ImageDraw.Draw(overlay)
 for i,im in enumerate(frames):
  # fixed uniform sizing and cell centering, non-contact grid
  im.thumbnail((220,224),Image.Resampling.LANCZOS)
  col=i%4;row=i//4;x=col*cell+(cell-im.width)//2;y=top+row*cell+(cell-im.height)//2
  clean.alpha_composite(im,(x,y))
  draw.rectangle((col*cell,top+row*cell,(col+1)*cell-1,top+(row+1)*cell-1),outline=(70,175,235,160),width=2)
  draw.text((col*cell+8,top+row*cell+8),str(i+1),fill=(255,255,255,180))
 clean.save(P/(label+'_clean.png'))
 overlay.save(P/(label+'_grid_overlay.png'))
 composed=Image.alpha_composite(clean,overlay)
 composed.save(P/(label+'_grid.png'))
 all_sheets[label]=clean
master=Image.new('RGBA',(2048,2048),(0,0,0,0))
mastergrid=Image.new('RGBA',(2048,2048),(0,0,0,0))
for i,label in enumerate(labels):
 x=(i%2)*1024;y=(i//2)*1024
 master.alpha_composite(all_sheets[label],(x,y))
 mastergrid.alpha_composite(Image.open(P/(label+'_grid_overlay.png')).convert('RGBA'),(x,y))
master.save(P/'ALL_4_DIRECTIONS_clean.png')
mastergrid.save(P/'ALL_4_DIRECTIONS_grid_overlay.png')
Image.alpha_composite(master,mastergrid).save(P/'ALL_4_DIRECTIONS_grid.png')
manifest=json.loads((P/'render_manifest.json').read_text())
manifest.update({'sheet_size':[1024,1024],'master_size':[2048,2048],'cell_size':256,'frame_region_y':[256,768],
'grid_reversible':'Separate transparent grid overlay; clean and grid versions share identical pixels under overlay.',
'grid_noncontact':'Characters fit inside 220x224 pixels, with 256x256 cell.'})
(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
assert all((P/(x+'_clean.png')).is_file() for x in labels)
assert len(list(P.glob('*/frame_*.png')))==32
print('ISO4_ATLAS_SUCCESS',len(labels),len(list(P.glob('*/frame_*.png'))))
