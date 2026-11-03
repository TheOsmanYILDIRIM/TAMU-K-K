-- Reproducible Stage 5 vertical-slice fixture on the REAL procedural world.
-- Domain operations use actual Stage 4 harvest events, not fabricated drops.
local Query=require("world.world_query")
local Adapter=require("world.collision_adapter")
local ResourceWorld=require("objects.world")
local Combined=require("objects.query")
local Harvest=require("objects.harvesting")
local Inventory=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Collision=require("physics.collision")
local Scenario={}

local WORLD_UUID="12345678-1234-4abc-9abc-123456789abd"
local function new_id(number)
  return string.format("12345678-1234-4abc-8abc-%012x",number)
end

function Scenario.run(seed)
  local query=Query.new(seed)
  local water=Adapter.new(query,8)
  local resources=ResourceWorld.new(query,water)
  local solids=Combined.new(water,resources)
  local inventory=Inventory.new(12)
  local crafting=Craft.new(inventory)
  local harvest=Harvest.new(resources,38)
  local tree,player
  -- Deterministic search in bounded source geography.
  for _,object in ipairs(resources:objects_in({
    min_x=-640,min_y=-640,max_x=640,max_y=640})) do
    if object.kind=="tree" then
      for _,direction in ipairs({{1,0},{0,1},{-1,0},{0,-1}}) do
        local x=object.x+direction[1]*(object.radius+20)
        local y=object.y+direction[2]*(object.radius+20)
        if Collision.can_stand(solids,x,y,5) then
          tree=object;player={x=x,y=y,radius=5,immersion=0}
          break
        end
      end
      if tree then break end
    end
  end
  assert(tree and player,"Stage5 scenario cannot find safe harvestable tree")
  assert(harvest:begin("stage5:harvest",tree.id,player.x,player.y).ok)
  for _=1,30 do harvest:update(.1,player.x,player.y) end
  local events=harvest:drain_events()
  assert(#events==1 and events[1].item_id=="core:wood_log")
  for _,event in ipairs(events) do
    assert(inventory:credit_harvest(event),"harvest credit failed")
  end
  assert(resources:is_depleted(tree.id),"resource state did not change")
  assert(crafting:execute("stage5:planks","core:planks_from_log").ok)
  assert(crafting:execute("stage5:bench","core:bench_from_planks").ok)
  local building=Building.new(inventory,query,solids,WORLD_UUID)
  local success
  local attempt=0
  for oy=-80,80,16 do
    for ox=-80,80,16 do
      if ox~=0 or oy~=0 then
        local x,y=player.x+ox,player.y+oy
        attempt=attempt+1
        local command="stage5:place:"..attempt
        local result=building:place(command,new_id(attempt),"core:workbench",
          x,y,0,player.x,player.y,"player:local")
        if result.ok then success=result;break end
      end
    end
    if success then break end
  end
  assert(success,"no nearby safe workbench placement")
  assert(inventory:count("core:wood_log")==2)
  assert(inventory:count("core:wood_plank")==0)
  assert(inventory:count("core:workbench")==0)
  assert(building.revision==1)
  assert(not building:place("stage5:place:1",new_id(1),
    "core:workbench",0,0,0,0,0,"player:local").ok or
    success.instance_id==new_id(1))
  return {query=query,resources=resources,solids=solids,
    inventory=inventory,crafting=crafting,building=building,
    player=player,tree_id=tree.id,placed_id=success.instance_id}
end
return Scenario
