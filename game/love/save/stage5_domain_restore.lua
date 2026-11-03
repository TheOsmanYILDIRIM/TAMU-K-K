-- Strict Stage6 checkpoint -> fresh Stage5 domain restoration.
-- No mutation of the active game graph before validation and successful rebuild.
local Clone=require("save.stage5_domain_clone")
local Validate=require("save.validate")
local Catalog=require("systems.catalog")
local M={}
function M.restore(live,state)
  assert(live and live.inventory and live.world and live.building)
  Validate.check(state,{catalog=Catalog.items(),world_id=live.building.world_id,
    seed=live.world.seed,generator_version=live.world.generator_version,
    catalog_version=Catalog.version()})
  local candidate=Clone.clone(live)
  local inv=candidate.inventory
  assert(state.player.inventory.capacity==inv.capacity,"inventory capacity mismatch")
  local slots={}
  for _,entry in ipairs(state.player.inventory.slots) do
    slots[entry.slot]={def_id=entry.def_id,count=entry.count}
  end
  inv:commit_preview(slots)
  candidate.world.delta={}
  for id,v in pairs(state.generated_object_delta.objects) do
    candidate.world.delta[id]={depleted=v.depleted}
  end
  candidate.building.placed={}
  local max_revision=0
  for id,v in pairs(state.placed_instances) do
    local def=Catalog.item(v.def_id)
    local fw,fh=def.placeable.footprint[1],def.placeable.footprint[2]
    if def.placeable.rotation_steps%2==0 and v.rotation%2==1 then fw,fh=fh,fw end
    candidate.building.placed[id]={
      id=v.id,def_id=v.def_id,x=v.x,y=v.y,rotation=v.rotation,
      owner_id=v.owner_id,command_id=v.command_id,revision=v.revision,
      box={x=v.x-fw*16,y=v.y-fh*16,w=fw*32,h=fh*32}}
    if v.revision>max_revision then max_revision=v.revision end
  end
  candidate.building.revision=max_revision
  candidate.building.commands={}
  candidate.crafting.commands={}
  candidate.harvesting.commands={}
  candidate.harvesting.events={}
  candidate.harvesting.active=nil
  candidate.crafting.active=nil
  for id,v in pairs(state.applied_commands) do
    local result={ok=v.status=="complete" or v.status=="crafted" or v.status=="placed",
      status=v.status}
    if id:sub(1,6)=="craft:" then candidate.crafting.commands[id]=result
    elseif id:sub(1,6)=="place:" or id:sub(1,6)=="build:" then
      candidate.building.commands[id]=result
    elseif id:sub(1,8)=="harvest:" then candidate.harvesting.commands[id]=result end
  end
  candidate.inventory.applied={}
  for id in pairs(state.applied_transactions) do candidate.inventory.applied[id]=true end
  return candidate,{x=state.player.x,y=state.player.y}
end
return M
