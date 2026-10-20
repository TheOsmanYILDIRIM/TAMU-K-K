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

-- V: the authored mask is never altered. Only its visual feather changes.
local edges=Materials.authored_edges({{
 polygon={{0,0},{100,0},{100,100},{0,100}}
}})
assert(#edges==4)
assert(Materials.authored_feather(edges,0,50,24)==0)
local soft=Materials.authored_feather(edges,12,50,24)
assert(soft>.05 and soft<1,"authored biome boundary must feather")
assert(Materials.authored_feather(edges,60,50,24)==1)
assert(soft==Materials.authored_feather(edges,12,50,24),
 "feather varies with call order/camera")
assert(not pcall(function() Materials.authored_feather(edges,0/0,50,24) end))

-- The REAL H facade uses a 22-world-unit river and valley floor at 704,128.
-- Refined DRAW geometry must still read exactly the C collision-water field.
local H=require("world.r2_compat_bridge")
local Json=require("save.json")
local function read_doc(name)
 local f=assert(io.open("../../data/worldbuild/"..name,"rb"))
 local bytes=f:read("*a");f:close()
 return Json.decode(bytes)
end
local h=H.new(read_doc("fisilti_ormani.r2.v1.json"),
 read_doc("osman_overworld.v2.json"))
local chunker=Chunks.new(h.query,{size=256,step=8})
local river=chunker:build(2,0)
local hs={query=h.query,visible=function() return {river} end}
local wet_before,signed_before=h.query:water_mask(704,128)
local height_before=h.topography:height(704,128)
assert(wet_before and signed_before>0)
Terrain.draw(hs,{x=704,y=128,zoom=1.4},720,1100,{
 topography=h.topography,routes=h.routes,quality="standard"})
-- World-space authored material must tint the background base BEFORE
-- transparent forest feather: this prevents glowing polygon outlines.
local bx,by=704,128
assert(h.query:sample(bx,by).biome=="forest")
local ex,ey=Iso.project(bx,by,h.topography:height(bx,by)*.35)
local expected=Materials.color("forest",bx,by)
local grad=h.topography:sample(bx,by)
local shading=Materials.light(grad.gradient_x,grad.gradient_y)
local checked=0
for _,v in ipairs(river._terrain_meshes.meadow.vertices) do
 if math.abs(v[1]-ex)<1e-7 and math.abs(v[2]-ey)<1e-7 then
  for k=1,3 do
   assert(math.abs(v[k+4]-math.min(1,expected[k]*shading))<1e-6,
     "authored underlay color mismatches biome")
  end
  checked=checked+1
 end
end
assert(checked>0,"missing background material sample at river crossing")
local refined=assert(river._terrain_meshes.water,"R2 authored water is invisible")
assert(#refined.vertices>#river.layers.water.vertices,
 "river should have more than the 8-unit marching contour")
for i=1,math.min(100,#refined.vertices) do
 local v=refined.vertices[i]
 assert(v[8]>=0 and v[8]<=1 and v[5]>=0 and v[5]<=1)
end
local function signature(drawable)
 local result={tostring(#drawable.vertices)}
 for i=1,math.min(90,#drawable.vertices) do
  local v=drawable.vertices[i]
  result[#result+1]=string.format("%.7f:%.7f:%.6f",v[1],v[2],v[8])
 end
 return table.concat(result,"|")
end
local first=signature(refined)
Terrain.invalidate(river)
Terrain.draw(hs,{x=744,y=104,zoom=1.4},720,1100,{
 topography=h.topography,routes=h.routes,quality="standard"})
assert(signature(river._terrain_meshes.water)==first,
 "water mesh changed after rebuild / camera pan")
local wet_after,signed_after=h.query:water_mask(704,128)
assert(wet_before==wet_after and signed_before==signed_after)
assert(height_before==h.topography:height(704,128))
assert(h.query:surface_at(704,128).speed_multiplier==.55)

-- Synthetic narrow world-space stream crossing a chunk boundary:
-- both neighbours must have identical projected border and vertex alpha.
local fake_field={channel=function(_,x,y,name)
 if name=="water" then return 12-math.abs(x-256) end
 return -1
end}
local fake_query={field=fake_field,
 sample=function() return {biome="meadow"} end}
local fake_routes={
 features={
  features={{kind="water",width=24,points={{256,0},{256,256}}}},
  signed=function(_,x,y) return 12-math.abs(x-256) end
 },
 surface_at=function() return {wet=false} end
}
local c=Chunks.new(fake_query,{size=256,step=8})
local lc,rc=c:build(0,0),c:build(1,0)
local fs={query=fake_query,visible=function() return {lc,rc} end}
Terrain.draw(fs,{x=256,y=128,zoom=1},720,1100,{
 routes=fake_routes,quality="standard",atmosphere=false})
local function seam(m)
 local seen={}
 for _,v in ipairs(m.vertices) do
  local x,y=Iso.unproject(v[1],v[2])
  if math.abs(x-256)<1e-6 then
   seen[string.format("%.6f:%.6f",y,v[8])]=true
  end
 end
 return seen
end
local lborder=seam(assert(lc._terrain_meshes.water))
local rborder=seam(assert(rc._terrain_meshes.water))
local common=0
for v in pairs(lborder) do
 assert(rborder[v],"authored water chunk seam alpha/position mismatch")
 common=common+1
end
assert(common>=40,"missing refined water seam vertices")
local stable=lc._terrain_meshes.water
Terrain.draw(fs,{x=300,y=100,zoom=1.6},720,1100,{
 routes=fake_routes,quality="standard",atmosphere=false})
assert(lc._terrain_meshes.water==stable,
 "camera movement unnecessarily rebuilt cached terrain")

-- Stream removes resident chunks by releasing chunk._meshes.
-- Terrain-owned GPU geometry must be registered on that existing path.
local Stream=require("world.stream")
local mobile=Stream.new(fake_query,{size=256,step=8,max_loaded=2,build_budget=2})
local Camera=require("core.camera")
local cam=Camera.new()
cam.x,cam.y,cam.zoom=256,128,1
mobile:update(cam,420,500,2)
Terrain.draw(mobile,cam,420,500,{routes=fake_routes,atmosphere=false})
local evicted
for _,ch in ipairs(mobile:visible()) do
 if ch._terrain_meshes and ch._terrain_meshes.water then
  evicted=ch._terrain_meshes.water
  break
 end
end
assert(evicted,"expected a nearby stream chunk with rendered water")
cam.x,cam.y=9000,9000
mobile:update(cam,420,500,2)
assert(evicted.released,"camera eviction leaked terrain GPU meshes")

print("R2_VISUAL_MATERIAL_MESH_OK variants=18 seam=9 profiles=3")
