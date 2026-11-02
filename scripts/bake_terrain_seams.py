#!/usr/bin/env python3
"""Build-only single-mesh feather of authored dry-material boundaries.

Reads the verified z=1 terrain geometry; never mutates source vertices,
water/wetland material, world identities, physics or saved player data.
"""
import argparse, collections, json, math, struct
from pathlib import Path
VERT=struct.Struct('<ffffI')
def bake(layer,manifest,output):
    data=json.loads(Path(manifest).read_text())
    names={}
    for a in data['assets']:
        if a['kind']=='terrain' and a['atlas_page']=='atlas_00.png':
            u,v=a['uv_rect'][:2]
            names[(int(round(u*1848/132)),int(round(v*1584/132)))]=a['family']
    raw=Path(layer).read_bytes()
    assert len(raw)>3000000 and len(raw)%60==0
    edges=collections.defaultdict(list)
    for n in range(len(raw)//60):
        tri=[VERT.unpack_from(raw,n*60+i*20) for i in range(3)]
        center=(sum(p[0] for p in tri)/3,sum(p[1] for p in tri)/3)
        uv=(sum(p[2] for p in tri)/3,sum(p[3] for p in tri)/3)
        family=names.get((min(13,int(uv[0]*14)),min(11,int(uv[1]*12))))
        assert family is not None,n
        for i in range(3):
            a,b=tri[i],tri[(i+1)%3]
            key=tuple(sorted(((round(a[0],2),round(a[1],2)),
                              (round(b[0],2),round(b[1],2)))))
            edges[key].append((family,center,a,b))
    out=bytearray();count=0
    for edge,sides in sorted(edges.items()):
        if len(sides)!=2:continue
        f1,c1,a,b=sides[0];f2,c2,_,_=sides[1]
        if f1==f2 or 'wetland' in (f1,f2):continue
        if f2<f1:
            f1,c1,a,b=sides[1]
            f2,c2=sides[0][:2]
        x1,y1,u1,v1,_=a;x2,y2,u2,v2,_=b
        dx,dy=x2-x1,y2-y1
        length=math.hypot(dx,dy)
        if length<0.001:continue
        nx,ny=-dy/length,dx/length
        mx,my=(x1+x2)*.5,(y1+y2)*.5
        if (c2[0]-mx)*nx+(c2[1]-my)*ny<0:nx,ny=-nx,-ny
        def width(x,y):
            return 10.0+5.5*(0.5+0.5*math.sin((round(x*7)*71+round(y*7)*131)*0.0007))
        w1,w2=width(x1,y1),width(x2,y2)
        def interior_uv(u,v):
            sx=min(13,int(u*14));sy=min(11,int(v*12))
            return (min(max(u,(sx*132+3)/1848),(sx*132+129)/1848),
                    min(max(v,(sy*132+3)/1584),(sy*132+129)/1584))
        uv1,uv2=interior_uv(u1,v1),interior_uv(u2,v2)
        a=(x1-2*nx,y1-2*ny);b=(x2-2*nx,y2-2*ny)
        c=(x1+w1*nx,y1+w1*ny);d=(x2+w2*nx,y2+w2*ny)
        for p,uv,alpha in ((a,uv1,247),(b,uv2,247),(c,uv1,0),
                           (b,uv2,247),(d,uv2,0),(c,uv1,0)):
            out.extend(VERT.pack(p[0],p[1],uv[0],uv[1],0xffffff|(alpha<<24)))
        count+=1
    assert 1000<count<20000 and len(out)==count*120
    result=Path(output);result.parent.mkdir(parents=True,exist_ok=True)
    result.write_bytes(out)
    print('TAMU_TERRAIN_SEAMS_OK edges=',count,'vertices=',count*6,
          'wetland_untouched=true bytes=',len(out))
if __name__=='__main__':
    args=argparse.ArgumentParser()
    args.add_argument('--layer',default='chunks/merged_layer_1.verts')
    args.add_argument('--manifest',default='assets/terrain25d/manifest.json')
    args.add_argument('--output',default='chunks/merged_ground_seams.verts')
    a=args.parse_args()
    bake(a.layer,a.manifest,a.output)
