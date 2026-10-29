-- TAMU KOK: exact point/line constraints for modular building pieces.
-- No PNG inspection, no renderer, no world generation, no allocations per frame.
-- All matching happens in authoritative world-space coordinates.
local Parts=require("systems.building_parts")
local Iso=require("world.iso")
local A={}
A.version=1
A.unit=Parts.unit
A.wall_height=Parts.wall_height
A.pixel_tolerance=1 -- Only future asset QC; world matching stays exact.
local sqrt=math.sqrt
local function finite(n)
  return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
function A.point(x,y,z)
  assert(finite(x) and finite(y) and finite(z),"anchor coordinates must be finite")
  return {x=x,y=y,z=z}
end
local function line(name,kind,a,b)
  assert(type(name)=="string" and #name>0 and type(kind)=="string" and #kind>0,
    "anchor names/kinds required")
  assert(a and b and finite(a.x) and finite(a.y) and finite(a.z) and
    finite(b.x) and finite(b.y) and finite(b.z),"invalid anchor endpoints")
  assert(a.x~=b.x or a.y~=b.y or a.z~=b.z,"zero-length anchor")
  return {name=name,kind=kind,a=A.point(a.x,a.y,a.z),b=A.point(b.x,b.y,b.z)}
end
A.line=line
local function rotate(x,y,r)
  if r==0 then return x,y
  elseif r==1 then return -y,x
  elseif r==2 then return -x,-y
  elseif r==3 then return y,-x end
  error("building anchor rotation must be 0..3")
end
function A.transform(edge,pose)
  assert(type(pose)=="table" and finite(pose.x) and finite(pose.y) and
    finite(pose.z) and type(pose.rotation)=="number" and
    pose.rotation==math.floor(pose.rotation),"invalid anchor pose")
  local function move(p)
    local x,y=rotate(p.x,p.y,pose.rotation)
    return A.point(x+pose.x,y+pose.y,p.z+pose.z)
  end
  return line(edge.name,edge.kind,move(edge.a),move(edge.b))
end
local function distance(a,b)
  return sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
function A.match(first,second,tolerance)
  tolerance=tolerance or 1e-6
  assert(finite(tolerance) and tolerance>=0,"invalid match tolerance")
  if first.kind~=second.kind then return false,"anchor_kind",nil end
  local direct=math.max(distance(first.a,second.a),distance(first.b,second.b))
  local inverse=math.max(distance(first.a,second.b),distance(first.b,second.a))
  local error=math.min(direct,inverse)
  if error>tolerance then return false,"anchor_gap",error end
  return true,"matched",error
end
function A.snap_translation(parent,child,reverse)
  assert(parent.kind==child.kind,"mismatched anchor families")
  -- Default lines must face in opposite directions at a join.
  if reverse==nil then reverse=true end
  local p=reverse and child.b or child.a
  local delta=A.point(parent.a.x-p.x,parent.a.y-p.y,parent.a.z-p.z)
  local relocated=A.transform(child,{x=delta.x,y=delta.y,z=delta.z,rotation=0})
  local ok,reason=A.match(parent,relocated)
  assert(ok,"unsnappable line: "..reason)
  return delta
end
function A.snap_piece(parent_id,parent_pose,parent_slot,child_id,child_rotation,child_slot)
  -- Match two named edge segments; return the child's exact world pose.
  local parent_line=assert(A.piece_line(parent_id,parent_slot))
  local child_line=assert(A.piece_line(child_id,child_slot))
  local parent_world=A.transform(parent_line,parent_pose)
  local child_oriented=A.transform(child_line,
    {x=0,y=0,z=0,rotation=child_rotation})
  if parent_world.kind~=child_oriented.kind then return nil,"anchor_kind" end
  for _,reverse in ipairs({false,true}) do
    local ok,delta=pcall(A.snap_translation,parent_world,child_oriented,reverse)
    if ok then
      return {x=delta.x,y=delta.y,z=delta.z,rotation=child_rotation}
    end
  end
  return nil,"unsnappable_piece"
end
function A.sprite_point(p,ppu,pivot_x,pivot_y)
  local sx,sy=Iso.project(p.x,p.y,p.z)
  return (pivot_x or 64)+(ppu or 2)*sx,(pivot_y or 92)+(ppu or 2)*sy
end
function A.piece_line(def_id,slot)
  local def=assert(Parts.get(def_id),"unknown construction definition")
  local shape=def.visual.shape
  local size=def.visual.module_size or def.size
  local half=size[1]/2
  if slot=="top" and (shape=="wall" or shape=="window" or shape=="doorway" or
    shape=="halfwall" or shape=="railing") then
    return line(def_id..".top","roof_eave",
      A.point(-half,0,size[3]),A.point(half,0,size[3]))
  end
  if shape=="roof_slope" then
    local half_y=size[2]/2
    if slot=="eave" then
      return line(def_id..".eave","roof_eave",
        A.point(-half,half_y,0),A.point(half,half_y,0))
    elseif slot=="ridge" then
      return line(def_id..".ridge","roof_ridge",
        A.point(-half,-half_y,size[3]),A.point(half,-half_y,size[3]))
    end
  end
  return nil,"undefined_piece_line"
end
function A.check_pairs(pairs)
  assert(type(pairs)=="table","anchor pair array required")
  local n,max_error=0,0
  for _,pair in ipairs(pairs) do
    local ok,why,error=A.match(pair[1],pair[2])
    if not ok then return false,why,n,error end
    n=n+1
    max_error=math.max(max_error,error or 0)
  end
  return true,n,max_error
end
return A
