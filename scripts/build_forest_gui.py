#!/usr/bin/env python3
"""Build-time forest UI textures. Seeded procedural wood/bronze; no runtime raster work."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import random,math
ROOT=Path("assets/gui")
ROOT.mkdir(parents=True,exist_ok=True)
rng=random.Random(22021102)
def timber(w,h,color):
    im=Image.new("RGBA",(w,h))
    p=im.load()
    variation=[rng.uniform(-1,1) for _ in range(h)]
    for y in range(h):
        for x in range(w):
            shade=.94+.075*math.sin(y*.07+7*math.sin(x*.013))+.025*variation[y]+rng.uniform(-.035,.035)
            rim=.83+.17*max(0,1-abs(x-w*.5)/(w*.55))
            p[x,y]=tuple(max(0,min(255,int(v*shade*rim))) for v in color)+(255,)
    d=ImageDraw.Draw(im,"RGBA")
    for _ in range(max(35,w*h//3900)):
        x=rng.randrange(9,w-10);y=rng.randrange(9,h-10)
        length=rng.randrange(12,max(13,w//4))
        d.line((x,y,min(w-8,x+length),y+rng.choice((-1,0,0,1))),
               fill=(20,11,5,rng.randint(8,24)),width=1)
    return im
def framed(name,w,h,color,stroke,radius):
    result=Image.new("RGBA",(w,h),(0,0,0,0))
    sh=Image.new("RGBA",(w,h),(0,0,0,0))
    d=ImageDraw.Draw(sh)
    d.rounded_rectangle((12,15,w-9,h-7),radius=radius,fill=(0,0,0,175))
    result.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)))
    tile=timber(w-28,h-28,color)
    mask=Image.new("L",tile.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,tile.width-1,tile.height-1),
                                              radius=radius,fill=255)
    tile.putalpha(mask)
    result.alpha_composite(tile,(14,9))
    d=ImageDraw.Draw(result,"RGBA")
    d.rounded_rectangle((15,10,w-15,h-21),radius=radius,outline=stroke,width=6)
    d.rounded_rectangle((22,17,w-22,h-28),radius=max(6,radius-7),
                         outline=(244,200,129,58),width=3)
    d.arc((28,10,w-28,h//2+18),18,168,fill=(248,211,144,20),width=2)
    result.save(ROOT/name)
    return result
def wood_panel():
    w,h=610,460
    im=framed("panel.png",w,h,(59,43,30),(157,115,71,190),34)
    d=ImageDraw.Draw(im,"RGBA")
    for y in (135,250):
        d.line((75,y,w-78,y),fill=(9,7,5,170),width=3)
        d.line((75,y+2,w-78,y+2),fill=(224,172,105,56),width=1)
    for x in (46,w-45):
        for y in (43,h-49):
            d.ellipse((x-5,y-5,x+5,y+5),fill=(21,12,6,218),
                      outline=(192,145,83,165),width=2)
    for i in range(5):
        x=w-102+i*9;y=26+i*10
        d.ellipse((x-15,y-4,x+10,y+9),
                  fill=(71+i*10,102+i*7,37,180),
                  outline=(175,161,73,117),width=1)
        d.line((x-4,y+13,x+11,y+24),fill=(87,93,38,140),width=2)
    im.save(ROOT/"panel.png")
def icon(name):
    im=Image.new("RGBA",(80,80),(0,0,0,0));d=ImageDraw.Draw(im,"RGBA")
    if name=="log":
        d.polygon([(20,50),(47,17),(69,29),(42,63)],fill=(158,104,52,255))
        d.ellipse((12,40,40,67),fill=(200,145,83,255),outline=(89,54,25,255),width=4)
        d.ellipse((21,47,34,60),outline=(115,67,30,210),width=2)
    elif name=="leaf":
        d.ellipse((10,28,58,61),fill=(130,146,65,244),outline=(53,81,32,255),width=3)
        d.ellipse((32,11,73,43),fill=(169,177,105,245),outline=(65,91,39,255),width=3)
        d.line((16,71,65,21),fill=(222,199,126,235),width=4)
    elif name=="basket":
        d.rounded_rectangle((13,36,66,67),radius=9,fill=(150,101,50,245),
                            outline=(80,49,24,255),width=4)
        d.arc((25,15,58,52),170,360,fill=(236,181,106,250),width=6)
        for x in range(23,62,11):d.line((x,37,x,65),fill=(89,59,29,190),width=3)
        for y in (46,56):d.line((17,y,64,y),fill=(237,182,105,130),width=2)
    elif name=="hammer":
        d.line((29,65,54,21),fill=(149,102,55,255),width=12)
        d.polygon([(27,14),(68,26),(60,43),(19,29)],fill=(183,178,164,255),
                  outline=(65,65,61,255))
    elif name=="pick":
        d.line((24,67,49,23),fill=(160,110,59,255),width=12)
        d.arc((12,10,70,57),192,345,fill=(184,176,154,255),width=10)
    elif name=="pin":
        d.ellipse((21,8,59,48),outline=(215,178,104,255),width=7)
        d.polygon([(26,44),(55,44),(40,71)],fill=(204,164,87,255))
    im.save(ROOT/(name+".png"))
def bokeh():
    im=Image.new("RGBA",(512,768),(0,0,0,0))
    d=ImageDraw.Draw(im,"RGBA")
    rng2=random.Random(992101)
    for i in range(150):
        x=rng2.randrange(-40,552);y=rng2.randrange(-40,808)
        r=rng2.randrange(4,26)
        d.ellipse((x-r,y-r,x+r,y+r),
            fill=rng2.choice([(224,178,88,17),(182,206,90,11),(235,216,118,13)]))
    im.filter(ImageFilter.GaussianBlur(13)).save(ROOT/"bokeh.png")
def radial_glow():
    w=256
    im=Image.new("RGBA",(w,w),(0,0,0,0))
    pix=im.load()
    for y in range(w):
        for x in range(w):
            dx=(x-w/2)/(w*.48)
            dy=(y-w/2)/(w*.48)
            r=dx*dx+dy*dy
            alpha=int(max(0,112*math.exp(-r*3.5)-1))
            pix[x,y]=(255,196,84,alpha)
    im.save(ROOT/"glow.png")

def main():
    wood_panel()
    radial_glow()
    framed("button_green.png",325,115,(29,47,33),(177,151,101,215),28)
    framed("button_oak.png",440,120,(161,106,55),(230,172,93,225),26)
    framed("button_small.png",225,95,(61,57,39),(156,134,90,180),23)
    for name in ("log","leaf","basket","hammer","pick","pin"):icon(name)
    bokeh()
    required=("panel.png","button_green.png","button_oak.png","button_small.png",
              "log.png","leaf.png","basket.png","hammer.png","pick.png","pin.png","bokeh.png","glow.png")
    assert all((ROOT/name).stat().st_size>300 for name in required)
    print("TAMU_FOREST_GUI_ASSETS_OK count=",len(required))
if __name__=="__main__":main()
