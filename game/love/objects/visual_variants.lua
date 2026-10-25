-- Presentation-only 14 nature variants for existing v1 tree/rock objects.
-- No new catalog IDs, drops, collision radii, save format or RNG mutation.
local V={}
local trees={"oak","birch","pine","maple","willow","berry_bush","fern","thorn_bush"}
local rocks={"boulder","ore_vein","crystal","fallen_log","stump","mushrooms"}
local function hash(id)
 local n=17
 for i=1,#id do n=(n*33+id:byte(i))%1000003 end
 return n
end
function V.variant(o)
 assert(o and type(o.id)=="string","stable object id required")
 local group=o.kind=="tree" and trees or rocks
 return group[hash(o.id)%#group+1]
end
function V.names() return trees,rocks end
local function line(g,x1,y1,x2,y2,z)
 g.setLineWidth(math.max(1,z*2));g.line(x1,y1,x2,y2)
end
local function leaf(g,x,y,z,r,col)
 g.setColor(col[1],col[2],col[3]);g.ellipse("fill",x,y,r*z,r*.78*z)
end
function V.draw(g,x,y,z,o,variant)
 local h=hash(o.id)
 local k=variant or V.variant(o)
 g.setColor(0,.09,.08,.26)
 g.ellipse("fill",x,y+3*z,o.radius*z*1.2,o.radius*z*.55)
 if k=="oak" or k=="birch" or k=="pine" or k=="maple" or k=="willow" then
  local tall=k=="pine" and 75 or 58
  if k=="birch" then g.setColor(.78,.77,.69) else g.setColor(.34,.23,.14) end
  g.rectangle("fill",x-4*z,y-tall*z,8*z,tall*z)
  if k=="birch" then
   g.setColor(.24,.25,.22)
   for j=1,4 do g.rectangle("fill",x-3*z,y-(j*11+8)*z,4*z,2*z) end
  end
  if k=="pine" then
   for j=1,3 do
    g.setColor(.12+j*.025,.29+j*.025,.21)
    local yy=y-(27+j*15)*z
    g.polygon("fill",x-(28-j*3)*z,yy,x,yy-(33-j*2)*z,x+(28-j*3)*z,yy)
   end
  elseif k=="willow" then
   leaf(g,x,y-60*z,z,25,{.24,.42,.22})
   g.setColor(.28,.44,.23)
   for i=-3,3 do
    local xx=x+i*7*z
    line(g,xx,y-61*z,xx+(i%2)*4*z,y-(32+(h+i*7)%19)*z,z*.7)
   end
  else
   local c=k=="maple" and {.67,.32,.16} or k=="birch" and {.36,.57,.27} or {.22,.44,.23}
   leaf(g,x-15*z,y-58*z,z,19,c)
   leaf(g,x+15*z,y-57*z,z,18,c)
   leaf(g,x,y-74*z,z,22,c)
  end
 elseif k=="berry_bush" or k=="fern" or k=="thorn_bush" then
  if k=="fern" then
   g.setColor(.20,.49,.24)
   for i=-3,3 do
    local xx=x+i*6*z
    g.polygon("fill",x,y-3*z,xx-6*z,y-14*z,xx,y-31*z,xx+6*z,y-14*z)
   end
  else
   leaf(g,x,y-13*z,z,18,k=="thorn_bush" and {.27,.34,.19} or {.21,.46,.23})
   if k=="berry_bush" then
    g.setColor(.80,.16,.21)
    for i=1,6 do
     local a=i*2.399+h*.001
     g.circle("fill",x+math.cos(a)*11*z,y-13*z+math.sin(a)*8*z,2.6*z)
    end
   else
    g.setColor(.69,.65,.42)
    for i=-2,2 do line(g,x+i*6*z,y-7*z,x+i*9*z,y-22*z,z*.5) end
   end
  end
 elseif k=="fallen_log" then
  g.setColor(.33,.20,.12);g.polygon("fill",x-23*z,y-8*z,x+18*z,y-15*z,x+25*z,y-6*z,x-17*z,y+1*z)
  g.setColor(.59,.39,.23);g.ellipse("fill",x+22*z,y-10*z,5*z,7*z)
 elseif k=="stump" then
  g.setColor(.38,.23,.13);g.rectangle("fill",x-12*z,y-12*z,24*z,12*z)
  g.setColor(.65,.48,.28);g.ellipse("fill",x,y-12*z,12*z,5*z)
  g.setColor(.43,.31,.18);g.ellipse("line",x,y-12*z,7*z,3*z)
 elseif k=="mushrooms" then
  for i=-1,1 do
   local dx=i*12*z;local top=y-(13+(i%2)*5)*z
   g.setColor(.82,.77,.63);g.rectangle("fill",x+dx-2*z,top,4*z,y-top)
   g.setColor(.69,.25,.21);g.ellipse("fill",x+dx,top,9*z,5*z)
   g.setColor(.96,.89,.71);g.circle("fill",x+dx-2*z,top-2*z,1.6*z)
  end
 else
  local c=k=="crystal" and {.36,.74,.82} or k=="ore_vein" and {.48,.50,.49} or {.33,.39,.40}
  g.setColor(c[1],c[2],c[3])
  g.polygon("fill",x-17*z,y-4*z,x-11*z,y-21*z,x+3*z,y-31*z,x+18*z,y-14*z,x+13*z,y,x-7*z,y+3*z)
  g.setColor(c[1]+.10,c[2]+.09,c[3]+.08)
  g.polygon("fill",x-11*z,y-21*z,x+3*z,y-31*z,x+18*z,y-14*z,x,y-13*z)
  if k=="ore_vein" then
   g.setColor(.77,.61,.30)
   line(g,x-8*z,y-8*z,x+4*z,y-18*z,z)
   line(g,x+4*z,y-18*z,x+12*z,y-10*z,z)
  elseif k=="crystal" then
   g.setColor(.51,.87,.94,.95)
   g.polygon("fill",x-5*z,y-14*z,x+2*z,y-41*z,x+11*z,y-13*z,x+4*z,y-5*z)
  end
 end
 return k
end
return V
