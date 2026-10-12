extends Node2D
const SEED:int = 42
const SIDE:int = 192
const THRESHOLD:float = 0.51
const SEGMENTS:Array = [[],[[3,0]],[[0,1]],[[3,1]],[[1,2]],[[3,2],[0,1]],[[0,2]],[[3,2]],[[2,3]],[[0,2]],[[0,3],[1,2]],[[1,2]],[[1,3]],[[0,1]],[[3,0]],[]]
var lines:Array[PackedVector2Array] = []
var generation_ms:float = 0.0
var frames:int = 0
var elapsed:float = 0.0
func h(x:int,y:int,s:int)->float:
 var n:int = posmod(x*15731+y*789221+s*137631,65521)
 return float((n*251+17)%65521)/65520.0
func noise(x:float,y:float,s:int)->float:
 var ix:int=floori(x)
 var iy:int=floori(y)
 var u:float=x-ix
 var v:float=y-iy
 u=u*u*(3.0-2.0*u)
 v=v*v*(3.0-2.0*v)
 return lerpf(lerpf(h(ix,iy,s),h(ix+1,iy,s),u),lerpf(h(ix,iy+1,s),h(ix+1,iy+1,s),u),v)
func density(x:int,y:int)->float:
 return 0.67*noise(float(x)/22.0,float(y)/22.0,SEED)+0.33*noise(float(x)/8.0,float(y)/8.0,SEED+91)
func iso(x:float,y:float)->Vector2:
 return Vector2((x-y)*5.0,(x+y)*2.5)
func cross(a:Vector2,b:Vector2,va:float,vb:float)->Vector2:
 var t:float=0.5 if absf(vb-va)<0.00000001 else clampf((THRESHOLD-va)/(vb-va),0.0,1.0)
 return a.lerp(b,t)
func _ready()->void:
 var begin:int=Time.get_ticks_usec()
 var values:PackedFloat32Array=PackedFloat32Array()
 values.resize((SIDE+1)*(SIDE+1))
 for y in range(SIDE+1):
  for x in range(SIDE+1):
   values[y*(SIDE+1)+x]=density(x-SIDE/2,y-SIDE/2)
 for y in range(SIDE):
  for x in range(SIDE):
   var v:Array=[values[y*(SIDE+1)+x],values[y*(SIDE+1)+x+1],values[(y+1)*(SIDE+1)+x+1],values[(y+1)*(SIDE+1)+x]]
   var mask:int=0
   for i in range(4):
    if v[i]>=THRESHOLD: mask|=1<<i
   if mask==0 or mask==15: continue
   var p0:Vector2=Vector2(x-SIDE/2,y-SIDE/2)
   var p1:Vector2=p0+Vector2.RIGHT
   var p2:Vector2=p0+Vector2.ONE
   var p3:Vector2=p0+Vector2.DOWN
   var e:Array=[cross(p0,p1,v[0],v[1]),cross(p1,p2,v[1],v[2]),cross(p3,p2,v[3],v[2]),cross(p0,p3,v[0],v[3])]
   for pair in SEGMENTS[mask]:
    lines.append(PackedVector2Array([iso(e[pair[0]].x,e[pair[0]].y),iso(e[pair[1]].x,e[pair[1]].y)]))
 generation_ms=float(Time.get_ticks_usec()-begin)/1000.0
 print("BENCH Godot seed=42 cells=",SIDE*SIDE," segments=",lines.size()," generation_ms=",generation_ms)
 queue_redraw()
func _process(delta:float)->void:
 elapsed+=delta
 frames+=1
 if frames==300:
  print("BENCH Godot avg_fps=",frames/elapsed)
  frames=0
  elapsed=0
func _draw()->void:
 draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color("#243c36"))
 var center:Vector2=get_viewport_rect().size*0.5
 for line in lines:
  draw_line(line[0]+center,line[1]+center,Color("#a9d48e"),1.5)
