-- R2 D strict Lua5.4/LuaJIT: eighteen IDs, organic feather, chunk seams and B adapter.
package.path="./?.lua;./?/init.lua;"..package.path
local Materials=require("world.materials")
local Terrain=require("world.terrain_renderer")
local Query=require("world.world_query")
local Chunks=require("world.chunks")
local Iso=require("world.iso")
assert(#Materials.order==18,"material contract changed")
local seen={}
for _,id in ipairs(Materials.order) do assert(not seen[id]);seen[id]=true end
assert(seen["forest/moss"] and seen["rocky/lichen"])
for _,biome in ipairs({"meadow","forest","rocky"}) do
 for _,p in ipairs({{-4096,-4096},{0,0},{256,48},{28671,28671}}) do
  local x,y=p[1],p[2]
  local a,b=Materials.color(biome,x,y),Materials.color(biome,x,y)
  for k=1,3 do
   assert(a[k]==b[k] and a[k]>=0 and a[k]<=1)
   assert(math.abs(a[k]-Materials.color(biome,x+1e-6,y)[k])<1e-5)
  end
 end
end
assert(Materials.edge_alpha(0,.1)==0)
assert(Materials.edge_alpha(.1,.1)==1)
assert(math.abs(Materials.edge_alpha(.05,.1)-.5)<1e-9)
assert(not pcall(function() Materials.color("forest",0/0,0) end))
assert(not pcall(function() Terrain.profile("ultra") end))
assert(Terrain.profile("low").grid>Terrain.profile("high").grid)
local draw_count,rectangles=0,0
love={graphics={
 newMesh=function(vertices,mode,usage)
  assert(mode=="triangles" and usage=="static" and #vertices%3==0)
  local m={vertices=vertices,released=false}
  function m:release() self.released=true end
  return m
 end,
 clear=function() end,push=function() end,pop=function() end,
 translate=function() end,scale=function() end,
 setColor=function() end,draw=function() draw_count=draw_count+1 end,
 rectangle=function() rectangles=rectangles+1 end}}
local query=Query.new(20261015)
local chunks=Chunks.new(query,{size=256,step=32})
local a,b=chunks:build(0,0),chunks:build(1,0)
local stream={query=query,visible=function() return {a,b} end}
local camera={x=256,y=128,zoom=1}
local topo={
 height=function(_,x,y) return (x+y)*.01 end,
 sample=function(_,x,y) return {gradient_x=.01,gradient_y=.01} end}
Terrain.draw(stream,camera,360,780,{topography=topo,quality="standard"})
assert(draw_count>0 and a._terrain_meshes.meadow and b._terrain_meshes.meadow)
assert(rectangles==0,"hard-edged atmosphere overlay is prohibited")
local function key(v)
 return string.format("%.8f:%.8f:%.6f:%.6f:%.6f:%.4f",
   v[1],v[2],v[5],v[6],v[7],v[8])
end
local function shared(mesh,x)
 local result={}
 for _,v in ipairs(mesh.vertices) do
  for y=0,256,32 do
   local sx,sy=Iso.project(x,y,(x+y)*.01*.35)
   if math.abs(v[1]-sx)<1e-7 and math.abs(v[2]-sy)<1e-7 then
    result[key(v)]=true
   end
  end
 end
 return result
end
local left=shared(a._terrain_meshes.meadow,256)
local right=shared(b._terrain_meshes.meadow,256)
local n=0
for id in pairs(left) do
 assert(right[id],"chunk seam color or projection mismatch")
 n=n+1
end
assert(n==9,"expected nine common edge vertices")
local old=a._terrain_meshes.meadow
Terrain.draw(stream,camera,360,780,{topography=topo,quality="standard"})
assert(a._terrain_meshes.meadow==old,"unnecessary mesh rebuild")
Terrain.draw(stream,camera,360,780,{topography=topo,quality="low"})
assert(old.released and a._terrain_meshes.meadow~=old,"quality did not invalidate mesh")
Terrain.invalidate(a)
assert(a._terrain_meshes==nil)
assert(not pcall(function() Terrain.draw(stream,camera,360,780,{height_scale=-1}) end))
print("R2_VISUAL_MATERIAL_MESH_OK variants=18 seam=9 profiles=3")
