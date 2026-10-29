-- Render- and world-generator-independent modular building kernel (V1).
-- Plans reserve volume; only completed pieces produce physical colliders/support.
-- No disk writes, graphics allocations, random IDs, or callbacks during commit.
local Spatial=require("systems.building_spatial")
local Kit={};Kit.__index=Kit
local abs,cos,sin,pi=math.abs,math.cos,math.sin,math.pi
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function integer(n) return finite(n) and n==math.floor(n) end
local function name(s) return type(s)=="string" and #s>0 and #s<=128 end
local function valid_uuid(s)
  if type(s)~="string" or #s~=36 then return false end
  local a,b,c,d,e=s:match("^(%x+)%-(%x+)%-(%x+)%-(%x+)%-(%x+)$")
  return a and #a==8 and #b==4 and #c==4 and #d==4 and #e==12
    and c:sub(1,1)=="4" and d:sub(1,1):match("[89aAbB]")~=nil
end
local function rotated(x,y,rot,steps)
  local angle=2*pi*rot/steps
  local c,s=cos(angle),sin(angle)
  if abs(c)<1e-12 then c=0 end
  if abs(s)<1e-12 then s=0 end
  return x*c-y*s,x*s+y*c
end
local function footprint(def,x,y,z,rot)
  local w,d,h=def.size[1],def.size[2],def.size[3]
  local a=2*pi*rot/def.rotation_steps
  local bw=abs(w*cos(a))+abs(d*sin(a))
  local bd=abs(w*sin(a))+abs(d*cos(a))
  return {x=x-bw/2,y=y-bd/2,w=bw,h=bd,z=z,d=h}
end
local function overlap3(a,b)
  local e=1e-7
  return a.x<b.x+b.w-e and b.x<a.x+a.w-e
    and a.y<b.y+b.h-e and b.y<a.y+a.h-e
    and a.z<b.z+b.d-e and b.z<a.z+a.d-e
end
local function socket_of(def,id)
  for _,s in ipairs(def.sockets or {}) do if s.id==id then return s end end
end
local function point(inst,s)
  local x,y=rotated(s.x,s.y,inst.rotation,inst.def.rotation_steps)
  return inst.x+x,inst.y+y,inst.z+s.z
end
local function validate_defs(defs)
  assert(type(defs)=="table" and next(defs),"building definitions required")
  local copy={}
  for id,def in pairs(defs) do
    assert(name(id) and type(def)=="table" and def.id==id,"invalid building definition ID")
    assert(def.mode=="foundation" or def.mode=="attached" or def.mode=="free",
      "invalid building placement mode")
    assert(def.rotation_steps==4 or def.rotation_steps==8,"unsupported rotation steps")
    assert(type(def.size)=="table" and #def.size==3,"invalid building size")
    for _,v in ipairs(def.size) do assert(finite(v) and v>0 and v<=256,"invalid size") end
    assert(type(def.cost)=="table" and next(def.cost),"construction cost required")
    local costs={}
    for item,n in pairs(def.cost) do
      assert(name(item) and integer(n) and n>0 and n<=9999,"invalid material cost")
      costs[item]=n
    end
    local sockets,unique={},{}
    for _,s in ipairs(def.sockets or {}) do
      assert(type(s)=="table" and name(s.id) and not unique[s.id]
        and name(s.kind) and finite(s.x) and finite(s.y) and finite(s.z)
        and integer(s.facing) and s.facing>=0 and s.facing<8,"invalid socket")
      unique[s.id]=true
      sockets[#sockets+1]={id=s.id,kind=s.kind,x=s.x,y=s.y,z=s.z,facing=s.facing}
    end
    copy[id]={id=id,mode=def.mode,size={def.size[1],def.size[2],def.size[3]},
      rotation_steps=def.rotation_steps,cost=costs,sockets=sockets}
  end
  return copy
end
function Kit.new(defs,world,options)
  assert(type(world)=="table" and type(world.sample)=="function"
    and type(world.obstacles)=="function","building world adapter required")
  options=options or {}
  local cell=options.cell or 64
  local reach=options.reach or 96
  local max_pier=options.max_pier or 32
  assert(finite(reach) and reach>0 and finite(max_pier) and max_pier>=0,
    "invalid building limits")
  return setmetatable({definitions=validate_defs(defs),world=world,
    index=Spatial.new(cell),items={},children={},socket_used={},
    commands={},revision=0,reach=reach,max_pier=max_pier},Kit)
end
local function valid_position(p)
  return type(p)=="table" and finite(p.x) and finite(p.y)
    and (p.z==nil or finite(p.z))
end
function Kit:preview(def_id,position,rotation,connection,player)
  local def=assert(self.definitions[def_id],"unknown building definition")
  assert(integer(rotation) and rotation>=0 and rotation<def.rotation_steps,"invalid rotation")
  assert(valid_position(position) and valid_position(player),"invalid world position")
  assert(type(connection)=="nil" or type(connection)=="table","invalid connection")
  local x,y,z=position.x,position.y,position.z
  local parent,parent_socket,child_socket
  if def.mode=="attached" then
    if not connection or not name(connection.parent_id) then return false,"missing_support" end
    parent=self.items[connection.parent_id]
    if not parent or parent.status~="built" then return false,"missing_support" end
    parent_socket=socket_of(parent.def,connection.parent_socket)
    child_socket=socket_of(def,connection.child_socket)
    if not parent_socket or not child_socket or parent_socket.kind~=child_socket.kind then
      return false,"socket_mismatch" end
    local parent_dir=(parent_socket.facing+parent.rotation*8/parent.def.rotation_steps)%8
    local child_dir=(child_socket.facing+rotation*8/def.rotation_steps)%8
    if (parent_dir-child_dir)%8~=4 then return false,"socket_direction" end
    local key=parent.id..":"..parent_socket.id
    if self.socket_used[key] then return false,"socket_occupied" end
    local px,py,pz=point(parent,parent_socket)
    local dx,dy=rotated(child_socket.x,child_socket.y,rotation,def.rotation_steps)
    x,y,z=px-dx,py-dy,pz-child_socket.z
    -- Authoritative snap, not screen-coordinate or user-provided z.
  elseif connection then
    return false,"unexpected_support"
  end
  if (x-player.x)^2+(y-player.y)^2>self.reach^2 then return false,"out_of_range" end
  if def.mode~="attached" then
    local footprint_box=footprint(def,x,y,0,rotation)
    local highest,lowest=-math.huge,math.huge
    for iy=0,2 do for ix=0,2 do
      local sx=footprint_box.x+footprint_box.w*ix/2
      local sy=footprint_box.y+footprint_box.h*iy/2
      local s=self.world:sample(sx,sy)
      if type(s)~="table" or not finite(s.height) or type(s.walkable)~="boolean" then
        return false,"missing_surface" end
      if not s.walkable or s.feature=="water" then return false,"unsafe_surface" end
      if type(self.world.is_protected)=="function" and self.world:is_protected(sx,sy) then
        return false,"protected_area" end
      highest=math.max(highest,s.height);lowest=math.min(lowest,s.height)
    end end
    if highest-lowest>self.max_pier then return false,"pier_too_long" end
    z=z or highest
    if z<highest-1e-7 or z-lowest>self.max_pier then return false,"invalid_elevation" end
  end
  if not finite(z) then return false,"invalid_elevation" end
  local box=footprint(def,x,y,z,rotation)
  for _,near in ipairs(self.index:query(box)) do
    if overlap3(box,near.box) then return false,"occupied" end
  end
  -- Legacy obstacles have ground footprints. Elevated pieces only collide
  -- with them when overlapping sampled ground height at their location.
  local ground=self.world:sample(x,y)
  if type(ground)~="table" or not finite(ground.height) then return false,"missing_surface" end
  if def.mode~="attached" or box.z<ground.height+1e-7 then
    for _,o in ipairs(self.world:obstacles(box.x,box.y,box.x+box.w,box.y+box.h)) do
      if type(o)=="table" and finite(o.x) and finite(o.y) and finite(o.w) and finite(o.h)
        and o.w>0 and o.h>0 and
        box.x<o.x+o.w and o.x<box.x+box.w and
        box.y<o.y+o.h and o.y<box.y+box.h then
        return false,"world_obstacle" end
    end
  end
  return true,{x=x,y=y,z=z,rotation=rotation,box=box,
    parent_id=parent and parent.id or nil,
    parent_socket=parent_socket and parent_socket.id or nil,
    child_socket=child_socket and child_socket.id or nil}
end
local function record(self,cmd,signature,fn)
  assert(name(cmd),"invalid command ID")
  local old=self.commands[cmd]
  if old then
    if old.signature~=signature then return {ok=false,status="command_conflict"} end
    return old.result
  end
  local result=fn()
  self.commands[cmd]={signature=signature,result=result}
  return result
end
function Kit:plan(cmd,id,def_id,pos,rotation,connection,player,owner)
  assert(valid_uuid(id) and name(owner),"invalid instance/owner")
  local signature=table.concat({"plan",id,def_id,tostring(pos.x),tostring(pos.y),
    tostring(pos.z),tostring(rotation),connection and connection.parent_id or "",
    connection and connection.parent_socket or "",
    connection and connection.child_socket or "",
    tostring(player.x),tostring(player.y),owner},"|")
  return record(self,cmd,signature,function()
    if self.items[id] then return {ok=false,status="instance_id_conflict"} end
    local ok,shape=self:preview(def_id,pos,rotation,connection,player)
    if not ok then return {ok=false,status=shape} end
    local def=self.definitions[def_id]
    local part={id=id,def_id=def_id,def=def,owner=owner,
      x=shape.x,y=shape.y,z=shape.z,rotation=rotation,box=shape.box,
      parent_id=shape.parent_id,parent_socket=shape.parent_socket,
      child_socket=shape.child_socket,status="planned",delivered={}}
    -- All fallible validation is complete before changing the authoritative state.
    self.index:insert(id,part.box,part)
    self.items[id]=part
    if part.parent_id then
      local key=part.parent_id..":"..part.parent_socket
      self.socket_used[key]=id
      local children=self.children[part.parent_id] or {}
      children[id]=true;self.children[part.parent_id]=children
    end
    self.revision=self.revision+1
    return {ok=true,status="planned",instance_id=id,revision=self.revision}
  end)
end
function Kit:deliver(cmd,id,material,amount,inventory)
  assert(name(id) and name(material) and integer(amount) and amount>0,
    "invalid material delivery")
  assert(inventory and type(inventory.preview)=="function" and
    type(inventory.preview_remove)=="function" and
    type(inventory.commit_preview)=="function","inventory staging required")
  return record(self,cmd,table.concat({"deliver",id,material,amount},"|"),function()
    local part=self.items[id]
    if not part or part.status~="planned" then return {ok=false,status="not_planned"} end
    local remaining=(part.def.cost[material] or 0)-(part.delivered[material] or 0)
    if remaining<=0 or amount>remaining then return {ok=false,status="excess_material"} end
    local staged=inventory:preview()
    if not inventory:preview_remove(staged,material,amount) then
      return {ok=false,status="insufficient_materials"} end
    -- Cost, index and support are fully validated; commit staged inventory once.
    inventory:commit_preview(staged)
    part.delivered[material]=(part.delivered[material] or 0)+amount
    local complete=true
    for item,required in pairs(part.def.cost) do
      if (part.delivered[item] or 0)~=required then complete=false;break end
    end
    if complete then part.status="built" end
    self.revision=self.revision+1
    return {ok=true,status=complete and "built" or "delivered",
      instance_id=id,revision=self.revision}
  end)
end
function Kit:obstacles(box)
  assert(type(box)=="table" and finite(box.z) and finite(box.d) and box.d>0,
    "3D obstacle query required")
  local out={}
  for _,part in ipairs(self.index:query(box)) do
    if part.status=="built" and overlap3(part.box,box) then
      out[#out+1]={id=part.id,x=part.box.x,y=part.box.y,z=part.box.z,
        w=part.box.w,h=part.box.h,d=part.box.d}
    end
  end
  return out
end
function Kit:remove(cmd,id)
  assert(name(id),"invalid instance ID")
  return record(self,cmd,"remove|"..id,function()
    local part=self.items[id]
    if not part then return {ok=false,status="missing_instance"} end
    if next(self.children[id] or {}) then return {ok=false,status="has_dependents"} end
    -- Refunds require a future inventory transaction contract. Do not discard paid parts.
    if part.status=="planned" and next(part.delivered) then
      return {ok=false,status="refund_not_implemented"} end
    if part.status=="built" then return {ok=false,status="dismantle_not_implemented"} end
    self.index:remove(id);self.items[id]=nil
    if part.parent_id then
      self.socket_used[part.parent_id..":"..part.parent_socket]=nil
      self.children[part.parent_id][id]=nil
    end
    self.revision=self.revision+1
    return {ok=true,status="removed",revision=self.revision}
  end)
end
function Kit:snapshot()
  local parts={}
  for id,p in pairs(self.items) do
    local delivered={}
    for item,n in pairs(p.delivered) do delivered[item]=n end
    parts[#parts+1]={id=id,def_id=p.def_id,x=p.x,y=p.y,z=p.z,
      rotation=p.rotation,owner=p.owner,status=p.status,
      parent_id=p.parent_id,parent_socket=p.parent_socket,
      child_socket=p.child_socket,delivered=delivered}
  end
  table.sort(parts,function(a,b)return a.id<b.id end)
  return {version=1,revision=self.revision,parts=parts}
end
return Kit
