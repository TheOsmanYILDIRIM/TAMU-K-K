-- Actual Stage5 operation adapters for detached graph candidates.
-- All mutation happens only in the clone; never invoke on live game objects.
local Catalog=require("systems.catalog")
local Checkpoint=require("save.stage5_checkpoint")
local M={}
local function mark(state,id,status)
  state.applied_commands[id]={revision=state.world_revision,status=status}
end
function M.run(domain,kind,args,state,previous,id)
  assert(domain and domain.inventory and domain.world and domain.building
    and domain.crafting and domain.harvesting,"detached Stage5 graph required")
  assert(type(args)=="table" and type(id)=="string","operation args required")
  local result
  if kind=="harvest" then
    -- Real Harvesting.begin/update, including inventory, depletion and events.
    result=domain.harvesting:begin(id,assert(args.object_id),assert(args.x),assert(args.y))
    if not result.ok then return false,result.status end
    domain.harvesting:update(assert(args.duration),args.x,args.y)
    result=domain.harvesting.commands[id]
    if not result or not result.ok or result.status~="complete" then
      return false,result and result.status or "incomplete"
    end
  elseif kind=="craft" then
    -- Actual Crafting.execute stages recipe inputs and outputs in cloned inventory.
    result=domain.crafting:execute(id,assert(args.recipe_id),args.station_tags or {})
    if not result.ok then return false,result.status end
  elseif kind=="build" then
    result=domain.building:place(id,assert(args.instance_id),
      assert(args.def_id),assert(args.x),assert(args.y),
      assert(args.rotation),assert(args.player_x),assert(args.player_y),
      assert(args.owner_id))
    if not result.ok then return false,result.status end
  else error("unsupported operation") end
  state.world_revision=previous.world_revision+1
  state.journal_sequence=previous.journal_sequence+1
  local status=kind=="harvest" and "complete"
    or kind=="craft" and "crafted" or "placed"
  mark(state,id,status)
  if kind=="harvest" then
    for _,event in ipairs(domain.harvesting.events) do
      if event.command_id==id then
        state.applied_transactions[event.transaction_id]={revision=state.world_revision,
          item_id=event.item_id,amount=event.amount}
      end
    end
  end
  -- Materialize actual domain state only after successful detached mutation.
  local snapshot=Checkpoint.compose({
    inventory=domain.inventory,world=domain.world,building=domain.building,
    world_id=previous.world_id,catalog=Catalog.items(),
    catalog_version=Catalog.version(),revision=state.world_revision,
    sequence=state.journal_sequence,player_id=previous.player.id,
    x=args.player_x or previous.player.x,y=args.player_y or previous.player.y,
    applied_commands=state.applied_commands,
    applied_transactions=state.applied_transactions
  })
  -- Replace only mutable state fields; preserve immutable world identity.
  state.player=snapshot.player
  state.generated_object_delta=snapshot.generated_object_delta
  state.placed_instances=snapshot.placed_instances
  return true
end
return M
