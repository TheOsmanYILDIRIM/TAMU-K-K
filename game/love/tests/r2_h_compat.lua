package.path="./?.lua;./?/init.lua;"..package.path
local Json=require("save.json")
local H=require("world.r2_compat_bridge")
local Chunks=require("world.chunks")
local function document(name)
 local file=assert(io.open("../../data/worldbuild/"..name,"rb"))
 local bytes=file:read("*a");file:close();return Json.decode(bytes)
end
local authored=document("fisilti_ormani.r2.v1.json")
local manifest=document("osman_overworld.v2.json")
local a=H.new(authored,manifest)
local b=H.new(authored,manifest)
assert(a.production_enabled==false and a.persistence_supported==false)
assert(a.query.seed==20261018 and a.query.generator_version==1)
assert(#a.routes.crossings==0,"unapproved bridge/ford created")
local diag=a.routes:crossing_diagnostics(manifest.sites)
assert(#diag==1 and diag[1].site_id=="site:fisilti-dere"
  and diag[1].valid and diag[1].water_bank_gap==0,
 "crossing site does not match real path-water geometry")
local river=a.features.by_id["feature:fisilti-dere-izi"]
assert(#river.points==4 and river.points[3][1]==704 and
 river.points[3][2]==128,"user-approved crossing location moved")
local path=a.features.by_id["feature:fisilti-ana-patika"]
assert(path.points[5][1]==704 and path.points[5][2]==128)
assert(a.features:crossing_site_status(
 (function() for _,site in ipairs(manifest.sites) do
  if site.id=="site:fisilti-dere" then return site end
 end end)()).valid)
assert(not pcall(function() a.features:resolve_crossings(manifest.sites,{
 {id="crossing:unsafe",site_id="site:fisilti-dere",kind="bridge",
 path_feature_id="feature:fisilti-ana-patika",
 water_feature_id="feature:fisilti-dere-izi",width=8,length=1}
},2,.75) end),"short fake bridge should be rejected")
-- The bridge geometry is physically admissible only as a dry *candidate*.
-- We never instantiate it without separately approved build/gameplay.
local candidate=a.features:resolve_crossings(manifest.sites,{
 {id="crossing:verified-candidate",site_id="site:fisilti-dere",
 kind="bridge",path_feature_id="feature:fisilti-ana-patika",
 water_feature_id="feature:fisilti-dere-izi",width=8,length=64}
},2,.75)
assert(#candidate==1 and candidate[1].x==704 and
 candidate[1].y==128 and candidate[1].length==64)
assert(#a.routes.crossings==0,"candidate must not be auto-built")
assert(not pcall(function() a.features:resolve_crossings(manifest.sites,{
 {id="crossing:unsafe-ford",site_id="site:fisilti-dere",
 kind="ford",path_feature_id="feature:fisilti-ana-patika",
 water_feature_id="feature:fisilti-dere-izi",width=8}
},2,.75) end),"2-unit-deep water is not an approved shallow ford")
-- Water should remain continuous at all points along the new centerline.
for i=1,#river.points-1 do
 local p,q=river.points[i],river.points[i+1]
 for sample=0,32 do
  local u=sample/32
  local x=p[1]*(1-u)+q[1]*u
  local y=p[2]*(1-u)+q[2]*u
  local wet=a.query:water_mask(x,y)
  assert(wet,"authored river centerline has a dry gap")
 end
end
local flow=a.routes:flow_report()
assert(#flow==1 and flow[1].status=="consistent" and
 flow[1].conflict_segments==0,"river segment rises against flow")
for i=1,#river.points-1 do
 local x,y=river.points[i][1],river.points[i][2]
 local X,Y=river.points[i+1][1],river.points[i+1][2]
 assert(a.topography:height(x,y)>a.topography:height(X,Y),
  "every actual river centerline segment must flow downhill")
end
assert(a.valley:offset(704,128)<-1.99)
assert(a.valley:offset(704,200)==0)
assert(a.topography:height(704,128)<a.base:get_height(704,128)-1.99)
assert(a.topography:height(704,200)==a.base:get_height(704,200))
local center=a.query:surface_at(704,128)
assert(center.wet and center.water_body and center.water_depth==2
 and center.water_feature_id==river.id
 and center.immersion==.5 and center.speed_multiplier==.55)
assert(a.query:get_height(704,128)==a.topography:height(704,128))
local crossingCost=a.query:route_cost({x=690,y=128},{x=718,y=128})
assert(crossingCost.walkable and crossingCost.cost>28,
 "wet but traversable crossing must retain water cost")

for _,p in ipairs({{-512,-256},{-256,0},{0,0},{64,128},
 {255.99,128},{256,128},{256.01,128},{512,128},{616,62},
 {704,128},{2000,2000}}) do
 local x,y=p[1],p[2]
 local s,t=a.query:sample(x,y),b.query:sample(x,y)
 assert(s.biome==t.biome and s.feature==t.feature and s.height==t.height)
 assert(s.walkable==(a.routes:is_walkable(x,y) and
   a.topography:sample(x,y).class~="cliff"))
 local wet,signed=a.query:water_mask(x,y)
 assert(wet==(signed>0))
 assert(math.abs(signed-a.query.field:channel(x,y,"water"))<1e-8)
 assert(a.query:get_height(x,y)==a.topography:height(x,y))
 assert(a.query:get_biome(x,y)==s.biome)
 assert(a.query:get_feature(x,y)==s.feature)
 assert(a.query:is_walkable(x,y)==s.walkable)
end
local wet=a.query:surface_at(616,62)
assert(wet.wet and wet.water_body and wet.water_feature_id=="feature:fisilti-dere-izi")
assert(wet.speed_multiplier==.55 and wet.immersion==.5)
local dry=a.query:sample(2000,2000)
assert(dry.biome==a.base:sample(2000,2000).biome)
local cost=a.query:route_cost({x=384,y=128},{x=400,y=128})
assert(type(cost)=="table" and type(cost.walkable)=="boolean")
local chunker=Chunks.new(a.query,{size=256,step=32})
local left,right=chunker:build(2,0),chunker:build(3,0)
for _,kind in ipairs({"forest","rocky","water"}) do
 assert(left.layers[kind] and right.layers[kind])
 for y=0,256,32 do
  assert(a.query.field:channel(768,y,kind)==
         b.query.field:channel(768,y,kind),"non-deterministic chunk seam")
 end
end
local ids={}
local bounds={min_x=0,min_y=0,max_x=512,max_y=512}
for _,o in ipairs(a.population:objects_in(bounds)) do
 assert(not ids[o.id]);ids[o.id]=true
 assert(b.population:get(o.id)~=nil and
        a.population:get(o.id).x==b.population:get(o.id).x)
 assert(a.topography:sample(o.x,o.y).class~="cliff")
end
for _,s in ipairs(manifest.sites) do
 local region=a.authored.authored:region_at(s.anchor[1],s.anchor[2])
 assert(region and region.id==s.region_id)
end
assert(not a.population:can_build(64,128,5),"protected spawn must not be built on")
assert(a.population:rare_status("core:nonexistent")==false)
assert(not pcall(function()
 local bad={} for k,v in pairs(manifest) do bad[k]=v end
 bad.seed=1;H.new(authored,bad)
end))
print(string.format("R2_H_COMPAT_OK sites=%d objects=%d bank_gap=%.3f",
 #manifest.sites,(function() local n=0 for _ in pairs(ids) do n=n+1 end return n end)(),
 diag[1].water_bank_gap))
