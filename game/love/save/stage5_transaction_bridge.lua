-- Stage5/Stage6 isolated durable adapter.
-- Operates on a fresh, detached Stage5 domain graph. Never mutate the live
-- inventory, object delta, placed instances or command ledgers before commit.
local Tx=require("save.transaction")
local Bridge={}
Bridge.__index=Bridge
function Bridge.new(store,world_id,clone_domain,stage_operation,publish)
  assert(type(clone_domain)=="function" and type(stage_operation)=="function"
    and type(publish)=="function","explicit isolated Stage5 ports required")
  local self=setmetatable({clone=clone_domain,stage=stage_operation,
    publish=publish,pending=nil},Bridge)
  self.tx=Tx.new(store,world_id,function(saved)
    local domain=self.pending
    assert(domain,"missing detached domain on committed publish")
    self.publish(domain,saved)
    self.pending=nil
  end)
  return self
end
function Bridge:run(command_id,kind,arguments)
  assert(kind=="harvest" or kind=="craft" or kind=="build",
    "unsupported Stage5 operation")
  assert(self.pending==nil,"unresolved prior transaction")
  local stagedDomain
  local ok,reason=self.tx:run(command_id,function(nextState,previous)
    -- Caller must return a newly created domain graph with no shared mutable
    -- tables to the live game, and stage all side effects only on that graph.
    local candidate=self.clone()
    assert(candidate and candidate~=self.live,"detached domain required")
    local accepted,why=self.stage(candidate,kind,arguments,nextState,previous,command_id)
    if not accepted then return false,why end
    assert(nextState.world_revision==previous.world_revision+1
      and nextState.journal_sequence==previous.journal_sequence+1
      and nextState.applied_commands[command_id],"invalid Stage5 checkpoint")
    stagedDomain=candidate
    self.pending=candidate
    return true
  end)
  if not ok then
    self.pending=nil
    return false,reason
  end
  return true,reason
end
return Bridge
