package.path="./?.lua;./?/init.lua;"..package.path
local Population=require("objects.r2_population")
local Harvest=require("objects.harvesting")
local Inventory=require("systems.inventory")
local Crafting=require("systems.crafting")
local Defs=require("objects.definitions")
local Collision=require("physics.collision")
local ObjectQuery=require("objects.query")
local seed=20261018
-- Explicit deterministic authored surface fixture, not a production v2 switch.
local q={seed=seed,generator_version=1}
function q:sample(x,y)
 return {walkable=true,biome="meadow",variant="wildflower",feature=nil}
end
local water={obstacles=function() return {} end}
local function region(x,y)
 if x>=-24 and x<=256 and y>=-24 and y<=256 then return "region:fisilti-giris" end
 if x>256 and x<550 and y>-40 and y<300 then return "region:fisilti-koruluk" end
 return nil
end
local sites={
 {id="site:fisilti-uyanis",role="spawn",region_id="region:fisilti-giris",anchor={64,128}},
 {id="site:fisilti-yol-ayrimi",role="crossroads",region_id="region:fisilti-koruluk",anchor={384,128}}
}
local cfg={map_id="worldmap:fisilti-ormani",sites=sites,region_at=region,
 starter_resources=true,
 corridors={{width=18,points={{64,128},{256,128},{384,128}}}},
 build_zones={{x=150,y=210,radius=26}}}
local a=Population.new(q,water,cfg)
local b=Population.new(q,water,cfg)
assert(#a.authored==2 and #b.authored==2)
for i=1,2 do
 local x,y=a.authored[i],b.authored[i]
 assert(x.id==y.id and x.x==y.x and x.y==y.y)
 assert(x.id:match("^worldobj:authored:v1:fisilti%-ormani:starter%-"))
 assert(x.region_id=="region:fisilti-giris")
 assert(a:get(x.id) and a:get(x.id).id==x.id)
 assert(not a:_protected(x.x,x.y,x.radius))
end
assert(a.authored[1].id~=a.authored[2].id)
assert(a:get("site:fisilti-uyanis")==nil)
local near={min_x=-256,min_y=-256,max_x=512,max_y=512}
local all=a:objects_in(near)
local observed={}
for _,o in ipairs(all) do
 assert(not observed[o.id],"duplicate ID");observed[o.id]=true
 assert(a:get(o.id).id==o.id)
 assert(not a:_protected(o.x,o.y,o.radius),"spawn/path/build resource interference")
end
for _,o in ipairs(a.authored) do
 assert(observed[o.id],"starter resource not in query")
 assert(not Collision.can_stand(ObjectQuery.new(water,a),o.x,o.y,1))
end
assert(a:can_build(150,210,5))
assert(not a:can_build(64,128,5))
assert(not a:can_build(384,128,5))
assert(not a:can_build(1000,1000,5))
local rare=Population.rare_slots({
 {id="site:fisilti-kalinti",role="ruin",region_id="region:fisilti-kalinti",anchor={320,420}},
 {id="site:fisilti-kayalik-cikis",role="pass",region_id="region:fisilti-kayalik-gecit",anchor={1130,350}},
 sites[1]
})
assert(#rare==2 and rare[1].id~=rare[2].id)
assert(rare[1].id:match("^rare%-slot:") and rare[2].id:match("^rare%-slot:"))
assert(rare[1].id~=rare[1].site_id) -- site ID is never a loot/object ID
assert(not a:rare_status("core:rare_crystal"))
assert(not a:rare_status("core:stone_rock"))
-- Outside authored region, procedural identity and placement stay Generator v1.
local Raw=require("objects.world")
local baseline=Raw.new(q,water)
local outer=baseline:site(-10,-10)
if outer then
 assert(a:get(outer.id) and a:get(outer.id).id==outer.id)
end
local tree,rock
for _,o in ipairs(a.authored) do
 if o.def_id=="core:oak_tree" then tree=o elseif o.def_id=="core:stone_rock" then rock=o end
end
assert(tree and rock)
local bag=Inventory.new(12)
local h=Harvest.new(a,38,bag)
local x,y=tree.x+tree.radius+2,tree.y
assert(h:begin("r2-tree-1",tree.id,x,y).ok)
for _=1,30 do h:update(.1,x,y) end
assert(h:begin("r2-tree-1",tree.id,x,y).status=="complete")
assert(bag:count("core:wood_log")==3)
local evt=h:drain_events()
assert(#evt==1 and evt[1].amount==3)
assert(not bag:credit_harvest(evt[1])) -- harvest already credited once
local craft=Crafting.new(bag)
assert(craft:execute("r2-planks-1","core:planks_from_log",{}).ok)
assert(bag:count("core:wood_plank")==4 and bag:count("core:wood_log")==2)
assert(a:is_depleted(tree.id))
assert(a.tree_regrow_days==3)
assert(not pcall(function() a:export_delta() end),"unsaved renewal must fail closed")
a:advance_day(2)
assert(a:is_depleted(tree.id))
a:advance_day(3)
assert(not a:is_depleted(tree.id))
assert(a:get(tree.id).id==tree.id)
assert(h:begin("r2-tree-2",tree.id,x,y).ok)
for _=1,30 do h:update(.1,x,y) end
assert(a:is_depleted(tree.id))
assert(bag:count("core:wood_log")==5)
assert(not pcall(function() a:advance_day(2) end))
local rh=Harvest.new(a,38,bag)
local rx,ry=rock.x+rock.radius+2,rock.y
assert(rh:begin("r2-rock",rock.id,rx,ry).ok)
for _=1,30 do rh:update(.1,rx,ry) end
assert(a:is_depleted(rock.id))
a:advance_day(100)
assert(a:is_depleted(rock.id),"finite rock regenerated")
assert(bag:count("core:stone")==2)
assert(not pcall(function() Population.new(q,water,{map_id=cfg.map_id,
 sites={{id="site:fisilti-uyanis",role="spawn",region_id="region:wrong",anchor={64,128}}},
 region_at=region}) end),"wrong region accepted")
assert(not pcall(function() Population.new(q,water,{map_id=cfg.map_id,
 sites=sites,region_at=region,starter_resources=true,
 anchors={{id="starter-tree",region_id="region:fisilti-giris",x=70,y=220,def_id="core:oak_tree"}}}) end),
 "duplicate curated resource ID accepted")

-- Real Generator v1 + authored-facade smoke, separate from the synthetic
-- guaranteed-start fixture. This is NOT production v2 map activation.
local WorldQuery=require("world.world_query")
local Facade=require("world.authored_world")
local WaterAdapter=require("world.collision_adapter")
local realbase=WorldQuery.new(seed)
local entry={
 id="region:fisilti-giris",biome="meadow",variant="wildflower",
 polygon={{0,0},{132,-24},{246,0},{265,76},{256,110},{256,146},
  {267,184},{256,256},{165,268},{58,254},{-24,160}}
}
local authored=Facade.new({
 format="osman-worldbuild-v1",schema_version=1,generator_version=1,
 seed=seed,map_id=cfg.map_id,coordinate_space="world",
 projection="iso-45",regions={entry}
},realbase)
local waterreal=WaterAdapter.new(authored,8)
local function actual_region(x,y)
 local hit=authored.authored:region_at(x,y)
 return hit and hit.id or nil
end
local realcfg={map_id=cfg.map_id,region_at=actual_region,
 sites={{id="site:fisilti-uyanis",role="spawn",region_id=entry.id,anchor={64,128}}},
 corridors={{width=18,points={{64,128},{256,128}}}}}
local real=Population.new(authored,waterreal,realcfg)
local twins=Population.new(authored,waterreal,realcfg)
local big={min_x=-256,min_y=-256,max_x=512,max_y=512}
local whole=real:objects_in(big)
local idset={}
for _,o in ipairs(whole) do
 assert(not idset[o.id]);idset[o.id]=o
 assert(twins:get(o.id)~=nil and twins:get(o.id).x==o.x)
 assert(o.id:match("^worldobj:v1:"))
end
local seam_seen={}
for _,bounds in ipairs({
 {min_x=-256,min_y=-256,max_x=128,max_y=512},
 {min_x=128,min_y=-256,max_x=512,max_y=512}
}) do
 for _,o in ipairs(real:objects_in(bounds)) do
  assert(idset[o.id],"chunk seam generated a foreign resource")
  seam_seen[o.id]=true
 end
end
for id in pairs(idset) do assert(seam_seen[id],"chunk seam omitted a resource") end
assert(authored:sample(-600,-600).biome==realbase:sample(-600,-600).biome)
assert(not pcall(function()
 Population.new(WorldQuery.new(seed+1),waterreal,realcfg)
end),"incorrect generator seed accepted")
print("R2_POPULATION_REAL_QUERY_OK authored facade, v1 seed, chunk union, water adapter")
print("R2_POPULATION_OK deterministic IDs, clear corridors, build, rare guard, renew, Stage5 craft, Stage6 guard")
