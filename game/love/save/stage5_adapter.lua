-- Explicit Stage5 inventory wire adapter. No mutation, IO or autosave.
local Json=require("save.json")
local M={}
function M.inventory_snapshot(inventory)
  assert(type(inventory)=="table" and type(inventory.snapshot)=="function",
    "Stage5 inventory required")
  local snap=inventory:snapshot()
  assert(type(snap.slots)=="table","inventory slots missing")
  local slots=Json.array()
  local seen={}
  for i,slot in ipairs(snap.slots) do
    assert(type(slot)=="table" and type(slot.slot)=="number"
      and slot.slot==math.floor(slot.slot) and slot.slot>=1
      and slot.slot<=snap.capacity and not seen[slot.slot],"invalid slot")
    seen[slot.slot]=true
    slots[i]={slot=slot.slot,def_id=slot.def_id,count=slot.count}
  end
  for k in pairs(snap.slots) do
    assert(type(k)=="number" and k>=1 and k<=#snap.slots
      and k==math.floor(k),"sparse inventory export")
  end
  return {version=snap.version,catalog_version=snap.catalog_version,
    capacity=snap.capacity,slots=slots}
end
-- Transient started operations must not enter immutable applied_commands.
-- Only terminal outcomes are immutable and journal-eligible.
local terminal={crafted=true,placed=true,complete=true,failed=true,interrupted=true}
function M.terminal_commands(commands,revision)
  assert(type(commands)=="table","command map required")
  local out={}
  for id,result in pairs(commands) do
    assert(type(id)=="string" and type(result)=="table","invalid command")
    if terminal[result.status] then
      out[id]={revision=revision,status=result.status}
    elseif result.status~="started" and result.status~="busy" then
      error("unsupported transient command status: "..tostring(result.status))
    end
  end
  return out
end
return M
