local Json=require("save.json")
local M={}
M.catalog={
 ["core:wood_log"]={max_stack=64},
 ["core:wood_plank"]={max_stack=64},
 ["core:stone"]={max_stack=64},
 ["core:workbench"]={max_stack=1,placeable=true}
}
M.world_id="12345678-1234-4abc-8abc-123456789abd"
M.placed_id="12345678-1234-4abc-8abc-123456789abe"
function M.empty()
  return {
    format="love-world-2d",save_version=2,world_id=M.world_id,
    seed=20261015,generator_version=1,catalog_version=1,
    world_revision=0,
    player={id="player:local",x=0,y=0,
      inventory={version=1,catalog_version=1,capacity=12,slots=Json.array()}},
    generated_object_delta={version=1,seed=20261015,generator_version=1,objects={}},
    placed_instances={},applied_commands={},applied_transactions={},journal_sequence=0
  }
end
function M.next(s)
  local n=Json.decode(Json.encode(s))
  n.world_revision=1;n.journal_sequence=1
  n.player.x=-123.5;n.player.y=55.75
  n.player.inventory.slots=Json.array({
    {slot=1,def_id="core:wood_log",count=2},
    {slot=9,def_id="core:workbench",count=1}
  })
  n.generated_object_delta.objects["worldobj:v1:20261015:-3:4"]={depleted=true}
  n.placed_instances[M.placed_id]={
    id=M.placed_id,def_id="core:workbench",x=-48.5,y=64,
    rotation=2,owner_id="player:local",command_id="place:one",revision=1
  }
  n.applied_commands["place:one"]={revision=1,status="placed"}
  n.applied_transactions["harvest:one"]={
    revision=1,item_id="core:wood_log",amount=2
  }
  return n
end
return M
