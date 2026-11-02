#!/usr/bin/env python3
"""Premium carved-wood TAMU UI. Deterministic CI bake; ZERO runtime art generation.

All resources are authored from reproducible code and imported as textures.
No font source is shipped; ornamental headings are baked as ordinary PNG pixels.
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT=Path("assets/gui")
ROOT.mkdir(parents=True, exist_ok=True)
R=random.Random(20261102)

def rgba(v,a=255):
    return tuple(int(max(0,min(255,c))) for c in v)+(a,)

def wood(w,h,tint,grain=1):
    """Continuous fine walnut/greenwood grain with diffuse wear, no black scratches."""
    im=Image.new("RGBA",(w,h))
    pix=im.load()
    offsets=[R.uniform(-1,1) for _ in range(h)]
    for y in range(h):
        ring=math.sin(y*.065+math.sin(y*.013)*2.6)
        for x in range(w):
            g=(.79+.085*ring+.040*math.sin(y*.18+math.sin(x*.025)*2.0)
               +.024*math.sin(y*.49+x*.008)+.018*offsets[y]+R.uniform(-.024,.024))
            edges=1-.15*min(1,abs((x-w/2)/(w/2)))**1.4
            pix[x,y]=rgba([v*g*edges for v in tint])
    d=ImageDraw.Draw(im,"RGBA")
    for k in range(max(5,h//45)):
        y=R.randint(9,h-10)
        x0=R.randint(14,w//2)
        x1=R.randint(max(x0+1,w//2),w-14)
        segments=[]
        for i in range(11):
            x=x0+(x1-x0)*i/10
            segments.append((x,y+math.sin(x*.032+k)*2.4+math.sin(x*.008)*4))
        d.line(segments,fill=(244,196,114,14),width=1)
    return im

def border_design(d,w,h,radius):
    # Layered leather seams, carved brown rim and brushed antique gold band.
    d.rounded_rectangle((13,11,w-14,h-20),radius=radius,
                        outline=(24,14,9,245),width=12)
    d.rounded_rectangle((19,15,w-20,h-25),radius=radius-2,
                        outline=(94,51,24,250),width=8)
    d.rounded_rectangle((24,19,w-24,h-31),radius=radius-3,
                        outline=(187,129,67,235),width=3)
    d.rounded_rectangle((29,24,w-29,h-36),radius=radius-7,
                        outline=(241,189,100,130),width=2)
    d.arc((27,20,w-30,h//2+4),184,353,fill=(255,222,142,74),width=2)
    d.arc((30,h//2,w-26,h-30),17,175,fill=(24,12,7,120),width=3)
    for x in (47,w-48):
        for y in (44,h-58):
            d.ellipse((x-6,y-6,x+6,y+6),fill=(18,13,9,230),
                      outline=(224,164,87,217),width=2)
            d.ellipse((x-2,y-3,x+1,y+1),fill=(240,192,107,114))
    # Corner filigree, oriented to keep center text unobstructed.
    for xx,side in ((34,1),(w-34,-1)):
        for yy,ys in ((36,1),(h-45,-1)):
            curve=[]
            for k in range(15):
                t=k/14.
                curve.append((xx+side*(8+38*t),
                              yy+ys*(6+17*t+5*math.sin(t*math.pi))))
            d.line(curve,fill=(215,165,89,125),width=3)
            d.ellipse((xx+side*34-3,yy+ys*20-3,xx+side*34+3,yy+ys*20+3),
                      fill=(241,195,104,145))

def braid(d,x,y0,y1):
    # Relief cord wrapped down left corner, braided rather than geometric dots.
    d.line((x,y0,x,y1),fill=(26,14,8,210),width=17)
    d.line((x-2,y0,x-2,y1),fill=(139,91,47,218),width=12)
    for y in range(y0,y1,13):
        d.line((x-9,y,x+8,y+13),fill=(247,186,99,198),width=5)
        d.line((x+7,y,x-8,y+13),fill=(90,51,27,223),width=3)
    d.line((x+6,y0,x+6,y1),fill=(241,174,83,85),width=2)

def leaves(d,x,y,direction=1):
    # Asymmetric foliage tucked into corners, with subtle olive highlights.
    d.line((x,y,x+direction*57,y+35),
           fill=(91,80,31,205),width=4)
    for i in range(6):
        shift=i*11
        cx=x+direction*(9+shift)
        cy=y+5+i*6
        yy=-1 if i%2 else 1
        pts=[(cx,cy),(cx+direction*12,cy+yy*14),
             (cx+direction*23,cy+yy*3),(cx+direction*12,cy+yy*1)]
        c=(88+i*5,111+i*5,42+i*4,238)
        d.polygon(pts,fill=c)
        d.line((cx,cy,cx+direction*21,cy+yy*3),
               fill=(202,197,105,121),width=1)

def carved_panel():
    w,h=720,540
    canvas=Image.new("RGBA",(w,h))
    shadow=Image.new("RGBA",(w,h))
    sd=ImageDraw.Draw(shadow,"RGBA")
    sd.rounded_rectangle((25,25,w-20,h-18),radius=47,fill=(0,0,0,205))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))
    im=wood(w-42,h-48,(89,59,38))
    mask=Image.new("L",im.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,im.width-1,im.height-1),
                                           radius=40,fill=255)
    im.putalpha(mask)
    canvas.alpha_composite(im,(20,12))
    # Inset dark walnut central panel; grain follows horizontal grow rings.
    inside=wood(w-103,h-116,(55,38,26))
    center_mask=Image.new("L",inside.size)
    ImageDraw.Draw(center_mask).rounded_rectangle(
        (0,0,inside.width-1,inside.height-1),radius=26,fill=252)
    inside.putalpha(center_mask)
    canvas.alpha_composite(inside,(51,48))
    d=ImageDraw.Draw(canvas,"RGBA")
    border_design(d,w,h,43)
    d.rounded_rectangle((51,48,w-51,h-66),radius=25,
                        outline=(17,10,7,177),width=5)
    d.line((94,187,w-90,187),fill=(23,12,7,210),width=4)
    d.line((94,190,w-90,190),fill=(211,151,80,153),width=2)
    d.line((94,316,w-91,316),fill=(28,18,12,185),width=3)
    d.line((94,318,w-91,318),fill=(207,156,96,73),width=1)
    braid(d,34,40,230)
    leaves(d,w-135,40)
    leaves(d,70,h-108,1)
    canvas.save(ROOT/"panel.png",optimize=True)

def button(name,w,h,fill,rim,kind):
    canvas=Image.new("RGBA",(w,h))
    sh=Image.new("RGBA",(w,h))
    d=ImageDraw.Draw(sh)
    d.rounded_rectangle((12,18,w-12,h-9),radius=33,fill=(0,0,0,180))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)))
    panel=wood(w-28,h-35,fill)
    mask=Image.new("L",panel.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,panel.width-1,panel.height-1),
                                           radius=30,fill=255)
    panel.putalpha(mask)
    canvas.alpha_composite(panel,(14,9))
    d=ImageDraw.Draw(canvas,"RGBA")
    d.rounded_rectangle((17,12,w-18,h-29),radius=30,
                        outline=(14,10,5,235),width=7)
    d.rounded_rectangle((20,13,w-22,h-31),radius=27,
                        outline=rim,width=4)
    d.rounded_rectangle((27,18,w-28,h-37),radius=23,
                        outline=(244,207,130,95),width=2)
    # Bevelled inset and tiny scrollwork only around corners.
    d.arc((29,21,w-29,h//2+3),190,350,
          fill=(255,227,161,130 if kind=="oak" else 70),width=3)
    d.arc((29,h//2,w-30,h-36),10,173,fill=(18,11,7,185),width=4)
    if kind=="oak":
        d.line((46,h-44,w-46,h-44),fill=(243,170,65,85),width=2)
        for x,dir in ((40,1),(w-40,-1)):
            for i in range(4):
                dx=dir*(4+i*12)
                d.arc((x+dx-7,23+i*3,x+dx+20,h-35),
                      65 if dir==1 else 160,290 if dir==1 else 370,
                      fill=(127,70,28,160),width=2)
    elif kind=="green":
        leaves(d,28,h-39,1)
    else:
        for x in (39,w-39):
            d.ellipse((x-3,h//2-3,x+3,h//2+3),
                      fill=(218,170,96,200))
    canvas.save(ROOT/name,optimize=True)

def icon(name):
    s=112
    im=Image.new("RGBA",(s,s))
    sd=ImageDraw.Draw(im,"RGBA")
    # Icon's soft shadow makes it appear physically lifted off wood.
    if name in ("log","hammer","pick"):
        sd.ellipse((22,75,95,98),fill=(12,8,4,70))
    d=sd
    if name=="log":
        d.polygon([(30,72),(70,22),(99,39),(57,87)],fill=(133,74,36,255))
        for o in (0,7,14):
            d.line((37+o,69-o*.45,80+o*.2,31+o*.38),
                   fill=(232,164,89,90),width=3)
        d.ellipse((18,61,61,100),fill=(198,128,66,255),
                  outline=(77,41,23,255),width=5)
        d.ellipse((26,67,52,90),outline=(114,66,35,240),width=3)
    elif name=="leaf":
        d.polygon([(25,72),(14,50),(34,21),(69,14),(77,37),(51,66)],
                  fill=(106,143,53,255))
        d.polygon([(58,67),(48,36),(70,19),(91,27),(94,53),(72,75)],
                  fill=(161,177,86,250))
        d.line((15,92,79,28),fill=(225,204,127,220),width=4)
        for x,y in ((35,54),(49,42),(62,33)):
            d.line((x,y,x-5,y-14),fill=(221,205,119,110),width=2)
    elif name=="basket":
        d.rounded_rectangle((18,48,97,93),radius=13,
            fill=(153,91,35,255),outline=(68,39,17,255),width=5)
        d.arc((33,23,83,64),180,360,fill=(248,187,92,252),width=7)
        for x in range(26,95,13):
            d.line((x,51,x+8,91),fill=(242,181,100,153),width=4)
        for y in (64,79):
            d.line((22,y,93,y),fill=(77,44,25,200),width=3)
    elif name in ("hammer","pick"):
        d.line((29,96,68,22),fill=(66,38,17,250),width=16)
        d.line((27,92,62,26),fill=(182,117,56,250),width=10)
        if name=="hammer":
            d.polygon([(28,19),(97,37),(91,55),(24,38)],
                fill=(186,182,168,255))
            d.line((30,24,87,40),fill=(248,242,219,110),width=4)
        else:
            d.arc((13,18,103,78),181,343,fill=(200,193,163,255),width=12)
            d.arc((13,18,103,78),189,337,fill=(255,245,221,105),width=3)
    elif name=="pin":
        d.ellipse((28,12,88,72),outline=(215,171,91,255),width=10)
        d.ellipse((42,26,73,56),fill=(34,28,19,240))
        d.polygon([(31,67),(85,67),(58,103)],fill=(204,159,79,255))
    im.save(ROOT/(name+".png"),optimize=True)

def glow():
    n=256
    im=Image.new("RGBA",(n,n))
    p=im.load()
    for y in range(n):
        for x in range(n):
            dx=(x-n/2)/(n*.48);dy=(y-n/2)/(n*.48)
            alpha=int(max(0,117*math.exp(-3.7*(dx*dx+dy*dy))-1))
            p[x,y]=(255,202,95,alpha)
    im.save(ROOT/"glow.png",optimize=True)

def bokeh():
    im=Image.new("RGBA",(512,768))
    d=ImageDraw.Draw(im,"RGBA")
    rng=random.Random(281101)
    for k in range(135):
        x=rng.randrange(-30,542);y=rng.randrange(-30,798)
        radius=rng.randrange(4,28)
        d.ellipse((x-radius,y-radius,x+radius,y+radius),
                  fill=rng.choice([(247,202,99,20),(205,209,108,14),(246,215,145,13)]))
    im.filter(ImageFilter.GaussianBlur(17)).save(ROOT/"bokeh.png",optimize=True)

def title(name,text):
    # DejaVu Serif is provided by Ubuntu; deliver pixels only, not font files.
    try:
        font=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",75)
    except OSError:
        font=ImageFont.load_default()
    canvas=Image.new("RGBA",(340,108))
    d=ImageDraw.Draw(canvas,"RGBA")
    for shift in range(4,0,-1):
        d.text((171,54+shift),text,font=font,anchor="mm",stroke_width=3,
               stroke_fill=(20,12,7,205),fill=(20,12,7,100))
    d.text((170,51),text,font=font,anchor="mm",
           stroke_width=1,stroke_fill=(51,28,14,255),
           fill=(248,221,168,255))
    canvas.save(ROOT/(name+".png"),optimize=True)

def main():
    carved_panel()
    button("button_green.png",430,146,(43,65,36),(193,159,87,240),"green")
    button("button_oak.png",550,156,(153,86,35),(252,193,104,245),"oak")
    button("button_small.png",300,125,(72,60,38),(176,148,91,220),"small")
    for key in ("log","leaf","basket","hammer","pick","pin"):icon(key)
    title("heading_tree","AĞAÇ")
    title("heading_rock","KAYA")
    glow()
    bokeh()
    required=("panel.png","button_green.png","button_oak.png","button_small.png",
              "log.png","leaf.png","basket.png","hammer.png","pick.png","pin.png",
              "glow.png","bokeh.png","heading_tree.png","heading_rock.png")
    for path in required:
        assert (ROOT/path).stat().st_size>400, path
    print("TAMU_FOREST_GUI_ASSETS_OK count=",len(required),"style=carved_walnut_v2")

if __name__=="__main__":main()
