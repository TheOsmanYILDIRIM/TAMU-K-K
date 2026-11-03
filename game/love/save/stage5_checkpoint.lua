-- Stage5 checkpoint composition. Safe for isolated transaction candidates only.
-- The caller MUST stage domain changes before commit and publish them only after success.
local Adapter=require("save.stage5_adapter")
local Validate=require("save.validate")
local M={}
local function copy_records(records)
  local result={}
  for id,entry in pairs(records) do
    assert(type(id)=="string" and type(entry)=="table","invalid ledger")
    local out={}
    for k,v in pairs(entry) do out[k]=v end
    result[id]=out
  end
  return result
end
function M.compose(args)
  assert(type(args)=="table" and type(args.inventory)=="table"
    and type(args.world)=="table" and type(args.world.export_delta)=="function"
    and type(args.building)=="table" and type(args.building.snapshot)=="function",
    "explicit Stage5 domain objects required")
  local placed=args.building:snapshot()
  assert(placed.world_id==args.world_id,"world identity mismatch")
  local revision=assert(args.revision)
  local s={
    format="love-world-2d",save_version=2,world_id=args.world_id,
    seed=args.world.seed,generator_version=args.world.generator_version,
    catalog_version=args.catalog_version,world_revision=revision,
    journal_sequence=assert(args.sequence),
    player={id=assert(args.player_id),x=assert(args.x),y=assert(args.y),
      inventory=Adapter.inventory_snapshot(args.inventory)},
    generated_object_delta=args.world:export_delta(),
    placed_instances=placed.placed,
    applied_commands=copy_records(args.applied_commands or {}),
    applied_transactions=copy_records(args.applied_transactions or {})
  }
  Validate.check(s,{catalog=assert(args.catalog),seed=s.seed,
    generator_version=s.generator_version,catalog_version=s.catalog_version,
    world_id=s.world_id})
  return s
end
return M
