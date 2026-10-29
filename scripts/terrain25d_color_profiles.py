#!/usr/bin/env python3
"""Offline CIELAB+contrast signatures for 128px user-created indexed PNGs.
No blur, texture modifications, new dependencies or runtime pixel analysis.
"""
import base64
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zlib

SIG=b'\x89PNG\r\n\x1a\n'
def indexed(data):
    if not data.startswith(SIG): raise ValueError('PNG signature mismatch')
    pos=8;palette=None;compressed=[];width=height=depth=kind=None
    while pos<len(data):
        if pos+12>len(data): raise ValueError('PNG truncated')
        n=int.from_bytes(data[pos:pos+4],'big')
        tag=data[pos+4:pos+8];val=data[pos+8:pos+8+n]
        if pos+12+n>len(data): raise ValueError('PNG chunk overflow')
        if zlib.crc32(tag+val)&0xffffffff!=int.from_bytes(data[pos+8+n:pos+12+n],'big'):
            raise ValueError('Invalid PNG CRC: '+repr(tag))
        pos+=12+n
        if tag==b'IHDR':
            width,height,depth,kind,compression,filt,interlace=struct.unpack('>IIBBBBB',val)
            if (width,height,depth,kind,interlace)!=(128,128,8,3,0):
                raise ValueError('Expected 128x128 indexed 8-bit PNG')
        elif tag==b'PLTE':palette=[val[i:i+3] for i in range(0,len(val),3)]
        elif tag==b'IDAT':compressed.append(val)
        elif tag==b'IEND':break
    if palette is None or not compressed:raise ValueError('Missing PNG PLTE/IDAT')
    raw=zlib.decompress(b''.join(compressed))
    if len(raw)!=height*(width+1):raise ValueError('PNG scanline size mismatch')
    freq=[0]*len(palette);previous=bytearray(width);pos=0
    for y in range(height):
        mode=raw[pos];pos+=1
        row=bytearray(raw[pos:pos+width]);pos+=width
        for i in range(width):
            a=row[i-1] if i else 0
            b=previous[i];c=previous[i-1] if i else 0
            if mode==1:row[i]=(row[i]+a)&255
            elif mode==2:row[i]=(row[i]+b)&255
            elif mode==3:row[i]=(row[i]+(a+b)//2)&255
            elif mode==4:
                pa=abs(b-c);pb=abs(a-c);pc=abs(a+b-2*c)
                row[i]=(row[i]+(a if pa<=pb and pa<=pc else (b if pb<=pc else c)))&255
            elif mode!=0:raise ValueError('Unexpected PNG filter')
            if row[i]>=len(palette):raise ValueError('PNG palette index out of range')
            freq[row[i]]+=1
        previous=row
    return palette,freq

def lab(rgb):
    def gamma(v):
        x=v/255
        return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
    r,g,b=map(gamma,rgb)
    x=(.4124564*r+.3575761*g+.1804375*b)/.95047
    y=.2126729*r+.7151522*g+.0721750*b
    z=(.0193339*r+.1191920*g+.9503041*b)/1.08883
    def f(t):return t**(1/3) if t>(6/29)**3 else t/(3*(6/29)**2)+4/29
    X,Y,Z=f(x),f(y),f(z)
    return (116*Y-16,500*(X-Y),200*(Y-Z))

def profile(data):
    colors,frequency=indexed(data)
    total=sum(frequency);mean=[0.,0.,0.];second=0.
    for color,count in zip(colors,frequency):
        if count:
            v=lab(color)
            for k in range(3):mean[k]+=v[k]*count/total
            second+=v[0]**2*count/total
    return [round(x,2) for x in mean]+[round(math.sqrt(max(0,second-mean[0]**2)),2)]

def build(root):
    m=json.loads((root/'manifest.json').read_text())
    inv=json.loads((root/'archive_inventory.json').read_text())
    records={x['source_drive_id']:x for x in inv['assets']}
    result={}
    for a in m['assets']:
        if a['kind']!='terrain':continue
        source=records[a['source_drive_id']]
        path=root/Path(source['source_repo_path']).relative_to('game/love/assets/terrain25d')
        data=path.read_bytes()
        if hashlib.sha256(data).hexdigest()!=a['sha256']:
            raise ValueError('Source SHA mismatch: '+str(path))
        result[a['id']]=profile(data)
    if len(result)!=168:raise ValueError('Expected 168 terrain entries')
    return {'version':1,'space':'CIELAB-D65-mean-L-std','assets':result}

if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]/'game/love/assets/terrain25d'
    content=json.dumps(build(root),separators=(',',':'),sort_keys=True)
    if '--ci-emit' in sys.argv:
        print('OSMAN25D_COLOR_PROFILES_JSON='+content)
    else:print(content)
