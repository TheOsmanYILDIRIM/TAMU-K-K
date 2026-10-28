-- World-coordinate deterministic terrain IDs; no image blur, alpha blending,
-- palette tinting, or gameplay/World Builder mutations.
local Materials={}
local MOD=2147483647
local function hash(x,y,salt)
 return (x*73856093+y*19349663+x*y*83492791+(salt or 17041))%MOD
end
local function salt_of(name)
 local v=0
 for i=1,#name do v=(v*31+name:byte(i))%MOD end
 return v
end
local function smooth(t) return t*t*(3-2*t) end
local function noise(x,y,spacing,salt)
 local gx,gy=math.floor(x/spacing),math.floor(y/spacing)
 local tx,ty=smooth(x/spacing-gx),smooth(y/spacing-gy)
 local function value(ix,iy) return (hash(ix,iy,salt)%2001)/1000-1 end
 local a=value(gx,gy)*(1-tx)+value(gx+1,gy)*tx
 local b=value(gx,gy+1)*(1-tx)+value(gx+1,gy+1)*tx
 return a*(1-ty)+b*ty
end
-- Only changes the location of rendered material decisions by a few world
-- units. Continuous global coordinates => adjacent chunks share exact edges.
function Materials.edge_jitter(x,y,salt)
 local n=noise(x,y,19,salt or 1103)
 return n*2+noise(x,y,43,(salt or 1103)+31)*1.2
end
function Materials.region(x,y)
 local spacing=384
 local cx,cy=math.floor(x/spacing),math.floor(y/spacing)
 local closest,choice=math.huge,nil
 for dy=-1,1 do for dx=-1,1 do
  local gx,gy=cx+dx,cy+dy
  local h=hash(gx,gy,17041)
  local px=(gx+.19+.62*(h%997)/997)*spacing
  local py=(gy+.19+.62*(math.floor(h/997)%991)/991)*spacing
  local dist=(x-px)^2+(y-py)^2
  if dist<closest then closest=dist;choice=h end
 end end
 return choice
end
-- Old API retained for existing renderer/material regression.
function Materials.variant(family,x,y,variants)
 assert(type(family)=="string" and type(variants)=="number"
   and variants>=1 and variants==math.floor(variants))
 local region=Materials.region(x,y)
 return 1+(region+salt_of(family))%variants
end
function Materials.family(sample,near_water,x,y)
 if near_water then return "wetland" end
 if sample.feature=="path" then return "dirt" end
 local biome=sample.biome
 if biome=="forest" then
  -- Preserve sparse native understory, not dominant giant grass mosaics.
  if Materials.region(x,y)%11==0 and (sample.grade or 0)<.23 then return "grass" end
  return "forest"
 elseif biome=="rocky" then
  if Materials.region(x,y)%9==0 and (sample.grade or 0)<.23 then return "grass" end
  return "rock"
 end
 return "grass"
end
local function anchors(family,x,y,list,profiles)
 local spacing=240
 local gx,gy=math.floor(x/spacing),math.floor(y/spacing)
 local tx,ty=smooth(x/spacing-gx),smooth(y/spacing-gy)
 local salt=salt_of(family)
 local function sample(ix,iy)
  local index=1+hash(ix,iy,salt)%#list
  return assert(profiles[list[index].id],"missing CIELAB signature")
 end
 local a,b,c,d=sample(gx,gy),sample(gx+1,gy),
   sample(gx,gy+1),sample(gx+1,gy+1)
 local target={}
 for i=1,4 do
  target[i]=(a[i]*(1-tx)+b[i]*tx)*(1-ty)
    +(c[i]*(1-tx)+d[i]*tx)*ty
 end
 return target
end
-- Sorted genuine, source-PNG CIELAB means + L* standard deviation.
-- Bilinear variation chooses a *single* source ID; it never mixes pixels.
-- An optional neighboring family centre merely favors compatible edge IDs.
function Materials.choose(family,x,y,list,profiles,neighbor)
 assert(type(list)=="table" and #list>0 and type(profiles)=="table")
 local target=anchors(family,x,y,list,profiles)
 if neighbor then
  for k=1,4 do target[k]=target[k]*.72+neighbor[k]*.28 end
 end
 local best,score
 for i,a in ipairs(list) do
  local p=assert(profiles[a.id],"missing CIELAB signature: "..a.id)
  local dist=(p[1]-target[1])^2+(p[2]-target[2])^2+
    (p[3]-target[3])^2+.75*(p[4]-target[4])^2
  if not score or dist<score-1e-8 or
    (math.abs(dist-score)<1e-8 and a.id<best.id) then
   best,score=a,dist
  end
 end
 return best
end
function Materials.centres(families,profiles)
 local out={}
 for family,list in pairs(families) do
  if #list>0 and list[1].kind=="terrain" then
   local centre={0,0,0,0}
   for _,a in ipairs(list) do
    local p=assert(profiles[a.id],"missing terrain CIELAB profile")
    for i=1,4 do centre[i]=centre[i]+p[i]/#list end
   end
   out[family]=centre
  end
 end
 return out
end
return Materials
