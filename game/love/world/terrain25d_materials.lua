-- Deterministic irregular large-area material variation; render-only.
-- Continuous in world coordinates, independent of chunk origin and load order.
local Materials={}
local MOD=2147483647
local function seed(x,y)
 return (x*73856093+y*19349663+x*y*83492791+17041)%MOD
end
function Materials.region(x,y)
 local spacing=384
 local cx,cy=math.floor(x/spacing),math.floor(y/spacing)
 local closest,choice=math.huge,nil
 -- Jittered Voronoi boundaries replace prior rigid rectangular 384px patches.
 for dy=-1,1 do for dx=-1,1 do
  local gx,gy=cx+dx,cy+dy
  local h=seed(gx,gy)
  local px=(gx+.19+.62*(h%997)/997)*spacing
  local py=(gy+.19+.62*(math.floor(h/997)%991)/991)*spacing
  local dist=(x-px)^2+(y-py)^2
  if dist<closest then
   closest=dist
   choice=h
  end
 end end
 return choice
end
function Materials.variant(family,x,y,variants)
 assert(type(family)=="string" and type(variants)=="number"
   and variants>=1 and variants==math.floor(variants))
 local region=Materials.region(x,y)
 local sum=0
 for i=1,#family do sum=(sum*31+family:byte(i))%MOD end
 return 1+(region+sum)%variants
end
function Materials.family(sample,near_water,x,y)
 if near_water then return "wetland" end
 if sample.feature=="path" then return "dirt" end
 local biome=sample.biome
 -- Visual-only grassy understory patches in forests and rock clearings.
 -- Does not alter biome, collision, ecology or authored World Builder rules.
 if biome=="forest" then
  local r=Materials.region(x,y)%13
  if r==0 and (sample.grade or 0)<.23 then return "grass" end
  return "forest"
 elseif biome=="rocky" then
  if Materials.region(x,y)%17==0 and (sample.grade or 0)<.19 then
   return "grass"
  end
  return "rock"
 end
 return "grass"
end
return Materials
