-- Opt-in authored objects overlay. A's v1 map has no object anchors yet:
-- callers must provide validated, editor-assigned anchors explicitly.
-- This module never activates Stage6 persistence or changes generator v1.
local Base=require("objects.world")
local Defs=require("objects.definitions")
local Collision=require("physics.collision")
local M={};M.__index=M
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function intersect(o,b)
  return o.x+o.radius>=b.min_x and o.x-o.radius<=b.max_x and
    o.y+o.radius>=b.min_y and o.y-o.radius<=b.max_y
end
local function overlaps(a,b)
  return math.abs(a.x-b.x)<a.radius+b.radius+4 and
    math.abs(a.y-b.y)<a.radius+b.radius+4
end
local function valid_slug(s)
  return type(s)=="string" and #s>=2 and #s<=64 and s:match("^[a-z][a-z0-9%-]*$")~=nil
end
function M.new(query,water,map_id,anchors,options)
  assert(query and query.generator_version==1 and query.seed and type(query.sample)=="function")
  assert(water and type(water.obstacles)=="function")
  assert(type(map_id)=="string" and map_id:match("^worldmap:[a-z][a-z0-9%-]+$"),"invalid map id")
  assert(type(anchors)=="table","explicit anchors required")
  options=options or {}
  local base=Base.new(query,water)
  local self=setmetatable({base=base,placement=base.placement,seed=query.seed,
    generator_version=1,map_id=map_id,authored={},authored_by_id={},
    delta=base.delta,site_cache=base.site_cache,
    persistence_supported=false},M)
  local occupied={}
  for _,a in ipairs(anchors) do
    assert(type(a)=="table" and valid_slug(a.id) and type(a.region_id)=="string"
      and a.region_id:match("^region:[a-z][a-z0-9%-]+$")
      and finite(a.x) and finite(a.y) and math.abs(a.x)<=1000000 and math.abs(a.y)<=1000000,
      "invalid authored anchor")
    local id="worldobj:authored:v1:"..map_id:sub(10)..":"..a.id
    assert(not self.authored_by_id[id],"duplicate authored anchor id")
    local def=Defs.get(a.def_id)
    local surface=query:sample(a.x,a.y)
    assert(surface and surface.walkable and surface.feature~="path" and surface.feature~="water"
      and def.biomes[surface.biome],"authored surface incompatible")
    assert(Collision.can_stand(water,a.x,a.y,def.radius+4),"authored water collision")
    if options.region_at then
      assert(options.region_at(a.x,a.y)==a.region_id,"anchor outside declared region")
    end
    if options.protected then
      assert(not options.protected(a.x,a.y,def.radius),"authored protected-area collision")
    end
    local o={id=id,def_id=a.def_id,kind=def.kind,x=a.x,y=a.y,radius=def.radius,
      region_id=a.region_id,anchor_id=a.id,cx=math.floor(a.x/256),cy=math.floor(a.y/256)}
    for _,p in ipairs(occupied) do assert(not overlaps(o,p),"authored object collision") end
    occupied[#occupied+1]=o
    self.authored_by_id[id]=o
    self.authored[#self.authored+1]=o
  end
  table.sort(self.authored,function(a,b) return a.id<b.id end)
  return self
end
function M:site(gx,gy)
  local p=self.base:site(gx,gy)
  if not p then return nil end
  for _,a in ipairs(self.authored) do
    if overlaps(p,a) then return nil end
  end
  return p
end
function M:get(id)
  if type(id)~="string" then return nil end
  if self.authored_by_id[id] then return self.authored_by_id[id] end
  local p=self.base:get(id)
  if not p then return nil end
  for _,a in ipairs(self.authored) do if overlaps(p,a) then return nil end end
  return p
end
function M:objects_in(bounds,include_depleted)
  -- Base validates bounds and budget, including negative coordinates.
  local procedural=self.base:objects_in(bounds,include_depleted)
  local out={}
  for _,p in ipairs(procedural) do
    local blocked=false
    for _,a in ipairs(self.authored) do
      if overlaps(p,a) then blocked=true;break end
    end
    if not blocked then out[#out+1]=p end
  end
  for _,a in ipairs(self.authored) do
    if intersect(a,bounds) and (include_depleted or not self:is_depleted(a.id)) then
      out[#out+1]=a
    end
  end
  table.sort(out,function(a,b) return a.id<b.id end)
  return out
end
function M:obstacles(x1,y1,x2,y2)
  local out={}
  for _,o in ipairs(self:objects_in({min_x=x1,min_y=y1,max_x=x2,max_y=y2})) do
    out[#out+1]={x=o.x-o.radius,y=o.y-o.radius,w=o.radius*2,h=o.radius*2,id=o.id}
  end
  return out
end
function M:is_depleted(id)
  if self.authored_by_id[id] then
    local d=self.delta[id]
    return d~=nil and d.depleted==true
  end
  return self.base:is_depleted(id)
end
function M:deplete(id)
  if not self.authored_by_id[id] then return self.base:deplete(id) end
  if self:is_depleted(id) then return false,"depleted" end
  self.delta[id]={depleted=true}
  return true
end
function M:export_delta()
  -- Stage6 save_v2 importer accepts only legacy generated IDs.
  -- Never silently serialize authored instances to an incompatible save.
  for id in pairs(self.delta) do
    if self.authored_by_id[id] then
      error("authored persistence requires explicit Stage6 migration/adapter")
    end
  end
  return self.base:export_delta()
end
return M
