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
-- Seed initial checkpoint with the same inventory as the live domain.
-- A Stage6 transaction must start from a checkpoint matching live RAM.
local initial=live.inventory:preview()
assert(live.inventory:preview_add(initial,"core:wood_plank",4))
live.inventory:commit_preview(initial)
zero.player.inventory.slots=Json.array({{slot=1,def_id="core:wood_plank",count=4}})
assert(store:commit(zero))
local publishes=0
local bridge=Bridge.new(store,F.world_id,function() return Clone.clone(live) end,
  Ops.run,function(staged)
    Clone.publish(live,staged)
    publishes=publishes+1
  end)
local function run(id,kind,args)
  fs.fail=true
  local before=live.inventory:snapshot()
  local ok=bridge:run(id,kind,args)
  assert(not ok and publishes==0)
  assert(live.inventory:count("core:wood_plank")==4 and live.inventory:count("core:workbench")==0)
  fs.fail=false
  ok=bridge:run(id,kind,args)
  assert(ok,"operation failed: "..tostring(kind))
  assert(publishes==1)
  local replay=bridge:run(id,kind,args)
  assert(not replay,"duplicate command published")
end
-- Real Crafting recipe: workbench from planks, prepared only in detached inventory.
run("craft:one","craft",{recipe_id="core:bench_from_planks",station_tags={}})
assert(live.inventory:count("core:workbench")==1)
local saved=store:load(F.world_id)
assert(saved.world_revision==1 and saved.player.inventory.slots[1])
print("STAGE5_REAL_OPS_CRAFT_PASS")

-- Actual procedural harvest in a fresh checkpoint/world, with no live mutation
-- on failed commit and idempotent replay.
local function fresh(kind)
  local w=World.new(query,water)
  local so=Solid.new(water,w)
  local inv=Inventory.new(12)
  local b=Building.new(inv,query,so,F.world_id)
  local domain={query=query,solid=so,world=w,inventory=inv,building=b,
    crafting=Craft.new(inv),harvesting=Harvest.new(w,38,inv)}
  local storage={files={},fail=false}
  function storage:mkdir(_) return true end
  function storage:read(path) return self.files[path] end
  function storage:write(path,bytes)
    if self.fail and path:find("/current.json",1,true) then return false end
    self.files[path]=bytes;return true
  end
  local st=Store.new(storage,{catalog=Catalog.items(),catalog_version=1,generator_version=1})
  local init=F.empty()
  if kind=="build" then
    local pr=inv:preview()
    assert(inv:preview_add(pr,"core:workbench",1))
    inv:commit_preview(pr)
    init.player.inventory.slots=Json.array({{slot=1,def_id="core:workbench",count=1}})
  end
  assert(st:commit(init))
  local published=0
  local tx=Bridge.new(st,F.world_id,function() return Clone.clone(domain) end,
    Ops.run,function(candidate) Clone.publish(domain,candidate);published=published+1 end)
  return domain,storage,st,tx,function() return published end
end
local hd,hfs,hstore,htx,hpub=fresh("harvest")
local obj
for _,o in ipairs(hd.world:objects_in({min_x=-384,min_y=-384,max_x=384,max_y=384})) do
  if o.kind=="tree" then obj=o;break end
end
assert(obj,"real procedural tree required")
local hargs={object_id=obj.id,x=obj.x,y=obj.y,duration=8}
hfs.fail=true
local hok=htx:run("harvest:real","harvest",hargs)
assert(not hok and hpub()==0 and not hd.world:is_depleted(obj.id))
assert(hd.inventory:count("core:wood_log")==0)
hfs.fail=false
local hreason
hok,hreason=htx:run("harvest:real","harvest",hargs)
assert(hok and hpub()==1 and hd.world:is_depleted(obj.id),tostring(hreason))
assert(hd.inventory:count("core:wood_log")>0)
assert(not htx:run("harvest:real","harvest",hargs))
local hs=hstore:load(F.world_id)
assert(hs.world_revision==1 and hs.generated_object_delta.objects[obj.id].depleted)
assert(next(hs.applied_transactions)~=nil)
print("STAGE5_REAL_OPS_HARVEST_PASS")

local bd,bfs,bstore,btx,bpub=fresh("build")
local bx,by
for y=-256,256,32 do
  if bx then break end
  for x=-256,256,32 do
    local ok,valid=pcall(bd.building.preview,bd.building,
      "core:workbench",x,y,0,x+50,y)
    if ok and valid then bx,by=x,y;break end
  end
end
assert(bx,"real valid dry building site required")
local bargs={instance_id=F.placed_id,def_id="core:workbench",
  x=bx,y=by,rotation=0,player_x=bx+50,player_y=by,
  owner_id="player:local"}
bfs.fail=true
local bok=btx:run("build:real","build",bargs)
assert(not bok and bpub()==0 and bd.inventory:count("core:workbench")==1)
assert(next(bd.building.placed)==nil)
bfs.fail=false
bok=btx:run("build:real","build",bargs)
assert(bok and bpub()==1 and bd.inventory:count("core:workbench")==0)
assert(bd.building.placed[F.placed_id])
assert(not btx:run("build:real","build",bargs))
local bs=bstore:load(F.world_id)
assert(bs.world_revision==1 and bs.placed_instances[F.placed_id])
print("STAGE5_REAL_OPS_BUILD_PASS")
