-- Sparse world-space spatial hash for placed structures. No chunk residency dependency.
-- IDs are stable; bucket membership is updated only when geometry changes.
local Spatial={};Spatial.__index=Spatial
local function integer(n) return type(n)=="number" and n==math.floor(n) and n>-math.huge and n<math.huge end
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function bounds(b)
  assert(type(b)=="table" and finite(b.x) and finite(b.y) and finite(b.w) and finite(b.h)
    and b.w>0 and b.h>0,"invalid spatial bounds")
end
local function intersects(a,b)
  return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
function Spatial.new(cell)
  cell=cell or 64
  assert(integer(cell) and cell>=8 and cell<=1024,"invalid spatial cell")
  return setmetatable({cell=cell,buckets={},entries={},count=0},Spatial)
end
function Spatial:_keys(box)
  bounds(box)
  local c=self.cell
  local ax,ay=math.floor(box.x/c),math.floor(box.y/c)
  local bx,by=math.floor((box.x+box.w)/c),math.floor((box.y+box.h)/c)
  assert((bx-ax+1)*(by-ay+1)<=256,"spatial object/query budget exceeded")
  local keys={}
  for y=ay,by do for x=ax,bx do keys[#keys+1]=x..":"..y end end
  return keys
end
function Spatial:insert(id,box,value)
  assert(type(id)=="string" and #id>0 and not self.entries[id],"duplicate spatial ID")
  local keys=self:_keys(box)
  local entry={box={x=box.x,y=box.y,w=box.w,h=box.h},value=value,keys=keys}
  for _,key in ipairs(keys) do
    local bucket=self.buckets[key]
    if not bucket then bucket={};self.buckets[key]=bucket end
    bucket[id]=entry
  end
  self.entries[id]=entry;self.count=self.count+1
end
function Spatial:remove(id)
  local entry=self.entries[id]
  if not entry then return false end
  for _,key in ipairs(entry.keys) do
    local bucket=self.buckets[key]
    bucket[id]=nil
    if not next(bucket) then self.buckets[key]=nil end
  end
  self.entries[id]=nil;self.count=self.count-1
  return true
end
function Spatial:query(box)
  local keys=self:_keys(box)
  local seen,out={},{}
  for _,key in ipairs(keys) do
    for id,entry in pairs(self.buckets[key] or {}) do
      if not seen[id] and intersects(entry.box,box) then
        seen[id]=true;out[#out+1]=entry.value
      end
    end
  end
  table.sort(out,function(a,b)return a.id<b.id end)
  return out
end
return Spatial
