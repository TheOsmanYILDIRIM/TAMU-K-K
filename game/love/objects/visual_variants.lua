-- Presentation-only 14 nature variants for existing v1 tree/rock objects.
-- No new catalog IDs, drops, collision radii, save format or RNG mutation.
local V={}
local trees={"oak","birch","pine","maple","willow","berry_bush","fern","thorn_bush","cedar","cypress","redwood","acacia","aspen","cherry_blossom","dead_tree","reeds","lavender"}
local rocks={"boulder","ore_vein","crystal","fallen_log","stump","mushrooms","mossy_rock","granite","basalt","geode","amber_ore","slate","clover","wildflowers","toadstools"}
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
-- Extended authored silhouettes and micro-detail; visual-only and deterministic.
local tall_tree={cedar=true,cypress=true,redwood=true,acacia=true,aspen=true,
 cherry_blossom=true,dead_tree=true}
local rock_shapes={mossy_rock=true,granite=true,basalt=true,geode=true,
 amber_ore=true,slate=true}
local meadow_shapes={reeds=true,lavender=true,clover=true,wildflowers=true,toadstools=true}
local function ellipse(g,x,y,rx,ry,c)
 g.setColor(c[1],c[2],c[3],c[4] or 1);g.ellipse("fill",x,y,rx,ry)
end
local function branch(g,x,y,dx,dy,z,w)
 g.setLineWidth(math.max(1,w*z));g.line(x,y,x+dx*z,y+dy*z)
end
local function extended_draw(g,x,y,z,o,k,h)
 if tall_tree[k] then
  local high=(k=="redwood" and 99 or k=="cypress" and 84 or 70)*z
  local trunk=(k=="redwood" and 8 or 5)*z
  ellipse(g,x,y+2*z,21*z,7*z,{.06,.09,.07,.31})
  g.setColor(.27,.19,.13);g.polygon("fill",x-trunk,y,x-trunk*.66,y-high*.78,x+trunk*.55,y-high*.86,x+trunk,y)
  g.setColor(.48,.32,.20,.75);g.setLineWidth(math.max(1,z));g.line(x-2*z,y-4*z,x-2*z,y-high*.78)
  for i=1,5 do
   local yy=y-(12+i*12)*z
   branch(g,x,yy,((i%2==0) and 1 or -1)*(13+i*2),-8,z,3)
  end
  if k=="dead_tree" then
   for i=1,5 do local side=i%2==0 and 1 or -1
    branch(g,x+side*(11+i)*z,y-(18+i*12)*z,side*11,-9,z,2) end
  elseif k=="cypress" or k=="cedar" or k=="redwood" then
   local r=k=="cypress" and 16 or k=="redwood" and 23 or 30
   for i=1,5 do
    local yy=y-(25+i*12)*z
    local t=r*(1-(i-1)*.13)*z
    g.setColor(.11+i*.012,.27+i*.019,.17+i*.008)
    g.polygon("fill",x-t,yy,x,yy-(24+i*2)*z,x+t,yy)
    g.setColor(.34,.52,.32,.35);g.line(x-t*.55,yy-5*z,x,yy-(17+i)*z)
   end
  else
   local col=k=="cherry_blossom" and {.87,.55,.65} or
     k=="aspen" and {.45,.65,.30} or k=="acacia" and {.39,.55,.24} or {.27,.48,.27}
   local wide=k=="acacia" and 42 or 31
   for i=1,9 do
    local angle=i*2.399+h*.00019
    local xx=x+math.cos(angle)*wide*.68*z
    local yy=y-high+math.sin(angle)*15*z+11*z
    ellipse(g,xx+2*z,yy+5*z,18*z,12*z,{.09,.19,.12,.4})
    ellipse(g,xx,yy,18*z,11*z,col)
    ellipse(g,xx-4*z,yy-4*z,8*z,4*z,{math.min(1,col[1]+.13),math.min(1,col[2]+.12),math.min(1,col[3]+.10),.7})
   end
  end
 elseif rock_shapes[k] then
  local c=k=="basalt" and {.20,.24,.27} or k=="granite" and {.44,.43,.40} or
   k=="slate" and {.30,.39,.42} or {.36,.39,.35}
  ellipse(g,x,y+2*z,19*z,8*z,{.04,.06,.07,.28})
  local n=k=="slate" and 4 or 1
  for j=1,n do
   local off=(j-(n+1)/2)*7*z
   g.setColor(c[1],c[2],c[3])
   g.polygon("fill",x-21*z+off,y-4*z,x-12*z+off,y-22*z,x+2*z+off,y-34*z,x+21*z+off,y-12*z,x+14*z+off,y+1*z)
   g.setColor(c[1]+.12,c[2]+.11,c[3]+.10)
   g.polygon("fill",x-12*z+off,y-22*z,x+2*z+off,y-34*z,x+4*z+off,y-14*z)
  end
  if k=="mossy_rock" then
   for i=1,8 do local a=i*2.39+h*.001
    ellipse(g,x+math.cos(a)*12*z,y-15*z+math.sin(a)*8*z,5*z,3*z,{.21,.45,.23,.85}) end
  elseif k=="geode" or k=="amber_ore" then
   local col=k=="geode" and {.43,.74,.92} or {.95,.57,.19}
   for i=1,6 do local xx=x+(i-3.5)*5*z;local yy=y-(12+(i%3)*6)*z
    g.setColor(col[1],col[2],col[3]);g.polygon("fill",xx-4*z,yy,xx,y-(31+i%3*6)*z,xx+4*z,yy)
    g.setColor(1,1,1,.42);g.line(xx,y-(29+i%3*6)*z,xx-2*z,yy) end
  end
 elseif meadow_shapes[k] then
  ellipse(g,x,y+1*z,14*z,5*z,{.06,.1,.05,.22})
  local flower=k=="wildflowers" or k=="lavender" or k=="clover"
  for i=1,13 do
   local a=i*2.399+h*.0001
   local xx=x+math.cos(a)*(5+i%4*3)*z
   local yy=y+math.sin(a)*4*z
   local height=(k=="reeds" and 22 or k=="lavender" and 17 or 9)+(i%5)*2
   branch(g,xx,yy,math.sin(a)*2,-height,z,.9)
   if k=="reeds" then ellipse(g,xx,yy-height*z,2.1*z,6*z,{.57,.44,.23})
   elseif k=="toadstools" then
    ellipse(g,xx,yy-height*z,5*z,3*z,{.72,.20,.17})
    ellipse(g,xx-1*z,yy-(height+1)*z,1*z,1*z,{.95,.85,.65})
   elseif flower then
    local c=k=="lavender" and {.59,.38,.75} or k=="clover" and {.90,.85,.72} or
      (i%2==0 and {.94,.72,.32} or {.78,.42,.54})
    for j=0,3 do local t=j*1.5708
     ellipse(g,xx+math.cos(t)*2.5*z,yy-height*z+math.sin(t)*2.5*z,2.2*z,2*z,c) end
    ellipse(g,xx,yy-height*z,1.8*z,1.8*z,{.92,.77,.36})
   end
  end
 end
 return k
end

function V.draw(g,x,y,z,o,variant)
 local h=hash(o.id)
 local k=variant or V.variant(o)
 if tall_tree[k] or rock_shapes[k] or meadow_shapes[k] then
  return extended_draw(g,x,y,z,o,k,h)
 end
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
