-- CPU-only, render-only 45-degree terrain mesh. Authoritative world query is read-only.
-- Chunk origins MUST lie on the shared world lattice (integer multiples of step).
-- vertices: {screen_x, screen_y, u, v, brightness, normal_x, normal_y, normal_z,
--            world_x, world_y, height, grade, wet}; triangles: 1-based vertex indices.
-- Wet is solely the existing query:water_mask result; never a new collision field.
local Iso=require("world.iso")
local Light=require("world.terrain25d_lighting")
local M={}
local sqrt=math.sqrt
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function integer(v) return finite(v) and v==math.floor(v) end
local function lattice(v,step)
 local index=v/step
 return math.abs(index-math.floor(index+.5))<1e-9
end
local function gradient(topo,x,y)
 -- topography:sample is the authoritative slope gradient; one world coordinate
 -- yields one identical normal in every neighbouring chunk.
 local s=topo:sample(x,y)
 assert(type(s)=="table" and finite(s.gradient_x) and finite(s.gradient_y),
  "invalid authored topography gradient")
 return s.gradient_x,s.gradient_y
end
function M.build_chunk(query,topography,options,chunk_origin,step)
 options=options or {}
 assert(type(options)=="table" and type(chunk_origin)=="table"
  and type(topography)=="table" and type(topography.height)=="function"
  and type(topography.sample)=="function","topography and chunk origin required")
 assert(query==nil or type(query)=="table","invalid world query")
 local x0,y0=chunk_origin.x,chunk_origin.y
 local size=options.size or chunk_origin.size or 256
 step=step or options.step or 16
 local scale=options.height_scale == nil and .35 or options.height_scale
 local uv_scale=options.uv_scale or 128
 assert(finite(x0) and finite(y0) and finite(size) and size>0
  and finite(step) and step>0 and integer(size/step) and size/step<=256
  and lattice(x0,step) and lattice(y0,step),"chunk must align to world lattice")
 assert(finite(scale) and scale>=0 and scale<=4 and finite(uv_scale) and uv_scale>0,
  "invalid render scale")
 local n=size/step
 local vertices,indices={},{}
 for iy=0,n do
  local y=y0+iy*step
  for ix=0,n do
   local x=x0+ix*step
   local h=topography:height(x,y)
   assert(finite(h),"nonfinite topography height")
   local gx,gy=gradient(topography,x,y)
   local nx,ny,nz=Light.normal(gx,gy,scale)
   local sx,sy=Iso.project(x,y,h*scale)
   local grade=sqrt(gx*gx+gy*gy)
   local wet=0
   if query and type(query.water_mask)=="function" then
    wet=query:water_mask(x,y) and 1 or 0
   end
   vertices[#vertices+1]={sx,sy,x/uv_scale,y/uv_scale,
    Light.shade(nx,ny,nz,options),nx,ny,nz,x,y,h,grade,wet}
  end
 end
 local stride=n+1
 for iy=0,n-1 do for ix=0,n-1 do
  local a=iy*stride+ix+1
  local b=a+1
  local c=a+stride
  local d=c+1
  -- Two shared triangles, no per-cell side wall or terracing.
  indices[#indices+1]=a;indices[#indices+1]=b;indices[#indices+1]=d
  indices[#indices+1]=a;indices[#indices+1]=d;indices[#indices+1]=c
 end end
 return {vertices=vertices,indices=indices,origin={x=x0,y=y0},
  size=size,step=step,height_scale=scale,columns=stride,rows=stride,
  format="terrain25d-v1",render_only=true}
end
-- Adapt index-buffer meshes into a LÖVE triangle list without constructing GPU objects.
-- UV and brightness are baked; no topography query during drawing.
function M.love_vertices(mesh)
 assert(mesh and mesh.format=="terrain25d-v1","invalid terrain25d mesh")
 local out={}
 for _,index in ipairs(mesh.indices) do
  local v=assert(mesh.vertices[index])
  out[#out+1]={v[1],v[2],v[3],v[4],v[5],v[5],v[5],1}
 end
 return out
end
return M
