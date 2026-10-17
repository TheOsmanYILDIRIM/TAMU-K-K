package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Water=require("world.collision_adapter")
local World=require("objects.world")
local Solid=require("objects.query")
local Inventory=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Harvest=require("objects.harvesting")
local Catalog=require("systems.catalog")
local Clone=require("save.stage5_domain_clone")
local Ops=require("save.stage5_domain_operations")
local Store=require("save.store")
local Bridge=require("save.stage5_transaction_bridge")
local Json=require("save.json")
local F=require("tests.save_v2_fixture")
local query=Query.new(20261015)
local water=Water.new(query,8)
local world=World.new(query,water)
local solid=Solid.new(water,world)
local inventory=Inventory.new(12)
local building=Building.new(inventory,query,solid,F.world_id)
local live={query=query,solid=solid,world=world,inventory=inventory,
  building=building,crafting=Craft.new(inventory),
  harvesting=Harvest.new(world,38,inventory)}
local fs={files={},fail=false}
function fs:mkdir(_) return true end
function fs:read(path) return self.files[path] end
function fs:write(path,data)
  if self.fail and path:find("/current.json",1,true) then return false end
  self.files[path]=data;return true
end
local store=Store.new(fs,{catalog=Catalog.items(),catalog_version=1,generator_version=1})
local zero=F.empty()
assert(store:commit(zero))
local publishes=0
local bridge=Bridge.new(store,F.world_id,function() return Clone.clone(live) end,
  Ops.run,function(staged)
    Clone.publish(live,staged)
    publishes=publishes+1
  end)
local function run(id,kind,args)
  fs.fail=true
  local before=Json.encode(live.inventory:snapshot())
  local ok=bridge:run(id,kind,args)
  assert(not ok and publishes==0)
  assert(Json.encode(live.inventory:snapshot())==before)
  fs.fail=false
  ok=bridge:run(id,kind,args)
  assert(ok,"operation failed: "..tostring(kind))
  assert(publishes==1)
  local replay=bridge:run(id,kind,args)
  assert(not replay,"duplicate command published")
end
-- Real Crafting recipe: workbench from planks, prepared only in detached inventory.
local candidate=live.inventory:preview()
assert(live.inventory:preview_add(candidate,"core:wood_plank",4))
live.inventory:commit_preview(candidate)
run("craft:one","craft",{recipe_id="core:bench_from_planks",station_tags={}})
assert(live.inventory:count("core:workbench")==1)
local saved=store:load(F.world_id)
assert(saved.world_revision==1 and saved.player.inventory.slots[1])
print("STAGE5_REAL_OPS_CRAFT_PASS")
