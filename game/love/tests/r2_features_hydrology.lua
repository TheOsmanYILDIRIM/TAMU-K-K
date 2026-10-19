package.path="./?.lua;./?/init.lua;"..package.path
-- R2 C scoped tests. Run from game/love; CI supplies the actual B-branch Lua file.
local Json=require("save.json")
local Query=require("world.world_query")
local Facade=require("world.authored_world")
local Features=require("world.authored_features")
local Routes=require("world.routes_water")
local function read_json(path)
  local file=assert(io.open(path,"rb"),"missing canonical authored fixture: "..path)
  local bytes=file:read("*a");file:close()
  return Json.decode(bytes)
end
local b_path=assert(os.getenv("OSMAN_R2_B_TOPOGRAPHY_PATH"),
  "real B topography module path must be provided by CI")
local Topography=assert(loadfile(b_path))()
assert(type(Topography.new)=="function","real B topography required")
local function near(a,b,eps)
  assert(type(a)=="number" and type(b)=="number"
    and math.abs(a-b)<(eps or 1e-6),tostring(a).." ~= "..tostring(b))
end
local function rejects(callback,message)
  assert(not pcall(callback),message or "unsafe configuration unexpectedly accepted")
end

local authored=read_json("../../data/worldbuild/fisilti_ormani.r2.v1.json")
local manifest=read_json("../../data/worldbuild/osman_overworld.v2.json")
local base=Query.new(20261018)
local facade=Facade.new(authored,base)
local features=Features.new(authored)
local topography=Topography.new({world=facade})
local r2=Routes.new(facade,features,{topography=topography,sites=manifest.sites})
assert(r2.generator_version==1 and r2.seed==20261018)
assert(r2.map_id=="worldmap:fisilti-ormani" and #r2.crossings==0)
assert(#features.features==4 and #manifest.sites==7)

local diagnostics=r2:crossing_diagnostics(manifest.sites)
assert(#diagnostics==1 and diagnostics[1].site_id=="site:fisilti-dere")
assert(diagnostics[1].valid
  and diagnostics[1].reason=="verified_intersection"
  and diagnostics[1].water_bank_gap==0,
  "H approved river line must cross A's immutable site and main path")
local invalid_crossing={id="crossing:fisilti-dere",
  site_id="site:fisilti-dere",kind="bridge",
  path_feature_id="feature:fisilti-ana-patika",
  water_feature_id="feature:fisilti-dere-izi",width=8,length=1}
rejects(function()
  Routes.new(facade,features,{topography=topography,sites=manifest.sites,
    crossings={invalid_crossing}})
end,"a physically invalid short bridge must be rejected")

local wet,wet_signed=r2:water_mask(616,62)
assert(wet and wet_signed>0)
local center=r2:surface_at(616,62)
assert(center.wet and center.water_body and center.id=="water")
near(center.speed_multiplier,0.55)
near(center.immersion,0.5)
near(center.water_depth,2)
assert(r2:sample(616,62).feature=="water")
local near_bank=r2:surface_at(616,69)
assert(near_bank.water_depth<center.water_depth and near_bank.water_depth>0)
local flow_report=r2:flow_report()
assert(#flow_report==1 and flow_report[1].feature_id=="feature:fisilti-dere-izi")
assert(flow_report[1].status=="consistent" or flow_report[1].status=="conflict"
  or flow_report[1].status=="no_overall_drop")

-- Generator v1 is never overwritten outside authored segments, even on chunk seams.
local reversed={}
for k,v in pairs(authored) do reversed[k]=v end
reversed.features={}
for i=#authored.features,1,-1 do
  reversed.features[#reversed.features+1]=authored.features[i]
end
local alternate=Routes.new(facade,Features.new(reversed),{topography=topography})
for _,p in ipairs({{-512,0},{-256,-256},{0,0},{256,0},{512,128},
  {616,62},{704,128},{2000,2000},{3000,-3000}}) do
  local x,y=p[1],p[2]
  local is_water,signed=r2:water_mask(x,y)
  assert(is_water==(signed>0))
  near(signed,r2.field:channel(x,y,"water"))
  near(signed,alternate:water_scalar(x,y))
  assert(r2:sample(x,y).feature==alternate:sample(x,y).feature)
  near(r2:get_height(x,y),facade:get_height(x,y))
  assert(r2:get_biome(x,y)==facade:get_biome(x,y))
  assert(r2:is_walkable(x,y)==facade:is_walkable(x,y))
end
for _,p in ipairs({{2000,2000},{-3000,-3000}}) do
  local x,y=p[1],p[2]
  near(r2:water_scalar(x,y),facade.field:channel(x,y,"water"))
  assert(r2:sample(x,y).feature==facade:sample(x,y).feature)
end
local bounds={min_x=0,min_y=0,max_x=16,max_y=16}
assert(#r2:get_obstacles(bounds)==#facade:get_obstacles(bounds))

-- Complete synthetic crossing centered exactly at the global 256 chunk seam.
local function testmap(cx,water_points)
  return {format="osman-worldbuild-v1",schema_version=1,
    coordinate_space="world",projection="iso-45",generator_version=1,
    seed=20261018,map_id="worldmap:crossing-test",
    features={{id="feature:dry-route",kind="path",intent_only=true,
       width=10,points={{cx-32,0},{cx+32,0}}},
      {id="feature:small-stream",kind="water",intent_only=true,
       width=12,points=water_points or {{cx,-48},{cx,48}}}}}
end
local map=testmap(256)
local f=Features.new(map)
local base_fake={seed=20261018,generator_version=1,
  field={channel=function(_,x,y,name)
    assert(name=="water" or name=="forest" or name=="rocky")
    return -5
  end},
  sample=function(_,x,y)
    return {biome="meadow",feature=nil,height=0,moisture=0.5,walkable=true}
  end,
  get_height=function() return 0 end,
  is_walkable=function() return true end,
  get_obstacles=function() return {} end}
local t_flat=Topography.new({world=base_fake})
local site={id="site:verified-crossing",role="crossing",anchor={256,0}}
local bridge={id="crossing:real-bridge",kind="bridge",
  site_id=site.id,path_feature_id="feature:dry-route",
  water_feature_id="feature:small-stream",width=6,length=24}
local no_cross=Routes.new(base_fake,f,{topography=t_flat})
local crossing=Routes.new(base_fake,f,{topography=t_flat,
  crossings={bridge},sites={site}})
assert(#f:intersections()==1)
assert(f:crossing_site_status(site).valid)
local body,signed=crossing:water_mask(256,0)
assert(body and signed>0 and crossing.field:channel(256,0,"water")>0)
local deck=crossing:surface_at(256,0)
assert(deck.id=="dry" and deck.water_body and not deck.wet
  and deck.crossing_id==bridge.id and deck.immersion==0)
assert(crossing:sample(256,0).feature=="path")
local off_deck=crossing:surface_at(256,5)
assert(off_deck.id=="water" and off_deck.wet and not off_deck.crossing_id)
near(off_deck.speed_multiplier,0.55)
near(off_deck.immersion,0.5)
assert(no_cross:surface_at(256,0).wet
  and no_cross:sample(256,0).feature=="water")
for _,x in ipairs({255.999,256,256.001}) do
  assert(crossing:water_mask(x,0))
  assert(no_cross:water_mask(x,0))
end
assert(not crossing:water_mask(249,0))
assert(not crossing:water_mask(263,0))
local along={x=228,y=0}
local along_end={x=240,y=0}
local outside={x=228,y=20}
local outside_end={x=240,y=20}
local cheap=crossing:route_cost(along,along_end)
local expensive=crossing:route_cost(outside,outside_end)
assert(cheap.walkable and expensive.walkable and cheap.cost<expensive.cost)
near(cheap.cost,12*0.85)
near(expensive.cost,12)
local from,to={x=244,y=0},{x=268,y=0}
local dry_bridge=crossing:route_cost(from,to)
local wet_crossing=no_cross:route_cost(from,to)
assert(dry_bridge.walkable and wet_crossing.walkable
  and dry_bridge.cost<wet_crossing.cost)
near(dry_bridge.cost,24*0.85)

-- An actual shallow ford remains wet; deep water cannot be declared ford.
local ford={id="crossing:real-ford",kind="ford",site_id=site.id,
  path_feature_id="feature:dry-route",
  water_feature_id="feature:small-stream",width=6}
local shallow=Routes.new(base_fake,f,{topography=t_flat,
  crossings={ford},sites={site},water_max_depth=0.5})
assert(shallow:surface_at(256,0).crossing_kind=="ford")
assert(shallow:surface_at(256,0).wet)
near(shallow:surface_at(256,0).speed_multiplier,0.55)
near(shallow:surface_at(256,0).immersion,0.5)
near(shallow:surface_at(256,0).water_depth,0.5)
rejects(function()
  Routes.new(base_fake,f,{topography=t_flat,crossings={ford},sites={site}})
end,"deep water was mislabeled as a shallow ford")
local short_bridge={}
for k,v in pairs(bridge) do short_bridge[k]=v end
short_bridge.length=10
rejects(function()
  Routes.new(base_fake,f,{topography=t_flat,crossings={short_bridge},sites={site}})
end,"short bridge span accepted")

-- Slopes use actual B transition API, not an unrelated height heuristic.
local steep=Topography.new({height_at=function(x,y) return x<256 and 0 or 100 end})
local steep_route=Routes.new(base_fake,f,{topography=steep})
local cost=steep_route:route_cost(from,to)
assert(not cost.walkable and cost.cost==math.huge and cost.reason=="cliff")
local downhill=Topography.new({height_at=function(x,y) return -y end})
local slope_route=Routes.new(base_fake,f,{topography=downhill})
assert(slope_route:flow_report()[1].status=="consistent")
local current=slope_route:surface_at(256,0).current
assert(current.status=="downhill")
near(current.x,0)
near(current.y,1)
near(current.grade,1)

local conflict_map=testmap(256,{{256,-48},{256,10},{256,48}})
local conflict_topo=Topography.new({height_at=function(x,y)
  if y==10 then return 200 end
  return -y
end})
local conflict=Routes.new(base_fake,Features.new(conflict_map),
  {topography=conflict_topo})
assert(conflict:flow_report()[1].status=="conflict")

local negative_map=testmap(-256)
local negative_routes=Routes.new(base_fake,Features.new(negative_map),
  {topography=t_flat})
assert(negative_routes:water_mask(-256,0))
assert(not negative_routes:water_mask(256,0))
local reversed_synthetic=testmap(256)
reversed_synthetic.features[1],reversed_synthetic.features[2]=
  reversed_synthetic.features[2],reversed_synthetic.features[1]
local alt=Routes.new(base_fake,Features.new(reversed_synthetic),
  {topography=t_flat,crossings={bridge},sites={site}})
assert(alt:water_mask(256,0) and alt:surface_at(256,0).id=="dry")
near(alt:route_cost(from,to).cost,dry_bridge.cost)

-- Negative inputs, duplicate IDs and invalid versions must fail closed.
rejects(function() crossing:surface_at(0/0,0) end)
rejects(function() crossing:water_mask(math.huge,0) end)
rejects(function() crossing:route_cost({x=0/0,y=0},to) end)
rejects(function() crossing:route_cost(from,{x=math.huge,y=0}) end)
local dup=testmap(256)
dup.features[2].id=dup.features[1].id
rejects(function() Features.new(dup) end)
local invalid=testmap(256);invalid.generator_version=2
rejects(function() Features.new(invalid) end)
local broken=testmap(256);broken.features[2].points[2]={256,-48}
rejects(function() Features.new(broken) end)
local other_base={}
for k,v in pairs(base_fake) do other_base[k]=v end
other_base.seed=20261019
rejects(function() Routes.new(other_base,f,{topography=t_flat}) end)
rejects(function() Routes.new(base_fake,f,{topography={}}) end)
rejects(function()
  Routes.new(base_fake,f,{topography=t_flat,crossings={bridge,bridge},sites={site}})
end)

print(string.format("R2_C_H_CROSSING_ALIGNED site=%s bank_gap=%.3f",
  diagnostics[1].site_id,diagnostics[1].water_bank_gap))
print("R2_C_A_FLOW_STATUS "..flow_report[1].status)
print("R2_FEATURES_HYDROLOGY_OK source=A_r2 B_topography=real Lua=both")
