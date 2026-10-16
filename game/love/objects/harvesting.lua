-- Idempotent command handling and exactly-once domain events.
-- State and command ledger live outside chunk residency (Stage 6 will persist them).
local Definitions=require("objects.definitions")
local H={};H.__index=H
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function within(o,x,y,range)
  return (o.x-x)^2+(o.y-y)^2 <= (range+o.radius)^2
end
function H.new(world,range,inventory)
  assert(world and world.get and world.deplete)
  range=range or 38
  assert(finite(range) and range>0)
  if inventory then assert(type(inventory.preview)=="function" and type(inventory.validate_preview)=="function") end
  return setmetatable({world=world,range=range,inventory=inventory,active=nil,commands={},events={}},H)
end
function H:begin(command_id,object_id,x,y)
  assert(type(command_id)=="string" and #command_id>0 and #command_id<=128,
    "invalid command id")
  assert(finite(x) and finite(y),"invalid interaction position")
  if self.commands[command_id] then return self.commands[command_id] end
  local o=self.world:get(object_id)
  local reason
  if not o then reason="missing_object"
  elseif self.world:is_depleted(object_id) then reason="depleted"
  elseif not within(o,x,y,self.range) then reason="out_of_range"
  elseif self.active then reason="busy" end
  if reason then
    local result={ok=false,status=reason}
    self.commands[command_id]=result
    return result
  end
  self.active={command_id=command_id,object_id=object_id,ticks=0,elapsed=0}
  local result={ok=true,status="started"}
  self.commands[command_id]=result
  return result
end
function H:update(dt,x,y)
  assert(finite(dt) and dt>=0 and finite(x) and finite(y),"invalid harvest step")
  local a=self.active
  if not a then return end
  local obj=self.world:get(a.object_id)
  if not obj or self.world:is_depleted(a.object_id) or not within(obj,x,y,self.range) then
    self.commands[a.command_id]={ok=false,status="interrupted"}
    self.active=nil
    return
  end
  a.elapsed=a.elapsed+math.min(dt,.1)
  local def=Definitions.get(obj.def_id)
  local duration=def.duration_ticks/60
  if a.elapsed+1e-9 < duration then return end
  -- Stage 5: stage ALL drops before touching depletion. Inventory-full
  -- leaves the resource and both ledgers intact, including multi-drop objects.
  local candidate
  if self.inventory then
    candidate=self.inventory:preview()
    for i,drop in ipairs(def.drops) do
      local transaction_id=a.command_id..":"..i
      if self.inventory.applied[transaction_id] then
        self.commands[a.command_id]={ok=false,status="duplicate_transaction"}
        self.active=nil
        return
      end
      if not self.inventory:preview_add(candidate,drop.def_id,drop.count) then
        self.commands[a.command_id]={ok=false,status="inventory_full"}
        self.active=nil
        return
      end
    end
    self.inventory:validate_preview(candidate)
  end
  local ok,reason=self.world:deplete(obj.id)
  if not ok then
    self.commands[a.command_id]={ok=false,status=reason}
  else
    -- No user callbacks/IO between domain changes. Preview was validated above.
    if candidate then self.inventory:commit_preview(candidate) end
    for i,drop in ipairs(def.drops) do
      if candidate then self.inventory.applied[a.command_id..":"..i]=true end
      self.events[#self.events+1]={
        type="HarvestCompleted",transaction_id=a.command_id..":"..i,
        command_id=a.command_id,object_id=obj.id,
        item_id=drop.def_id,amount=drop.count}
    end
    self.commands[a.command_id]={ok=true,status="complete"}
  end
  self.active=nil
end
function H:progress()
  if not self.active then return 0 end
  local o=assert(self.world:get(self.active.object_id))
  local d=Definitions.get(o.def_id)
  return math.min(1,self.active.elapsed/(d.duration_ticks/60))
end
function H:drain_events()
  local events=self.events
  self.events={}
  return events
end
return H
