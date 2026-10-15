-- Conservative Marching water footprint mask for resource placement only.
-- Same field, global 32-unit origin, level and triangle clipping as the renderer.
local Marching=require("world.marching")
local M={};M.__index=M
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function triangle_rect(tri,x,y,s)
  -- Triangle/axis-aligned rectangle SAT. Touching edges is conservatively blocked.
  local vertices={{x,y},{x+s,y},{x+s,y+s},{x,y+s}}
  local function overlap(nx,ny)
    local a,b=math.huge,-math.huge
    local c,d=math.huge,-math.huge
    for _,p in ipairs(tri) do local v=p[1]*nx+p[2]*ny;a=math.min(a,v);b=math.max(b,v) end
    for _,p in ipairs(vertices) do local v=p[1]*nx+p[2]*ny;c=math.min(c,v);d=math.max(d,v) end
    return a<=d+1e-9 and c<=b+1e-9
  end
  if not overlap(1,0) or not overlap(0,1) then return false end
  for k=1,3 do
    local a,b=tri[k],tri[k%3+1]
    if not overlap(-(b[2]-a[2]),b[1]-a[1]) then return false end
  end
  return true
end
function M.new(world,cell)
  assert(world and world.field and type(world.field.channel)=="function","scalar WorldQuery required")
  cell=cell or 8
  assert(finite(cell) and cell>0 and 32/cell==math.floor(32/cell),"collision cell must divide 32")
  return setmetatable({world=world,cell=cell,cache={},cache_size=0,max_cache=32768,patches={}},M)
end
function M:patch(ix,iy)
  local k=ix..":"..iy
  local p=self.patches[k]
  if p then return p end
  local geom=Marching.build(function(x,y) return self.world.field:channel(x,y,"water") end,ix*32,iy*32,32,32,0)
  p={}
  for i=1,#geom.vertices,3 do
    p[#p+1]={geom.vertices[i],geom.vertices[i+1],geom.vertices[i+2]}
  end
  -- Patch mesh is derived only from the seed; it may be regenerated after eviction.
  if self.patch_count==nil then self.patch_count=0 end
  if self.patch_count>=2048 then self.patches={};self.patch_count=0 end
  self.patches[k]=p;self.patch_count=self.patch_count+1
  return p
end
function M:blocked(ix,iy)
  local key=ix..":"..iy
  local b=self.cache[key]
  if b~=nil then return b end
  local c=self.cell
  local px,py=math.floor(ix*c/32),math.floor(iy*c/32)
  b=false
  for _,tri in ipairs(self:patch(px,py)) do
    if triangle_rect(tri,ix*c,iy*c,c) then b=true;break end
  end
  if self.cache_size>=self.max_cache then self.cache={};self.cache_size=0 end
  self.cache[key]=b;self.cache_size=self.cache_size+1
  return b
end
function M:obstacles(x1,y1,x2,y2)
  assert(finite(x1) and finite(y1) and finite(x2) and finite(y2) and x1<=x2 and y1<=y2,"invalid obstacle bounds")
  local c=self.cell
  local ax,ay,bx,by=math.floor(x1/c),math.floor(y1/c),math.floor(x2/c),math.floor(y2/c)
  assert((bx-ax+1)*(by-ay+1)<=4096,"collision query budget exceeded")
  local result={}
  for iy=ay,by do for ix=ax,bx do
    if self:blocked(ix,iy) then result[#result+1]={x=ix*c,y=iy*c,w=c,h=c} end
  end end
  return result
end
return M
