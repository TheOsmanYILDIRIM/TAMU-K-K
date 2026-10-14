from PIL import Image,ImageDraw,ImageFilter
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

 # MTS-style magenta 48px reference grid; never touches occupied alpha (8px clearance).
 # Grid is a separate reversible presentation layer.
 occupancy=clean.getchannel('A').point(lambda v:255 if v>0 else 0)
 protected=occupancy.filter(ImageFilter.MaxFilter(17))
 pixels=overlay.load();blocked=protected.load()
 for gy in range(0,S,48):
  for gx in range(S):
   if blocked[gx,gy]==0:pixels[gx,gy]=(255,0,255,255)
 for gx in range(0,S,48):
  for gy in range(S):
   if blocked[gx,gy]==0:pixels[gx,gy]=(255,0,255,255)
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
manifest.update({'grid_style':'MTS magenta #FF00FF, spacing 48px, 8px alpha clearance, separate overlay; restore uses clean sheet and frame map', 'sheet_size':[1024,1024],'master_size':[2048,2048],'cell_size':256,'frame_region_y':[256,768],
'grid_reversible':'Separate transparent grid overlay; clean and grid versions share identical pixels under overlay.',
'grid_noncontact':'Characters fit inside 220x224 pixels, with 256x256 cell.'})
mapping={'schema':1,'source':'Blender Walking.fbx pinned source','sheet_size':[S,S],
'grid':{'color':'#FF00FF','spacing':48,'clearance_px':8,'overlay_is_separate':True},
'directions':{label:[{'frame':i,'source_frame':manifest['source_frames'][i],
'cell':[i%4,1+i//4],'rect':[i%4*256,256+i//4*256,256,256]} for i in range(8)] for label in labels},
'restore':'For lossless clean source use *_clean.png. For AI-generated sheets use mapping to extract cell rectangles; source alpha cannot prove AI geometry fidelity.'}
(P/'grid_mapping.json').write_text(json.dumps(mapping,indent=2))
(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
assert all((P/(x+'_clean.png')).is_file() for x in labels)
assert len(list(P.glob('*/frame_*.png')))==32
print('ISO4_ATLAS_SUCCESS',len(labels),len(list(P.glob('*/frame_*.png'))))
