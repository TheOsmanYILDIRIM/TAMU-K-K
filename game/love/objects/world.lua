-- Immutable seed world + sparse mutable delta, independent of chunk residency.
local Placement=require("objects.placement")
local W={};W.__index=W
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function W.new(query,water)
  return setmetatable({seed=query.seed,placement=Placement.new(query,water),
    delta={},site_cache={},cache_size=0,max_cache=4096},W)
end
function W:site(gx,gy)
  local key=gx..":"..gy
  local cached=self.site_cache[key]
  if cached~=nil then return cached~=false and cached or nil end
  local obj=self.placement:at(gx,gy)
  if self.cache_size>=self.max_cache then self.site_cache={};self.cache_size=0 end
  self.site_cache[key]=obj or false
  self.cache_size=self.cache_size+1
  return obj
end
function W:get(id)
  if type(id)~="string" then return nil end
  local seed,gx,gy=id:match("^worldobj:v1:(%d+):(-?%d+):(-?%d+)$")
  if not seed or tonumber(seed)~=self.seed then return nil end
  local obj=self:site(tonumber(gx),tonumber(gy))
  if obj and obj.id==id then return obj end
end
function W:objects_in(bounds,include_depleted)
  assert(type(bounds)=="table" and finite(bounds.min_x) and finite(bounds.min_y)
    and finite(bounds.max_x) and finite(bounds.max_y)
    and bounds.min_x<=bounds.max_x and bounds.min_y<=bounds.max_y,
    "invalid object bounds")
  local s=self.placement.spacing
  local ax=math.floor(bounds.min_x/s)-1
  local ay=math.floor(bounds.min_y/s)-1
  local bx=math.floor(bounds.max_x/s)+1
  local by=math.floor(bounds.max_y/s)+1
  assert((bx-ax+1)*(by-ay+1)<=4096,"object query budget exceeded")
  local out={}
  for gy=ay,by do for gx=ax,bx do
    local o=self:site(gx,gy)
    if o and (include_depleted or not self.delta[o.id] or not self.delta[o.id].depleted)
      and o.x+o.radius>=bounds.min_x and o.x-o.radius<=bounds.max_x
      and o.y+o.radius>=bounds.min_y and o.y-o.radius<=bounds.max_y then
      out[#out+1]=o
    end
  end end
  return out
end
function W:obstacles(x1,y1,x2,y2)
  local result={}
  for _,o in ipairs(self:objects_in({min_x=x1,min_y=y1,max_x=x2,max_y=y2})) do
    result[#result+1]={x=o.x-o.radius,y=o.y-o.radius,
      w=o.radius*2,h=o.radius*2,id=o.id}
  end
  return result
end
function W:deplete(id)
  local obj=self:get(id)
  if not obj then return false,"missing_object" end
  if self.delta[id] and self.delta[id].depleted then return false,"depleted" end
  self.delta[id]={depleted=true}
  return true
end
function W:is_depleted(id) return self.delta[id] and self.delta[id].depleted or false end
function W:export_delta()
  local copy={version=1,seed=self.seed,objects={}}
  for id,state in pairs(self.delta) do copy.objects[id]={depleted=state.depleted==true} end
  return copy
end
return W
