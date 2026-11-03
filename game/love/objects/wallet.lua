-- Temporary Stage 4 resource count sink, not an inventory/crafting system.
local W={};W.__index=W
function W.new() return setmetatable({totals={},applied={}},W) end
function W:apply(event)
  assert(type(event)=="table" and event.type=="HarvestCompleted"
    and type(event.transaction_id)=="string" and #event.transaction_id>0
    and type(event.item_id)=="string" and event.item_id:match("^[%w_]+:[%w_]+$")
    and type(event.amount)=="number" and event.amount>0 and event.amount%1==0,
    "invalid harvest event")
  if self.applied[event.transaction_id] then return false end
  self.applied[event.transaction_id]=true
  self.totals[event.item_id]=(self.totals[event.item_id] or 0)+event.amount
  return true
end
function W:count(id) return self.totals[id] or 0 end
return W
