package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Water=require("world.collision_adapter")
local World=require("objects.world")
local Solid=require("objects.query")
local Inventory=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Harvest=require("objects.harvesting")
local Clone=require("save.stage5_domain_clone")
local query=Query.new(20261015)
local water=Water.new(query,8)
local world=World.new(query,water)
local solid=Solid.new(water,world)
local inventory=Inventory.new(12)
local building=Building.new(inventory,query,solid,
  "12345678-1234-4abc-8abc-123456789abd")
local live={query=query,solid=solid,world=world,inventory=inventory,
  building=building,crafting=Craft.new(inventory),
  harvesting=Harvest.new(world,38,inventory)}
local detached=Clone.clone(live)
assert(detached.inventory~=live.inventory and detached.world~=live.world)
assert(detached.building~=live.building and detached.harvesting~=live.harvesting)
assert(detached.solid.objects==detached.world)
assert(detached.building.base_query==detached.solid)
assert(detached.crafting.inventory==detached.inventory)
assert(detached.harvesting.inventory==detached.inventory)
assert(detached.harvesting.world==detached.world)
local item="core:wood_log"
local preview=detached.inventory:preview()
assert(detached.inventory:preview_add(preview,item,3))
detached.inventory:commit_preview(preview)
assert(detached.inventory:count(item)==3 and live.inventory:count(item)==0)
detached.world.delta["worldobj:v1:20261015:-3:4"]={depleted=true}
assert(next(live.world.delta)==nil)
assert(not pcall(Clone.clone,{inventory=inventory,world=world,building=building,
  query=query,solid={}}))
print("STAGE5_DOMAIN_CLONE_OK actual Stage5 classes isolated")
