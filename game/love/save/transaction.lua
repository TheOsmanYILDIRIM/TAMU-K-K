-- Durable transaction boundary: only publish RAM mutation AFTER verified checkpoint.
-- Builders must be side-effect-free; this module refuses recovered/read-only worlds.
local Json=require("save.json")
local Tx={}
Tx.__index=Tx
function Tx.new(store,world_id,publish)
  assert(store and type(store.load)=="function" and type(store.commit)=="function")
  assert(type(world_id)=="string" and type(publish)=="function")
  return setmetatable({store=store,id=world_id,publish=publish},Tx)
end
function Tx:run(command_id,build)
  assert(type(command_id)=="string" and #command_id>0 and #command_id<=128)
  assert(type(build)=="function")
  local previous,meta=self.store:load(self.id)
  if not previous or not meta or meta.read_only or meta.status~="ok" then
    return false,"no_writable_checkpoint"
  end
  if previous.applied_commands[command_id] then
    return false,"duplicate"
  end
  -- Deep copy prevents a builder mutating the live snapshot on failure.
  local staged=Json.decode(Json.encode(previous))
  local ok,value,reason=pcall(build,staged,previous)
  if not ok then return false,"stage_error:"..tostring(value) end
  if value~=true then return false,reason or "rejected" end
  if previous.applied_commands[command_id] then return false,"duplicate" end
  if staged.world_revision~=previous.world_revision+1
     or staged.journal_sequence~=previous.journal_sequence+1
     or not staged.applied_commands[command_id] then
    return false,"invalid_staged_revision"
  end
  local committed,why=self.store:commit(staged)
  if not committed then return false,why end
  -- This callback must be a no-fail state replacement. A callback failure is
  -- fatal for the current session: reload from disk rather than retry mutation.
  local published,err=pcall(self.publish,staged)
  if not published then return false,"committed_reload_required:"..tostring(err) end
  return true,"committed"
end
return Tx
