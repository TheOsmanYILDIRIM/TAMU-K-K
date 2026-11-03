-- Placed instances are distinct from procedural worldobj:v1 instances.
-- Transactionally stages inventory and placement in memory; Stage 6 persists both.
local Catalog=require("systems.catalog")
local Building={}
Building.__index=Building

local function finite(x)
  return type(x)=="number" and x==x and math.abs(x)<math.huge
end
local function valid_id(id)
  if type(id)~="string" or #id~=36 then return false end
  local p={id:match("^(%x+)%-(%x+)%-(%x+)%-(%x+)%-(%x+)$")}
  return #p==5 and #p[1]==8 and #p[2]==4 and #p[3]==4
     and #p[4]==4 and #p[5]==12 and p[3]:sub(1,1)=="4"
     and p[4]:sub(1,1):match("[89aAbB]")~=nil
end
local function overlap(a,b)
  return a.x < b.x+b.w and b.x < a.x+a.w
     and a.y < b.y+b.h and b.y < a.y+a.h
end

function Building.new(inventory,terrain,base_query,world_id)
  assert(inventory and type(inventory.preview)=="function"
    and type(inventory.commit_preview)=="function","inventory required")
  assert(terrain and type(terrain.sample)=="function","terrain required")
  assert(base_query and type(base_query.obstacles)=="function","solid query required")
  assert(valid_id(world_id),"world_id must be a version-4 UUID")
  return setmetatable({inventory=inventory,terrain=terrain,base_query=base_query,
    world_id=world_id,placed={},commands={},revision=0},Building)
end

function Building:obstacles(x1,y1,x2,y2)
  assert(finite(x1) and finite(y1) and finite(x2) and finite(y2)
    and x1<=x2 and y1<=y2,"invalid bounds")
  local result=self.base_query:obstacles(x1,y1,x2,y2)
  for _,instance in pairs(self.placed) do
    local box=instance.box
    if box.x<=x2 and box.x+box.w>=x1
      and box.y<=y2 and box.y+box.h>=y1 then
      result[#result+1]={x=box.x,y=box.y,w=box.w,h=box.h,id=instance.id}
    end
  end
  table.sort(result,function(a,b)
    return tostring(a.id or a.x..":"..a.y)<tostring(b.id or b.x..":"..b.y)
  end)
  return result
end

function Building:surface_at(x,y)
  if self.base_query.surface_at then return self.base_query:surface_at(x,y) end
  error("surface query unavailable",2)
end

function Building:station_tags_near(x,y,radius)
  assert(finite(x) and finite(y) and finite(radius) and radius>=0)
  local known={}
  for _,instance in pairs(self.placed) do
    local box=instance.box
    local closest_x=math.max(box.x,math.min(x,box.x+box.w))
    local closest_y=math.max(box.y,math.min(y,box.y+box.h))
    if (closest_x-x)^2+(closest_y-y)^2<=radius*radius then
      for _,tag in ipairs(Catalog.item(instance.def_id).station_tags) do
        known[tag]=true
      end
    end
  end
  local tags={}
  for tag in pairs(known) do tags[#tags+1]=tag end
  table.sort(tags)
  return tags
end

local function dry_and_stable(terrain,box)
  -- Terrain placement is only supported on dry, walkable surface v1.
  for _,y in ipairs({box.y+0.01,box.y+box.h/2,box.y+box.h-0.01}) do
    for _,x in ipairs({box.x+0.01,box.x+box.w/2,box.x+box.w-0.01}) do
      local s=terrain:sample(x,y)
      assert(type(s)=="table" and type(s.walkable)=="boolean",
        "terrain sample unavailable")
      if not s.walkable or s.feature=="water" then return false end
    end
  end
  return true
end

-- Side-effect-free placement validation used by touch ghost and actual placement.
function Building:preview(def_id,x,y,rotation,player_x,player_y)
  assert(finite(x) and finite(y) and finite(player_x) and finite(player_y),
    "invalid placement coordinates")
  local def=Catalog.item(def_id)
  assert(def.kind=="structure" and def.placeable,"target must be a placeable structure")
  local steps=def.placeable.rotation_steps
  assert(type(rotation)=="number" and rotation==math.floor(rotation)
    and rotation>=0 and rotation<steps,"invalid structure rotation")
  if (x-player_x)^2+(y-player_y)^2>96^2 then return false,"out_of_range" end
  local fw,fh=def.placeable.footprint[1],def.placeable.footprint[2]
  if steps%2==0 and rotation%2==1 then fw,fh=fh,fw end
  local box={x=x-fw*16,y=y-fh*16,w=fw*32,h=fh*32}
  if overlap(box,{x=player_x-5,y=player_y-5,w=10,h=10}) then
    return false,"player_overlap"
  end
  if not dry_and_stable(self.terrain,box) then return false,"invalid_surface" end
  for _,solid in ipairs(self:obstacles(box.x,box.y,box.x+box.w,box.y+box.h)) do
    if overlap(box,solid) then return false,"obstructed" end
  end
  if self.inventory:count(def_id)<1 then return false,"insufficient_materials" end
  return true,"valid"
end

function Building:place(command_id,instance_id,def_id,x,y,rotation,player_x,player_y,owner_id)
  assert(type(command_id)=="string" and #command_id>0 and #command_id<=128,
    "invalid place command ID")
  if self.commands[command_id] then return self.commands[command_id] end
  assert(valid_id(instance_id),"placed instance ID must be UUIDv4")
  assert(type(owner_id)=="string" and #owner_id>0,"missing placed owner")
  assert(finite(x) and finite(y) and finite(player_x) and finite(player_y),
    "invalid placement coordinates")
  local def=Catalog.item(def_id)
  assert(def.kind=="structure" and def.placeable,
         "target must be a placeable structure")
  local steps=def.placeable.rotation_steps
  assert(type(rotation)=="number" and rotation==math.floor(rotation)
    and rotation>=0 and rotation<steps,"invalid structure rotation")
  local result
  if self.placed[instance_id] then result={ok=false,status="instance_id_conflict"}
  elseif (x-player_x)^2+(y-player_y)^2>96^2 then
    result={ok=false,status="out_of_range"}
  else
    local fw,fh=def.placeable.footprint[1],def.placeable.footprint[2]
    if steps%2==0 and (rotation % 2)==1 then fw,fh=fh,fw end
    local box={x=x-fw*16,y=y-fh*16,w=fw*32,h=fh*32}
    local player_box={x=player_x-5,y=player_y-5,w=10,h=10}
    if overlap(box,player_box) then
      result={ok=false,status="player_overlap"}
    elseif not dry_and_stable(self.terrain,box) then
      result={ok=false,status="invalid_surface"}
    else
      local obstacles=self:obstacles(box.x,box.y,box.x+box.w,box.y+box.h)
      local blocked=false
      for _,solid in ipairs(obstacles) do
        if overlap(box,solid) then blocked=true;break end
      end
      if blocked then result={ok=false,status="obstructed"}
      else
        local candidate=self.inventory:preview()
        if not self.inventory:preview_remove(candidate,def_id,1) then
          result={ok=false,status="insufficient_materials"}
        else
          -- No callbacks or external operations after mutating inventory.
          -- Stage 6 must persist inventory+placed+ledger in ONE checkpoint.
          self.inventory:commit_preview(candidate)
          self.revision=self.revision+1
          self.placed[instance_id]={id=instance_id,def_id=def_id,x=x,y=y,
            rotation=rotation,owner_id=owner_id,command_id=command_id,
            box=box,revision=self.revision}
          result={ok=true,status="placed",instance_id=instance_id,
            revision=self.revision}
        end
      end
    end
  end
  self.commands[command_id]=result
  return result
end

function Building:snapshot()
  local placed={}
  for id,item in pairs(self.placed) do
    placed[id]={id=id,def_id=item.def_id,x=item.x,y=item.y,
      rotation=item.rotation,owner_id=item.owner_id,
      command_id=item.command_id,revision=item.revision}
  end
  return {version=1,world_id=self.world_id,world_revision=self.revision,
          placed=placed}
end

return Building
