-- Render-only authored water/bank/path surfaces (no collision or crossing edits).
-- Marching samples global coordinates so adjacent chunks share exact edge contours.
local Marching=require("world.marching")
local Iso=require("world.iso")
local Shore={}

local function intersects(chunk,features,kind,padding)
 if not features or type(features.features)~="table" then return false end
 for _,f in ipairs(features.features) do
  if f.kind==kind then
   local margin=(f.width or 0)/2+(padding or 0)
   for i=2,#f.points do
    local a,b=f.points[i-1],f.points[i]
    local x0=math.min(a[1],b[1])-margin
    local y0=math.min(a[2],b[2])-margin
    local x1=math.max(a[1],b[1])+margin
    local y1=math.max(a[2],b[2])+margin
    if x0<=chunk.x+chunk.size and x1>=chunk.x and
       y0<=chunk.y+chunk.size and y1>=chunk.y then return true end
   end
  end
 end
 return false
end
Shore.intersects=intersects

local function clamp(x) return math.max(0,math.min(1,x)) end
local function vertex(x,y,topography,scale,kind,signed)
 local px,py=Iso.project(x,y,topography:height(x,y)*scale)
 if kind=="water" then
  -- Near-bank turquoise, deeper channels blue-green. Static; no GPU shader.
  local depth=clamp(signed/15)
  local shallow=1-depth
  local edge=1-clamp(signed/5)
  local variation=.018*math.sin(x*.11+y*.075)
    +.012*math.cos(y*.17-x*.064)
  return {px,py,0,0,
   .105+shallow*.125+edge*.085+variation,
   .355+shallow*.17+edge*.08+variation,
   .44+shallow*.13+edge*.065,
   .96}
 elseif kind=="bank" then
  local near=clamp((signed+12)/14)
  return {px,py,0,0,.38,.405,.31,.12+near*.52}
 else
  return {px,py,0,0,.41,.33,.215,.66}
 end
end

local function project(vertices,topography,scale,kind,sampler)
 local out={}
 for _,p in ipairs(vertices or {}) do
  local x,y=p[1],p[2]
  local signed=kind=="path" and 0 or sampler(x,y)
  out[#out+1]=vertex(x,y,topography,scale,kind,signed)
 end
 assert(#out%3==0,"clipped layer is not triangular")
 return out
end

function Shore.build(chunk,query,topography,routes,scale)
 assert(chunk and chunk.size and query and query.water_mask
   and topography and topography.height,"authored geometry required")
 scale=scale or .35
 local features=routes and routes.features
 local is_river=intersects(chunk,features,"water",18)
 local is_path=intersects(chunk,features,"path",10)
 local water_sampler=function(x,y)
  local wet,signed=query:water_mask(x,y)
  assert(type(wet)=="boolean" and type(signed)=="number"
    and signed==signed and math.abs(signed)<math.huge,
    "nonfinite authoritative water scalar")
  return signed
 end
 local raw_water=(chunk.layers and chunk.layers.water
   and chunk.layers.water.vertices) or {}
 local bank,path={}
 if is_river then
  -- 4-unit edge fidelity; only chunks overlapping an actual authored river.
  local refined=Marching.build(water_sampler,chunk.x,chunk.y,
    chunk.size,4,0)
  raw_water=refined.vertices
  local outer=Marching.build(water_sampler,chunk.x,chunk.y,
    chunk.size,8,-12)
  bank=project(outer.vertices,topography,scale,"bank",water_sampler)
 end
 if is_path and features and type(features.signed)=="function" then
  local path_sampler=function(x,y) return features:signed(x,y,"path") end
  local out=Marching.build(path_sampler,chunk.x,chunk.y,
    chunk.size,8,0)
  path=project(out.vertices,topography,scale,"path",water_sampler)
 end
 return {path=path,bank=bank,
   water=project(raw_water,topography,scale,"water",water_sampler),
   refined=is_river,authored_path=is_path}
end
return Shore
