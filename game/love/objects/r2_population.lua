-- Round 2 E: explicit, opt-in hybrid ecology overlay for validated authored maps.
-- No main.lua wiring, catalog mutation, Stage6 migration or Generator v1 change.
local Base=require("objects.authored_population")
local Defs=require("objects.definitions")
local Collision=require("physics.collision")
local M={}; M.__index=M
local weights={
 meadow={["core:oak_tree"]=0.78,["core:stone_rock"]=0.85},
 forest={["core:oak_tree"]=1},
 rocky={["core:stone_rock"]=1}
}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function dist2(x,y,a,b) return (x-a)^2+(y-b)^2 end
local function segment_dist2(x,y,a,b)
 local vx,vy=b[1]-a[1],b[2]-a[2]
 local d=vx*vx+vy*vy
 if d==0 then return dist2(x,y,a[1],a[2]) end
 local t=math.max(0,math.min(1,((x-a[1])*vx+(y-a[2])*vy)/d))
 return dist2(x,y,a[1]+t*vx,a[2]+t*vy)
end
local function bucket(id)
 local h=7
 for i=1,#id do h=(h*31+id:byte(i))%1000003 end
 return h/1000003
end
local function role_radius(role)
 if role=="spawn" then return 48 end
 if role=="crossroads" or role=="crossing" or role=="pass" then return 26 end
 return 20
end
local function valid_point(x,y) return finite(x) and finite(y) and math.abs(x)<=1000000 and math.abs(y)<=1000000 end
local function site_valid(site)
 return type(site)=="table" and type(site.id)=="string" and
  site.id:match("^site:[a-z][a-z0-9%-]+$") and
  type(site.region_id)=="string" and site.region_id:match("^region:[a-z][a-z0-9%-]+$") and
  type(site.anchor)=="table" and valid_point(site.anchor[1],site.anchor[2]) and
  type(site.role)=="string"
end
function M:_protected(x,y,r,ignore_zones)
 for _,s in ipairs(self.sites) do
  if dist2(x,y,s.anchor[1],s.anchor[2]) < (role_radius(s.role)+r)^2 then
   return true,"site_protection"
  end
 end
 for _,route in ipairs(self.corridors) do
  for i=2,#route.points do
   if segment_dist2(x,y,route.points[i-1],route.points[i]) <
    (route.width/2+r+4)^2 then return true,"route_protection" end
  end
 end
 if not ignore_zones then
  for _,zone in ipairs(self.build_zones) do
   if dist2(x,y,zone.x,zone.y)<(zone.radius+r)^2 then
    return true,"building_clearance"
   end
  end
 end
 return false
end
local function eligible(self,def_id,x,y,region_id,occupied)
 local def=Defs.get(def_id)
 if self.region_at(x,y)~=region_id then return false end
 local s=self.query:sample(x,y)
 if not s or not s.walkable or s.feature=="path" or s.feature=="water" or not def.biomes[s.biome] then return false end
 if not Collision.can_stand(self.water,x,y,def.radius+4) then return false end
 if self:_protected(x,y,def.radius) then return false end
 for _,a in ipairs(occupied) do
  local prev=Defs.get(a.def_id)
  if dist2(x,y,a.x,a.y)<(def.radius+prev.radius+8)^2 then return false end
 end
 return true
end
local function starter(self,spawn)
 local anchors={}
 -- Fixed search order, independent of RNG, table order and chunk residency.
 for _,kind in ipairs({{"starter-tree","core:oak_tree"},{"starter-rock","core:stone_rock"}}) do
  local found=false
  for _,radius in ipairs({72,96,120,144}) do
   if found then break end
   for n=0,15 do
    local angle=n*math.pi/8
    local x=math.floor(spawn.anchor[1]+radius*math.cos(angle)+0.5)
    local y=math.floor(spawn.anchor[2]+radius*math.sin(angle)+0.5)
    if eligible(self,kind[2],x,y,spawn.region_id,anchors) then
     anchors[#anchors+1]={id=kind[1],region_id=spawn.region_id,
      x=x,y=y,def_id=kind[2]}
     found=true
     break
    end
   end
  end
  assert(found,"R2 starter resource unavailable: "..kind[2]..
   " (validated terrain/region adapter required)")
 end
 return anchors
end
function M.new(query,water,config)
 assert(query and query.generator_version==1 and query.seed==20261018 and
  type(query.sample)=="function","R2 requires generator v1 seed 20261018")
 assert(water and type(water.obstacles)=="function","water adapter required")
 assert(type(config)=="table" and config.map_id=="worldmap:fisilti-ormani" and
  type(config.region_at)=="function","validated R2 region mapping required")
 assert(type(config.sites)=="table" and #config.sites>=1,"R2 sites required")
 local self=setmetatable({query=query,water=water,region_at=config.region_at,
  sites=config.sites,corridors=config.corridors or {},build_zones=config.build_zones or {},
  day=0,renewal={},tree_regrow_days=config.tree_regrow_days or 3,persistence_supported=false},M)
 assert(type(self.tree_regrow_days)=="number" and self.tree_regrow_days==math.floor(self.tree_regrow_days)
  and self.tree_regrow_days>=1 and self.tree_regrow_days<=365,"invalid renewable duration")
 local seen,spawn={},nil
 for _,s in ipairs(self.sites) do
  assert(site_valid(s) and not seen[s.id],"invalid or duplicate R2 site")
  assert(self.region_at(s.anchor[1],s.anchor[2])==s.region_id,
   "site outside region")
  seen[s.id]=true
  if s.id=="site:fisilti-uyanis" then
   assert(s.role=="spawn","invalid R2 starter site role")
   spawn=s
  end
 end
 assert(spawn,"R2 starter site missing")
 for _,route in ipairs(self.corridors) do
  assert(type(route)=="table" and finite(route.width) and route.width>0
   and type(route.points)=="table" and #route.points>=2,"invalid route")
  for _,p in ipairs(route.points) do
   assert(type(p)=="table" and valid_point(p[1],p[2]),"invalid route point")
  end
 end
 for _,z in ipairs(self.build_zones) do
  assert(type(z)=="table" and valid_point(z.x,z.y) and finite(z.radius)
   and z.radius>0,"invalid construction zone")
 end
 -- Opt-in population only: the manifest sites themselves are never objects.
 local anchors=config.starter_resources and starter(self,spawn) or {}
 if config.anchors then
  for _,a in ipairs(config.anchors) do anchors[#anchors+1]=a end
 end
 self.base=Base.new(query,water,config.map_id,anchors,{
  region_at=self.region_at,
  protected=function(x,y,r)
   -- Generated starter sites use the same route/POI/building exclusion.
   return self:_protected(x,y,r)
  end
 })
 self.authored=self.base.authored
 self.delta=self.base.delta
 self.generator_version=1
 self.seed=query.seed
 return self
end
function M:_visible(o)
 if not o then return false end
 if self:_protected(o.x,o.y,o.radius) then return false end
 if o.anchor_id then return true end
 if not self.region_at(o.x,o.y) then return true end -- generator unchanged outside authored regions
 local surface=self.query:sample(o.x,o.y)
 local w=weights[surface.biome] and weights[surface.biome][o.def_id]
 return w~=nil and bucket(o.id)<w
end
function M:site(gx,gy)
 local o=self.base:site(gx,gy)
 if self:_visible(o) then return o end
 return nil
end
function M:get(id)
 local o=self.base:get(id)
 if self:_visible(o) then return o end
 return nil
end
function M:is_depleted(id)
 local record=self.renewal[id]
 if record then return self.day-record.depleted_day<self.tree_regrow_days end
 return self.base:is_depleted(id)
end
function M:deplete(id)
 local o=self:get(id)
 if not o then return false,"missing_object" end
 if self:is_depleted(id) then return false,"depleted" end
 local record=self.renewal[id]
 if record then
  record.depleted_day=self.day
  return true
 end
 local ok,reason=self.base:deplete(id)
 if not ok then return ok,reason end
 -- Trees only, in authored areas, regrow after configured explicit gameplay days.
 -- Rocks and unspecified future rare definitions remain finite.
 if o.def_id=="core:oak_tree" and self.region_at(o.x,o.y) then
  self.renewal[id]={depleted_day=self.day}
 end
 return true
end
function M:advance_day(day)
 assert(finite(day) and day==math.floor(day) and day>=self.day and day<2147483647,
  "game day must advance monotonically")
 self.day=day
end
function M:objects_in(bounds,include_depleted)
 local raw=self.base:objects_in(bounds,true)
 local out={}
 for _,o in ipairs(raw) do
  if self:_visible(o) and (include_depleted or not self:is_depleted(o.id)) then
   out[#out+1]=o
  end
 end
 return out -- already sorted by base, identity order preserved
end
function M:obstacles(x1,y1,x2,y2)
 local out={}
 for _,o in ipairs(self:objects_in({min_x=x1,min_y=y1,max_x=x2,max_y=y2})) do
  out[#out+1]={x=o.x-o.radius,y=o.y-o.radius,w=o.radius*2,h=o.radius*2,id=o.id}
 end
 return out
end
function M:can_build(x,y,r)
 assert(valid_point(x,y) and finite(r) and r>0,"invalid building footprint")
 local within=false
 for _,z in ipairs(self.build_zones) do
  if dist2(x,y,z.x,z.y)<=(z.radius-r)^2 and z.radius>=r then within=true end
 end
 if not within then return false,"outside_build_area" end
 if self:_protected(x,y,r,true) then return false,"protected_route_or_site" end
 local s=self.query:sample(x,y)
 if not s or not s.walkable or s.feature=="water" or s.feature=="path" or
  not Collision.can_stand(self.water,x,y,r) then return false,"unsafe_surface" end
 for _,o in ipairs(self:objects_in({min_x=x-r-32,min_y=y-r-32,
  max_x=x+r+32,max_y=y+r+32})) do
  if dist2(x,y,o.x,o.y)<(r+o.radius+4)^2 then return false,"occupied" end
 end
 return true
end
-- Pure authoring reservations for scarce discovery nodes; NOT loot or worldobj IDs.
-- R2 ruin, pass and vantage anchors are opportunities, never auto-spawned resources.
function M.rare_slots(sites)
 assert(type(sites)=="table","rare slots need validated sites")
 local slots,seen={},{}
 local roles={ruin=true,pass=true,vista=true}
 for _,s in ipairs(sites) do
  assert(site_valid(s) and not seen[s.id],"invalid rare POI")
  seen[s.id]=true
  if roles[s.role] then
   slots[#slots+1]={id="rare-slot:"..s.id:sub(6),site_id=s.id,
    region_id=s.region_id,anchor={s.anchor[1],s.anchor[2]},policy="finite"}
  end
 end
 table.sort(slots,function(a,b) return a.id<b.id end)
 return slots
end
function M:rare_status(def_id)
 -- A future rare resource requires a canonical catalog definition and explicit
 -- authored anchor. Never fabricate loot/recipe IDs in this agent.
 local ok=pcall(Defs.get,def_id)
 if not ok then return false,"catalog_definition_required" end
 return false,"authored_rare_anchor_required"
end
function M:export_delta()
 for _ in pairs(self.renewal) do
  error("R2 day-based regrowth requires approved Stage6 persistence migration")
 end
 return self.base:export_delta() -- authored depletion guard remains intact
end
return M
