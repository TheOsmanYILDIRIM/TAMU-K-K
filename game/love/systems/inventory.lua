-- In-memory atomic stack inventory. Does not claim crash-durable operations.
-- Intent/transaction IDs are durable-contract-ready but persisted in Stage 6.
local Catalog=require("systems.catalog")
local Inventory={}
Inventory.__index=Inventory

local function integer(n)
  return type(n)=="number" and n==n and n<math.huge and n>-math.huge
     and n==math.floor(n)
end

local function copy_slots(slots,capacity)
  local result={}
  for i=1,capacity do
    local s=slots[i]
    if s then result[i]={def_id=s.def_id,count=s.count} end
  end
  return result
end

local function valid_stack(id,count)
  assert(type(id)=="string" and integer(count) and count>0,
         "invalid inventory stack")
  local d=Catalog.item(id)
  return d.max_stack
end

local function tally(slots,capacity,id)
  local total=0
  for i=1,capacity do
    local s=slots[i]
    if s and s.def_id==id then total=total+s.count end
  end
  return total
end

local function add(slots,capacity,id,count)
  local limit=valid_stack(id,count)
  local remaining=count
  for pass=1,2 do
    for i=1,capacity do
      local s=slots[i]
      if pass==1 and s and s.def_id==id and s.count<limit then
        local amount=math.min(remaining,limit-s.count)
        s.count=s.count+amount
        remaining=remaining-amount
      elseif pass==2 and not s then
        local amount=math.min(remaining,limit)
        slots[i]={def_id=id,count=amount}
        remaining=remaining-amount
      end
      if remaining==0 then return true end
    end
  end
  return false
end

local function remove(slots,capacity,id,count)
  valid_stack(id,count)
  if tally(slots,capacity,id)<count then return false end
  local remaining=count
  for i=capacity,1,-1 do
    local s=slots[i]
    if s and s.def_id==id then
      local amount=math.min(remaining,s.count)
      s.count=s.count-amount
      remaining=remaining-amount
      if s.count==0 then slots[i]=nil end
      if remaining==0 then return true end
    end
  end
  error("inventory underflow invariant")
end

function Inventory.new(capacity)
  capacity=capacity or 12
  assert(integer(capacity) and capacity>=1 and capacity<=256,
         "invalid inventory slot capacity")
  return setmetatable({capacity=capacity,slots={},applied={}},Inventory)
end

function Inventory:count(id)
  Catalog.item(id)
  return tally(self.slots,self.capacity,id)
end

function Inventory:snapshot()
  -- Dense record array is JSON-safe: sparse Lua arrays are not.
  local records={}
  for i=1,self.capacity do
    local stack=self.slots[i]
    if stack then records[#records+1]={
      slot=i,def_id=stack.def_id,count=stack.count} end
  end
  return {version=1,catalog_version=Catalog.version(),
    capacity=self.capacity,slots=records}
end

function Inventory:preview()
  return copy_slots(self.slots,self.capacity)
end

function Inventory:validate_preview(preview)
  -- Reject untrusted/corrupt staging data rather than silently importing it.
  assert(type(preview)=="table","missing preview")
  for k,s in pairs(preview) do
    assert(integer(k) and k>=1 and k<=self.capacity and type(s)=="table",
      "malformed inventory slot")
    local max=valid_stack(s.def_id,s.count)
    assert(s.count<=max,"stack overflow")
  end
  return true
end

function Inventory:commit_preview(preview)
  self:validate_preview(preview)
  self.slots=copy_slots(preview,self.capacity)
end

function Inventory:preview_add(preview,id,count)
  return add(preview,self.capacity,id,count)
end
function Inventory:preview_remove(preview,id,count)
  return remove(preview,self.capacity,id,count)
end

function Inventory:credit_harvest(event)
  assert(type(event)=="table" and event.type=="HarvestCompleted"
    and type(event.transaction_id)=="string" and #event.transaction_id>0
    and type(event.item_id)=="string",
    "invalid harvested resource transaction")
  valid_stack(event.item_id,event.amount)
  if self.applied[event.transaction_id] then return false,"duplicate" end
  local candidate=self:preview()
  if not self:preview_add(candidate,event.item_id,event.amount) then
    return false,"inventory_full"
  end
  self:commit_preview(candidate)
  self.applied[event.transaction_id]=true
  return true,"credited"
end

function Inventory:can_add(id,count)
  local candidate=self:preview()
  return self:preview_add(candidate,id,count)
end

return Inventory
