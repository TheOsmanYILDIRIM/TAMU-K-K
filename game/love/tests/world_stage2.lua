package.path="./?.lua;./?/init.lua;"..package.path
local Field=require("world.field")
local Query=require("world.world_query")
local Marching=require("world.marching")
local Chunks=require("world.chunks")
local Stream=require("world.stream")
local Camera=require("core.camera")

local function close(a,b,tol)
  assert(math.abs(a-b) <= (tol or 1e-8), tostring(a).." ~= "..tostring(b))
end

local field=Field.new(20261015)
local twin=Field.new(20261015)
local other=Field.new(20261016)
for _,p in ipairs({{0,0},{-17.6,12.1},{-512,-256},{2103.54,-934.1},{16384,8192}}) do
  close(field:noise(p[1],p[2],320,4),twin:noise(p[1],p[2],320,4))
  local a,b=field:sample(p[1],p[2]),twin:sample(p[1],p[2])
  assert(a.biome==b.biome and a.feature==b.feature and a.height==b.height)
end
assert(field:noise(135,789,123,1) ~= other:noise(135,789,123,1))
assert(not pcall(function() Field.new(-1) end))
assert(not pcall(function() field:sample(0/0,2) end))
assert(not pcall(function() field:channel(0,0,"invalid") end))
local seen={}
for x=-2400,2400,200 do for y=-2400,2400,200 do
  seen[field:sample(x,y).biome]=true
end end
assert(seen.meadow and seen.forest and seen.rocky,
       "seed should generate all three biomes")

local query=Query.new(20261015)
for _,p in ipairs({{-130,0},{0,0},{900,-700}}) do
  local x,y=p[1],p[2]
  local sample=query:sample(x,y)
  assert(query:get_biome(x,y)==sample.biome)
  assert(query:get_height(x,y)==sample.height)
  assert(query:get_feature(x,y)==sample.feature)
  assert(query:is_walkable(x,y)==sample.walkable)
end
assert(#query:get_obstacles({min_x=-50,min_y=-5,max_x=35,max_y=10})==0)
assert(not pcall(function() query:get_obstacles({min_x=4,max_x=3}) end))

local horizontal=function(_,y) return y-117 end
local left=Marching.build(horizontal,0,0,256,32,0)
local right=Marching.build(horizontal,256,0,256,32,0)
local function on_edge(contours,x)
  local points={}
  for _,pair in ipairs(contours) do
    for _,p in ipairs(pair) do
      if math.abs(p[1]-x)<1e-8 then points[#points+1]=p[2] end
    end
  end
  table.sort(points)
  return points
end
local aa,bb=on_edge(left.contours,256),on_edge(right.contours,256)
assert(#aa>0 and #aa==#bb,"neighbour chunks must share contour endpoints")
for i=1,#aa do close(aa[i],bb[i]) end
local saddle=Marching.build(function(x,y)
  return (x-.5)*(y-.5)
end,0,0,1,1,0)
assert(#saddle.contours==2)
assert(#left.vertices % 3==0 and #right.vertices%3==0)

local chunks=Chunks.new(query,{size=256,step=32})
local ch1,ch2=chunks:build(-1,0),chunks:build(-1,0)
assert(ch1.key=="-1:0" and ch1.x==-256 and ch1.y==0)
for _,layer in ipairs({"forest","rocky","water"}) do
  assert(#ch1.layers[layer].vertices == #ch2.layers[layer].vertices)
  assert(#ch1.layers[layer].contours == #ch2.layers[layer].contours)
  for i=1,math.min(18,#ch1.layers[layer].vertices) do
    close(ch1.layers[layer].vertices[i][1],ch2.layers[layer].vertices[i][1])
    close(ch1.layers[layer].vertices[i][2],ch2.layers[layer].vertices[i][2])
  end
end

local camera=Camera.new()
local stream=Stream.new(query,{size=256,step=64,max_loaded=16,build_budget=3})
local stats=stream:update(camera,720,1100)
assert(stats.created==3 and stats.loaded==3 and stats.needed<=16)
local origin_key=stream:visible()[1].key
for _=1,8 do stats=stream:update(camera,720,1100) end
assert(stats.loaded==stats.needed and stats.pending==0)
assert(stats.loaded<=16)
local before=stream.resident[origin_key]
camera.x,camera.y=15000,-12000
for _=1,8 do stats=stream:update(camera,720,1100) end
assert(stream.resident[origin_key]==nil,"far chunks must be evicted")
camera.x,camera.y=0,0
for _=1,8 do stats=stream:update(camera,720,1100) end
assert(stream.resident[origin_key] and stream.resident[origin_key]~=before)
assert(stats.loaded==stats.needed)
assert(not pcall(function() stream:update(camera,720,1100,-1) end))

-- Ajan I: controlled CPU-only baseline. A GPU timing or Android FPS claim is NOT
-- inferred from these synthetic frames. Both variants use identical camera paths.
local Terrain=require("world.terrain_renderer")
local Json=require("save.json")
local H=require("world.r2_compat_bridge")
local Renderer=require("objects.renderer")
local function read_map(name)
 local f=assert(io.open("../../data/worldbuild/"..name,"rb"))
 local bytes=f:read("*a");f:close()
 return Json.decode(bytes)
end
local authored=H.new(read_map("fisilti_ormani.r2.v1.json"),
 read_map("osman_overworld.v2.json"))
local mesh_count,vertex_count=0,0
love={graphics={
 newMesh=function(v,mode,usage)
  assert(mode=="triangles" and usage=="static")
  mesh_count=mesh_count+1;vertex_count=vertex_count+#v
  return {release=function() end}
 end,
 clear=function() end,push=function() end,pop=function() end,
 translate=function() end,scale=function() end,setColor=function() end,
 draw=function() end
}}
local function percentile(a,p)
 local copy={}
 for i,v in ipairs(a) do copy[i]=v end
 table.sort(copy)
 return copy[math.max(1,math.ceil(#copy*p))]
end
local function perf_scene(label,q,step,render_options,objs)
 collectgarbage("collect")
 local s=Stream.new(q,{size=256,step=step,max_loaded=12,build_budget=2})
 local camera=Camera.new()
 local paths={{0,0,1},{0,0,1},{256,0,1},{512,0,1},
   {768,0,1},{768,0,1},{768,0,1.5},{256,0,.85},
   {0,0,1},{0,0,1}}
 if label=="R2" then
  paths={{704,128,1},{704,128,1},{960,128,1},
    {1216,128,1},{704,128,1.4},{704,128,1.4},
    {448,128,.85},{704,128,1},{704,128,1},{960,128,1}}
 end
 local stream_ms,terrain_ms,frame_ms,build_ms={}, {}, {},{}
 local builds,loaded,peak_mem,visible_lag=0,0,0,0
 local oldbuild=s.chunker.build
 s.chunker.build=function(self,cx,cy)
  local begin=os.clock()
  local c=oldbuild(self,cx,cy)
  builds=builds+1;build_ms[#build_ms+1]=(os.clock()-begin)*1000
  return c
 end
 local before=collectgarbage("count")
 for _,p in ipairs(paths) do
  camera.x,camera.y,camera.zoom=p[1],p[2],p[3]
  local start=os.clock()
  local st=s:update(camera,360,780)
  local mid=os.clock()
  Terrain.draw(s,camera,360,780,render_options)
  local finish=os.clock()
  stream_ms[#stream_ms+1]=(mid-start)*1000
  terrain_ms[#terrain_ms+1]=(finish-mid)*1000
  frame_ms[#frame_ms+1]=(finish-start)*1000
  loaded=st.loaded
  visible_lag=visible_lag+st.pending
  peak_mem=math.max(peak_mem,collectgarbage("count")-before)
  if objs then
   local t=os.clock()
   Renderer.collect(objs,s)
   terrain_ms[#terrain_ms+1]=(os.clock()-t)*1000 -- object-query-only
  end
 end
 local function fmt(a)
  return string.format("p50=%.3f p95=%.3f p99=%.3f max=%.3f",
   percentile(a,.5),percentile(a,.95),percentile(a,.99),percentile(a,1))
 end
 print(string.format("CHUNK_PERF_BASELINE %s frames=%d builds=%d loaded=%d pendingSum=%d mesh=%d vertices=%d peakKiB=%.0f stream[%s] render[%s] frame[%s] build[%s]",
  label,#paths,builds,loaded,visible_lag,mesh_count,vertex_count,peak_mem,
  fmt(stream_ms),fmt(terrain_ms),fmt(frame_ms),fmt(build_ms)))
end
perf_scene("V1",Query.new(20261015),32,nil,nil)
mesh_count,vertex_count=0,0
perf_scene("R2",authored.query,8,{topography=authored.topography,
 routes=authored.routes,quality="standard"},authored.population)
love=nil

print("WORLD_STAGE2_TEST_OK seed, masks, seam, query, streaming, revisit")
