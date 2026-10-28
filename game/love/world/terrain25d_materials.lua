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
 -- Keep the authoritative biome as the PRIMARY material everywhere.
 -- A previous 384-unit Voronoi %11/%9 assigned entire forest/rock patches
 -- to grass, creating the visible hard-edged circular clearing.
 if sample.biome=="forest" then return "forest" end
 if sample.biome=="rocky" then return "rock" end
 return "grass"
end

local function clamp(v) return math.max(0,math.min(1,v)) end

-- Diffuse visually by original source-ID area coverage, NOT by pixel blur.
-- Broad fields control the density of numerous tiny islands rather than
-- assigning an entire 384-unit Voronoi polygon to an unrelated biome.
function Materials.understory_coverage(family,x,y)
 if family~="forest" and family~="rock" then return 0 end
 local field=.62*noise(x,y,210,6301)+.38*noise(x,y,97,4223)
 local envelope=clamp((field+.17)/.62)
 local coverage=.035+.55*envelope^1.6
 if family=="rock" then return coverage*.28 end
 return coverage
end

local function micro_rank(x,y,spacing,salt)
 local gx,gy=math.floor(x/spacing),math.floor(y/spacing)
 local closest,rank=math.huge,1
 for oy=-1,1 do for ox=-1,1 do
  local ix,iy=gx+ox,gy+oy
  local h=hash(ix,iy,salt)
  local px=(ix+.16+.68*(h%997)/997)*spacing
  local py=(iy+.16+.68*(math.floor(h/997)%991)/991)*spacing
  local d=(x-px)^2+(y-py)^2
  if d<closest then
   closest=d
   rank=hash(ix*3+17,iy*7-11,salt+35010)%65521/65521
  end
 end end
 return rank
end

function Materials.interior_family(family,x,y)
 local density=Materials.understory_coverage(family,x,y)
 if density>0 and micro_rank(x,y,12,14921)<density then
  return "grass",family,density
 end
 return family,nil,0
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
function Materials.choose(family,x,y,list,profiles,neighbor,neighbor_weight)
 assert(type(list)=="table" and #list>0 and type(profiles)=="table")
 local target=anchors(family,x,y,list,profiles)
 if neighbor then
  local weight=neighbor_weight or .28
  assert(weight>=0 and weight<=1,"invalid material-neighbor selection weight")
  -- The original source PNG is not tinted. Near authored borders, choose
  -- genuinely closer light-forest/dark-grass source variants instead.
  for k=1,4 do target[k]=target[k]*(1-weight)+neighbor[k]*weight end
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
-- Cross-biome transition uses categorical source texture coverage, NEVER
-- image-space blur, alpha blending or color-tint interpolation. World Builder's
-- authored polygon outlines remain unchanged for all gameplay queries.
local biome_family={meadow="grass",forest="forest",rocky="rock"}
local TRANSITION_REACH=156
function Materials.boundaries(query,map)
 local edges={}
 if not (map and type(map.regions)=="table") then return edges end
 assert(query and type(query.sample)=="function")
 for _,region in ipairs(map.regions) do
  for i=1,#region.polygon do
   local a,b=region.polygon[i],region.polygon[i%#region.polygon+1]
   local dx,dy=b[1]-a[1],b[2]-a[2]
   local length=math.sqrt(dx*dx+dy*dy)
   if length>1e-6 then
    local nx,ny=-dy/length,dx/length
    -- Determine actual neighbouring biome on each side; two authored
    -- forest polygons sharing an edge must NOT create a transition.
    local mx,my=(a[1]+b[1])*.5,(a[2]+b[2])*.5
    local plus=biome_family[query:sample(mx+nx*7,my+ny*7).biome]
    local minus=biome_family[query:sample(mx-nx*7,my-ny*7).biome]
    if plus and minus and plus~=minus then
     edges[#edges+1]={
       ax=a[1],ay=a[2],dx=dx,dy=dy,length2=length*length,
       plus=plus,minus=minus,
       minx=math.min(a[1],b[1])-TRANSITION_REACH,
       maxx=math.max(a[1],b[1])+TRANSITION_REACH,
       miny=math.min(a[2],b[2])-TRANSITION_REACH,
       maxy=math.max(a[2],b[2])+TRANSITION_REACH
     }
    end
   end
  end
 end
 return edges
end

-- Evaluated once per 32-unit surface cell, not for every triangle.
-- No circular patches: the band follows each validated authored edge.
function Materials.nearest_boundary(edges,x,y)
 local best,limit=nil,TRANSITION_REACH*TRANSITION_REACH
 for _,edge in ipairs(edges) do
  if x>=edge.minx and x<=edge.maxx
     and y>=edge.miny and y<=edge.maxy then
   local t=((x-edge.ax)*edge.dx+(y-edge.ay)*edge.dy)/edge.length2
   t=math.max(0,math.min(1,t))
   local dx,dy=x-edge.ax-t*edge.dx,y-edge.ay-t*edge.dy
   local dist2=dx*dx+dy*dy
   if dist2<limit then limit,best=dist2,edge end
  end
 end
 return best,best and math.sqrt(limit) or nil
end

-- Crisp, spatially coherent interleaving of *whole source material IDs*.
-- The outer 112-unit band gains small foreign-family islands that grow
-- in coverage toward the authored boundary, then gradually disappear
-- on the other side. No wide alpha brush or pseudo-blurred RGB pixels.
function Materials.interleaved_family(family,edge,x,y)
 if not edge or (family~=edge.plus and family~=edge.minus) then
  return family,nil,0
 end
 local alternate=family==edge.plus and edge.minus or edge.plus
 local t=((x-edge.ax)*edge.dx+(y-edge.ay)*edge.dy)/edge.length2
 t=math.max(0,math.min(1,t))
 local ex,ey=edge.ax+t*edge.dx,edge.ay+t*edge.dy
 local dist=math.sqrt((x-ex)^2+(y-ey)^2)
 -- Distance-weighted source-ID coverage; both sides approach the SAME
 -- distribution at the authored border, without touching the real biome.
 local drift=14*noise(x,y,52,9247)+5*noise(x,y,21,3141)
 local width=126+20*noise(x,y,135,6271)
 local reach=math.max(0,math.min(1,1-math.max(0,dist+drift)/width))
 if reach==0 then return family,alternate,0 end
 local foreign=.42*reach^0.8
 local earth=.16*reach^1.25
 -- 11-unit jittered Voronoi micro-islands: each area has exactly ONE
 -- original source PNG's pixels. No Gaussian blur, RGB blend or tint.
 -- Wider biome-scale gradients come from the fraction of source-ID areas.
 local spacing=11
 local gx,gy=math.floor(x/spacing),math.floor(y/spacing)
 local closest,rank=math.huge,1
 for oy=-1,1 do for ox=-1,1 do
  local ix,iy=gx+ox,gy+oy
  local h=hash(ix,iy,57121)
  local px=(ix+.16+.68*(h%997)/997)*spacing
  local py=(iy+.16+.68*(math.floor(h/997)%991)/991)*spacing
  local d=(x-px)^2+(y-py)^2
  if d<closest then
   closest=d
   rank=hash(ix*3+17,iy*7-11,92131)%65521/65521
  end
 end end
 if rank<earth then return "dirt",alternate,reach end
 if rank<earth+foreign then return alternate,family,reach end
 return family,alternate,reach
end
return Materials
