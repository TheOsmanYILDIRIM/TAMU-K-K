-- Detached Stage5 domain recreation: fresh objects, no shared mutable RAM.
-- This is a staging adapter, not yet wired into the production update loop.
local Inventory=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Harvest=require("objects.harvesting")
local Json=require("save.json")
local M={}
local function copy(v) return Json.decode(Json.encode(v)) end
function M.clone(live)
  assert(type(live)=="table" and live.inventory and live.world
    and live.building and live.query and live.solid,"live Stage5 domain required")
  local inv=Inventory.new(live.inventory.capacity)
  inv:commit_preview(live.inventory:preview())
  inv.applied=copy(live.inventory.applied)
  local world=setmetatable({},getmetatable(live.world))
  for k,v in pairs(live.world) do world[k]=v end
  world.delta=copy(live.world.delta)
  -- Building obstacle queries must see the staged world, not the live world.
  -- Reject unknown query adapters instead of silently aliasing mutable state.
  assert(live.solid.world==live.world or live.solid.objects==live.world,
    "unsupported Stage5 solid-query shape")
  local solid=setmetatable({},getmetatable(live.solid))
  for k,v in pairs(live.solid) do solid[k]=v end
  if solid.world==live.world then solid.world=world end
  if solid.objects==live.world then solid.objects=world end
  -- placement/cache objects remain read-only during the staged operation;
  -- only mutable delta and domain ledgers are copied.
  local building=Building.new(inv,live.query,solid,live.building.world_id)
  building.placed=copy(live.building.placed)
  building.commands=copy(live.building.commands)
  building.revision=live.building.revision
  local craft=Craft.new(inv)
  craft.commands=copy(live.crafting.commands)
  craft.active=copy(live.crafting.active)
  local harvest=Harvest.new(world,live.harvesting.range,inv)
  harvest.commands=copy(live.harvesting.commands)
  harvest.active=copy(live.harvesting.active)
  harvest.events=copy(live.harvesting.events)
  return {inventory=inv,world=world,solid=solid,building=building,
    crafting=craft,harvesting=harvest}
end
function M.publish(live,staged)
  assert(staged and staged.inventory and staged.world and staged.building)
  -- Caller must quiesce gameplay during publication; one coherent graph swap.
  live.inventory=staged.inventory
  live.world=staged.world
  live.solid=staged.solid
  live.building=staged.building
  live.crafting=staged.crafting
  live.harvesting=staged.harvesting
end
return M
