-- R2 H: explicitly opt-in A-F world-space compatibility preview.
-- Call ONLY with externally v1/v2-schema-validated documents.
-- No main.lua, save, catalog, autosave or world activation side effects.
local Base=require("world.world_query")
local Authored=require("world.authored_world")
local Features=require("world.authored_features")
local Topo=require("world.topography_surface")
local Routes=require("world.routes_water")
local Water=require("world.collision_adapter")
local Ecology=require("objects.r2_population")
local M={}
local function valid_docs(a,m)
 assert(type(a)=="table" and type(m)=="table"
  and a.format=="osman-worldbuild-v1" and a.schema_version==1
  and m.format=="osman-worldmap-v2" and m.schema_version==2
  and a.generator_version==1 and m.generator_version==1
  and a.coordinate_space=="world" and m.coordinate_space=="world"
  and a.projection=="iso-45" and m.projection=="iso-45"
  and a.seed==m.seed and a.seed==20261018
  and type(m.authored_maps)=="table" and #m.authored_maps==1
  and m.authored_maps[1].id==a.map_id
  and m.authored_maps[1].path=="data/worldbuild/fisilti_ormani.r2.v1.json"
  and type(m.sites)=="table" and type(m.routes)=="table",
  "externally validated matching R2 A manifest and authored map required")
end
function M.new(a,m)
 valid_docs(a,m)
 local base=Base.new(a.seed)
 local region_query=Authored.new(a,base)
 local features=Features.new(a)
 local Valley=require("world.r2_valley_surface")
 local valley=Valley.new(features)
 local topography=Topo.new({
  height_at=function(x,y) return valley:height(region_query,x,y) end
 })
 local site
 for _,s in ipairs(m.sites) do
  if s.id=="site:fisilti-dere" then
   assert(not site,"duplicate crossing site");site=s
  end
 end
 assert(site and site.role=="crossing"
  and site.anchor[1]==704 and site.anchor[2]==128,
  "approved crossing site missing")
 local crossing=features:crossing_site_status(site)
 assert(crossing.valid and crossing.water_bank_gap==0,
  "approved river/route crossing geometry must be physically aligned")
 -- Crossing geometry is valid; no speculative bridge/ford construction.
 local routes=Routes.new(region_query,features,{topography=topography,sites=m.sites,crossings={}})
 local flow=routes:flow_report()
 assert(#flow==1 and flow[1].status=="consistent"
  and flow[1].conflict_segments==0,
  "river must follow the real topographic downhill gradient")
 local query={field=routes.field,seed=a.seed,generator_version=1,map_id=a.map_id}
 function query:sample(x,y)
  local s=routes:sample(x,y)
  local t=topography:sample(x,y)
  local out={} for k,v in pairs(s) do out[k]=v end
  out.height=t.height;out.grade=t.grade;out.slope_class=t.class
  out.walkable=s.walkable and t.class~="cliff"
  return out
 end
 function query:get_height(x,y) return topography:height(x,y) end
 function query:get_biome(x,y) return self:sample(x,y).biome end
 function query:get_feature(x,y) return self:sample(x,y).feature end
 function query:is_walkable(x,y) return self:sample(x,y).walkable end
 function query:surface_at(x,y) return routes:surface_at(x,y) end
 function query:water_mask(x,y) return routes:water_mask(x,y) end
 function query:route_cost(a,b) return routes:route_cost(a,b) end
 function query:get_obstacles(bounds)
  local result=routes:get_obstacles(bounds)
  for _,v in ipairs(topography:colliders(bounds.min_x,bounds.min_y,
     bounds.max_x,bounds.max_y)) do result[#result+1]=v end
  return result
 end
 local water=Water.new(query,8)
 local corridors={}
 for _,feature in ipairs(a.features) do
  if feature.kind=="path" then
   corridors[#corridors+1]={width=feature.width,points=feature.points}
  end
 end
 local population=Ecology.new(query,water,{
  map_id=a.map_id,sites=m.sites,corridors=corridors,
  build_zones={},starter_resources=false,
  region_at=function(x,y)
   local region=region_query.authored:region_at(x,y)
   return region and region.id or nil
  end})
 local old_visible=population._visible
 function population:_visible(o)
  if not old_visible(self,o) then return false end
  return topography:sample(o.x,o.y).class~="cliff"
 end
 local old_build=population.can_build
 function population:can_build(x,y,r)
  local safe,reason=topography:can_build(x-r,y-r,2*r,2*r)
  if not safe then return false,reason end
  return old_build(self,x,y,r)
 end
 return {query=query,base=base,authored=region_query,topography=topography,
  features=features,valley=valley,routes=routes,water=water,population=population,
  manifest=m,authored_map=a,production_enabled=false,
  persistence_supported=false}
end
return M
