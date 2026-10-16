package.path="./?.lua;./?/init.lua;"..package.path
local Scenario=require("systems.scenario")
local Collision=require("physics.collision")
local s=Scenario.run(20261015)
assert(s.resources:is_depleted(s.tree_id))
assert(s.building.placed[s.placed_id])
local instance=s.building.placed[s.placed_id]
assert(not Collision.can_stand(s.building,instance.x,instance.y,1))
local before=s.inventory:count("core:wood_log")
local replay=s.inventory:credit_harvest({
  type="HarvestCompleted",transaction_id="stage5:harvest:1",
  item_id="core:wood_log",amount=3
})
assert(not replay and before==s.inventory:count("core:wood_log"))
local same=Scenario.run(20261015)
assert(same.tree_id==s.tree_id and same.placed_id==s.placed_id)
assert(same.building.revision==s.building.revision)
local snapshot=s.building:snapshot()
assert(snapshot.placed[s.placed_id].command_id~=nil)
print("STAGE5_END_TO_END_OK harvest -> inventory -> planks -> bench -> placement")
