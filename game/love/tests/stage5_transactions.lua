package.path="./?.lua;./?/init.lua;"..package.path
local Inventory=require("systems.inventory")
local Harvest=require("objects.harvesting")
local Craft=require("systems.crafting")
local Catalog=require("systems.catalog")
local Uuid=require("systems.uuid")
local Tree=require("objects.definitions")
local id="worldobj:v1:15:-1:2"
local tree={id=id,def_id="core:oak_tree",x=0,y=0,radius=10}
assert(Tree.get(tree.def_id).drops[1].def_id=="core:wood_log")
local function world()
  local w={depleted=false}
  function w:get(which) if which==id then return tree end end
  function w:is_depleted() return self.depleted end
  function w:deplete(which)
    assert(which==id)
    if self.depleted then return false,"depleted" end
    self.depleted=true
    return true
  end
  return w
end
local full=Inventory.new(1)
assert(full:credit_harvest({type="HarvestCompleted",transaction_id="fill",item_id="core:stone",amount=99}))
local w=world()
local h=Harvest.new(w,38,full)
assert(h:begin("h1",id,25,0).ok)
for _=1,40 do h:update(.1,25,0) end
assert(h.commands.h1.status=="inventory_full" and not w.depleted)
assert(#h:drain_events()==0 and full:count("core:wood_log")==0)
local inv=Inventory.new(3)
local obj=world()
local harvest=Harvest.new(obj,38,inv)
assert(harvest:begin("h2",id,25,0).ok)
for _=1,40 do harvest:update(.1,25,0) end
assert(obj.depleted and harvest.commands.h2.status=="complete")
local drops=harvest:drain_events()
assert(#drops==1 and inv:count("core:wood_log")==drops[1].amount)
assert(inv:credit_harvest(drops[1])==false)
assert(harvest:begin("h2",id,25,0).status=="complete")
local craft=Craft.new(inv)
local a=craft:begin("c1","core:planks_from_log")
assert(a.ok and a.status=="started" and craft:begin("c1","core:planks_from_log")==a)
assert(inv:count("core:wood_plank")==0)
for _=1,4 do assert(craft:update(.1)==nil) end
assert(inv:count("core:wood_plank")==0)
local done=craft:update(.1)
assert(done and done.ok and inv:count("core:wood_plank")==4)
assert(craft:begin("c1","core:planks_from_log")==done)
local second=craft:begin("c2","core:bench_from_planks")
assert(second.ok)
for _=1,10 do craft:update(.1) end
assert(inv:count("core:workbench")==1)
local status=craft:begin("c3","core:planks_from_log")
assert(status.ok)
local busy=craft:begin("c4","core:planks_from_log")
assert(not busy.ok and busy.status=="busy")
local v=Uuid.new(function(lo,hi) assert(lo==0 and hi==255) return 10 end)
assert(v:match("^[%x]+%-%x+%-4%x+%-[89ab]%x+%-%x+$"))
-- A schema-canonical synthetic station recipe checks late station loss.
local original_recipe=Catalog.recipe
Catalog.recipe=function(id)
  if id=="test:station" then return {
    id=id,inputs={{def_id="core:wood_log",count=1}},
    outputs={{def_id="core:wood_plank",count=4}},
    station_tags={"core:bench"},duration_ticks=12
  } end
  return original_recipe(id)
end
local gated=Craft.new(inv)
local denied=gated:begin("gate-1","test:station",{})
assert(denied.status=="station_required" and not denied.ok)
local started=gated:begin("gate-2","test:station",{"core:bench"})
assert(started.ok)
assert(gated:update(.1,{})==nil)
local failed=gated:update(.1,{})
assert(failed and not failed.ok and failed.status=="station_required")
assert(inv:count("core:wood_plank")==0)
Catalog.recipe=original_recipe
print("STAGE5_TRANSACTIONS_OK atomic harvest, timed craft, station gate")
