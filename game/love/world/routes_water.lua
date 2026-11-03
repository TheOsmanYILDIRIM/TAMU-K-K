-- R2 C: opt-in world-space water/path/traversal facade.
-- The production WorldQuery/player/terrain renderer are deliberately unchanged.
local Liquids = require("world.liquids")
local M = {}
M.__index = M
local function finite(n)
  return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
local function coords(x,y)
  assert(finite(x) and finite(y),"nonfinite world-space coordinates")
end
local function position(p)
  assert(type(p)=="table" and finite(p.x) and finite(p.y),
    "route requires {x=...,y=...} world coordinates")
end
local function copy(t)
  local r={} for k,v in pairs(t) do r[k]=v end return r
end
local function flow(topography,hit)
  if not hit then return {status="procedural_unknown"} end
  local points=hit.feature.points
  local first,last=points[1],points[#points]
  local start_height=topography:height(first[1],first[2])
  local end_height=topography:height(last[1],last[2])
  if math.abs(start_height-end_height)<=1e-9 then
    return {status="no_overall_drop"}
  end
  local direction=start_height>end_height and 1 or -1
  local a,b=points[hit.segment_index],points[hit.segment_index+1]
  local ha,hb=topography:height(a[1],a[2]),topography:height(b[1],b[2])
  local drop=(ha-hb)*direction
  if drop< -1e-9 then return {status="slope_conflict"} end
  if drop<=1e-9 then return {status="level_segment"} end
  local dx,dy=b[1]-a[1],b[2]-a[2]
  local length=math.sqrt(dx*dx+dy*dy)
  return {status="downhill",x=direction*dx/length,
    y=direction*dy/length,grade=drop/length}
end
function M.new(base,features,options)
  options=options or {}
  assert(type(options)=="table"
    and type(base)=="table" and base.generator_version==1
    and finite(base.seed) and type(base.sample)=="function"
    and type(base.get_obstacles)=="function"
    and type(base.field)=="table" and type(base.field.channel)=="function"
    and type(features)=="table" and type(features.at)=="function"
    and type(features.signed)=="function"
    and type(features.resolve_crossings)=="function"
    and features.seed==base.seed and features.generator_version==1,
    "validated Generator v1 and authored feature facade required")
  local topography=options.topography
  assert(type(topography)=="table" and type(topography.height)=="function"
    and type(topography.transition)=="function",
    "B topography height/transition API required")
  local max_depth=options.water_max_depth or 2
  local ford_limit=options.ford_max_depth or 0.75
  local preference=options.path_cost_factor or 0.85
  local stride=options.route_stride or 2
  assert(finite(max_depth) and max_depth>0 and max_depth<=20
    and finite(ford_limit) and ford_limit>0 and ford_limit<=20
    and finite(preference) and preference>0 and preference<=1
    and finite(stride) and stride>0 and stride<=16,
    "invalid hydrology parameters")
  -- Existing player water contract is immutable in this optional implementation.
  local wet=Liquids.for_feature("water")
  assert(wet.speed_multiplier==0.55 and wet.immersion==0.5,
    "existing liquid traversal contract changed")
  local crossings=features:resolve_crossings(options.sites or {},
    options.crossings or {},max_depth,ford_limit)
  local self=setmetatable({base=base,features=features,topography=topography,
    water_max_depth=max_depth,ford_max_depth=ford_limit,
    path_cost_factor=preference,route_stride=stride,crossings=crossings,
    generator_version=1,seed=base.seed,map_id=features.map_id},M)
  local field={}
  function field:channel(x,y,name)
    if name=="water" then return self._owner:water_scalar(x,y) end
    return base.field:channel(x,y,name)
  end
  field._owner=self
  self.field=field
  return self
end

function M:water_scalar(x,y)
  coords(x,y)
  local baseline=self.base.field:channel(x,y,"water")
  assert(finite(baseline),"invalid Generator v1 water field")
  return math.max(baseline,self.features:signed(x,y,"water"))
end
function M:water_mask(x,y)
  local signed=self:water_scalar(x,y)
  return signed>0,signed
end
function M:crossing_at(x,y)
  coords(x,y)
  for _,c in ipairs(self.crossings) do
    local dx,dy=x-c.x,y-c.y
    local along=dx*c.tx+dy*c.ty
    local lateral=math.abs(-dx*c.ty+dy*c.tx)
    if lateral<c.width/2 and
      math.abs(along)<c.length/2 then
      return c
    end
  end
  return nil
end

function M:_surface(x,y)
  coords(x,y)
  local water,signed=self:water_mask(x,y)
  local path=self.features:at(x,y,"path")
  local stream=self.features:at(x,y,"water")
  local crossing=water and self:crossing_at(x,y) or nil
  local on_deck=crossing and crossing.kind=="bridge"
  local wet=water and not on_deck
  local depth
  if water and stream then
    local fraction=math.max(0,math.min(1,stream.distance/(stream.width/2)))
    depth=self.water_max_depth*(1-fraction*fraction)
  end
  local liquid=Liquids.for_feature(wet and "water" or "path")
  local current=water and flow(self.topography,stream) or nil
  return {id=liquid.id,speed_multiplier=liquid.speed_multiplier,
    immersion=liquid.immersion,water_body=water,wet=wet,
    water_signed=signed,water_depth=depth,
    water_feature_id=stream and stream.id or nil,
    path_feature_id=path and path.id or nil,
    crossing_id=crossing and crossing.id or nil,
    crossing_kind=crossing and crossing.kind or nil,
    current=current}
end

function M:surface_at(x,y)
  return self:_surface(x,y)
end
function M:sample(x,y)
  local baseline=self.base:sample(x,y)
  assert(type(baseline)=="table","missing baseline WorldQuery sample")
  local surface=self:_surface(x,y)
  local result=copy(baseline)
  if surface.wet then result.feature="water"
  elseif surface.crossing_kind=="bridge" or surface.path_feature_id then
    result.feature="path"
  elseif surface.water_body then result.feature="water" end
  -- No fabricated depth or flow for pure Generator-v1 water.
  result.water_depth=surface.water_depth
  result.water_flow=surface.current
  result.path_feature_id=surface.path_feature_id
  result.water_feature_id=surface.water_feature_id
  result.crossing_id=surface.crossing_id
  return result
end
function M:get_feature(x,y) return self:sample(x,y).feature end
function M:get_biome(x,y) return self:sample(x,y).biome end
function M:get_height(x,y) return self.base:get_height(x,y) end
function M:is_walkable(x,y) return self.base:is_walkable(x,y) end
function M:get_obstacles(bounds) return self.base:get_obstacles(bounds) end

-- Advisory navigation cost only. Collision/player integration belongs to coordinator.
-- No made-up current velocity; B grades and unchanged 0.55 wet speed drive cost.
function M:route_cost(a,b)
  position(a);position(b)
  local transition=self.topography:transition(a.x,a.y,b.x,b.y)
  assert(type(transition)=="table" and type(transition.walkable)=="boolean",
    "invalid B topography transition")
  if not transition.walkable then
    return {walkable=false,cost=math.huge,reason=transition.reason or "cliff"}
  end
  local multiplier=transition.speed_multiplier
  assert(finite(multiplier) and multiplier>0 and multiplier<=1,
    "invalid B terrain speed multiplier")
  local dx,dy=b.x-a.x,b.y-a.y
  local length=math.sqrt(dx*dx+dy*dy)
  if length==0 then return {walkable=true,cost=0,length=0,reason="stationary"} end
  local n=math.max(1,math.ceil(length/self.route_stride))
  assert(n<=4096,"route query sampling budget exceeded")
  local cost=0
  for i=1,n do
    local t=(i-0.5)/n
    local s=self:surface_at(a.x+dx*t,a.y+dy*t)
    local factor=s.wet and (1/Liquids.definitions.water.speed_multiplier)
      or ((s.path_feature_id or s.crossing_kind=="bridge")
        and self.path_cost_factor or 1)
    cost=cost+(length/n)*factor/multiplier
  end
  return {walkable=true,cost=cost,length=length,reason="passable"}
end

function M:flow_report()
  local result={}
  for _,f in ipairs(self.features.features) do if f.kind=="water" then
    local counts={downhill=0,level_segment=0,slope_conflict=0,
      no_overall_drop=0}
    for i=1,#f.points-1 do
      local hit={feature=f,segment_index=i}
      local status=flow(self.topography,hit).status
      counts[status]=counts[status]+1
    end
    local status
    if counts.slope_conflict>0 then status="conflict"
    elseif counts.no_overall_drop>0 then status="no_overall_drop"
    else status="consistent" end
    result[#result+1]={feature_id=f.id,status=status,segments=#f.points-1,
      conflict_segments=counts.slope_conflict,level_segments=counts.level_segment}
  end end
  return result
end
function M:crossing_diagnostics(sites)
  assert(type(sites)=="table","sites required")
  local report={}
  for _,site in ipairs(sites) do if site.role=="crossing" then
    local detail=self.features:crossing_site_status(site)
    report[#report+1]={site_id=site.id,valid=detail.valid,
      reason=detail.reason,water_bank_gap=detail.water_bank_gap}
  end end
  table.sort(report,function(a,b) return a.site_id<b.site_id end)
  return report
end
return M
