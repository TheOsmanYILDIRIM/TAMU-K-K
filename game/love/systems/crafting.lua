-- Canonical recipes. Production uses begin/update to honour duration_ticks.
-- execute remains an immediate domain adapter for isolated fixtures.
local Catalog=require("systems.catalog")
local Crafting={}; Crafting.__index=Crafting
local function valid_id(id)
  assert(type(id)=="string" and #id>0 and #id<=128,"invalid crafting command")
end
local function stations_allowed(recipe,available)
  available=available or {}
  assert(type(available)=="table","station tags must be a table")
  local known={}
  for _,tag in ipairs(available) do
    assert(type(tag)=="string","station tag must be string")
    known[tag]=true
  end
  for _,tag in ipairs(recipe.station_tags) do
    if not known[tag] then return false end
  end
  return true
end
function Crafting.new(inventory)
  assert(inventory and type(inventory.preview)=="function"
    and type(inventory.commit_preview)=="function","inventory required")
  return setmetatable({inventory=inventory,commands={},active=nil},Crafting)
end
function Crafting:_stage(recipe,station_tags)
  if not stations_allowed(recipe,station_tags) then
    return nil,"station_required"
  end
  local candidate=self.inventory:preview()
  for _,input in ipairs(recipe.inputs) do
    if not self.inventory:preview_remove(candidate,input.def_id,input.count) then
      return nil,"insufficient_materials"
    end
  end
  for _,output in ipairs(recipe.outputs) do
    if not self.inventory:preview_add(candidate,output.def_id,output.count) then
      return nil,"inventory_full"
    end
  end
  self.inventory:validate_preview(candidate)
  return candidate
end
function Crafting:_perform(recipe,station_tags)
  local candidate,reason=self:_stage(recipe,station_tags)
  if not candidate then return {ok=false,status=reason} end
  self.inventory:commit_preview(candidate)
  return {ok=true,status="crafted",recipe_id=recipe.id,duration_ticks=recipe.duration_ticks}
end
function Crafting:execute(command_id,recipe_id,station_tags)
  valid_id(command_id)
  if self.commands[command_id] then return self.commands[command_id] end
  local recipe=Catalog.recipe(recipe_id)
  local result=self:_perform(recipe,station_tags)
  self.commands[command_id]=result
  return result
end
function Crafting:begin(command_id,recipe_id,station_tags)
  valid_id(command_id)
  if self.commands[command_id] then return self.commands[command_id] end
  local recipe=Catalog.recipe(recipe_id)
  local result
  if self.active then result={ok=false,status="busy"}
  else
    local candidate,reason=self:_stage(recipe,station_tags)
    if not candidate then result={ok=false,status=reason}
    else
      self.active={command_id=command_id,recipe_id=recipe.id,ticks=0}
      result={ok=true,status="started",recipe_id=recipe.id,duration_ticks=recipe.duration_ticks}
    end
  end
  self.commands[command_id]=result
  return result
end
function Crafting:progress()
  local a=self.active
  if not a then return 0 end
  return math.min(1,a.ticks/Catalog.recipe(a.recipe_id).duration_ticks)
end
function Crafting:update(dt,station_tags)
  assert(type(dt)=="number" and dt==dt and dt>=0 and dt<math.huge,"invalid crafting delta")
  local a=self.active
  if not a then return nil end
  a.ticks=a.ticks+math.min(dt,0.1)*60
  local recipe=Catalog.recipe(a.recipe_id)
  if a.ticks+1e-8<recipe.duration_ticks then return nil end
  -- Revalidate both stock and station at completion. No reservation, no loss
  -- on interruption, full inventory or moving away from the workbench.
  local result=self:_perform(recipe,station_tags)
  self.commands[a.command_id]=result
  self.active=nil
  return result
end
return Crafting
