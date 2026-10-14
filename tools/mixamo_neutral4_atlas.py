from PIL import Image,ImageFilter
import pathlib,json,hashlib
P=pathlib.Path('rendered/mixamo_neutral4')
directions=['NE','NW','SW','SE']
size=2048;cell=1024
clean=Image.new('RGBA',(size,size),(0,0,0,0))
mapping={}
for i,name in enumerate(directions):
 im=Image.open(P/(name+'_rest.png')).convert('RGBA')
 assert im.size==(1024,1024)
 bbox=im.getchannel('A').getbbox()
 assert bbox,'Empty rest pose render: '+name
 x=(i%2)*cell;y=(i//2)*cell
 clean.alpha_composite(im,(x,y))
 mapping[name]={'source_file':name+'_rest.png','source_sha256':hashlib.sha256((P/(name+'_rest.png')).read_bytes()).hexdigest(),
 'source_bbox':list(bbox),'atlas_rect':[x,y,cell,cell],'atlas_occupied_bbox':[x+bbox[0],y+bbox[1],x+bbox[2],y+bbox[3]]}
clean.save(P/'NEUTRAL_4_clean.png')
# MTS 48px magenta grid, no grid pixel within 8px of occupied alpha.
overlay=Image.new('RGBA',clean.size,(0,0,0,0))
occupied=clean.getchannel('A').point(lambda v:255 if v else 0)
protected=occupied.filter(ImageFilter.MaxFilter(17))
pixels=overlay.load();blocked=protected.load()
for y in range(0,size,48):
 for x in range(size):
  if not blocked[x,y]:pixels[x,y]=(255,0,255,255)
for x in range(0,size,48):
 for y in range(size):
  if not blocked[x,y]:pixels[x,y]=(255,0,255,255)
overlay.save(P/'NEUTRAL_4_grid_overlay.png')
Image.alpha_composite(clean,overlay).save(P/'NEUTRAL_4_grid.png')
manifest=json.loads((P/'render_manifest.json').read_text())
manifest.update({'atlas_size':[2048,2048],'grid_color':'#FF00FF','grid_spacing':48,'alpha_clearance_px':8})
(P/'mapping.json').write_text(json.dumps({'schema':1,'manifest':manifest,'directions':mapping,
'roundtrip':'Original rest images are canonical. Grid overlay is separate. Crop clean atlas by atlas_rect for exact RGBA restoration. AI-modified output requires registration and geometry inspection.'},indent=2))
# Exact RGBA round-trip for every quadrant.
for name,m in mapping.items():
 assert clean.crop(tuple(m['atlas_rect'])).tobytes()==Image.open(P/m['source_file']).convert('RGBA').tobytes()
assert all(not (a and b) for a,b in zip(overlay.getchannel('A').tobytes(),protected.tobytes()))
print('NEUTRAL4_ATLAS_SUCCESS',list(mapping))
