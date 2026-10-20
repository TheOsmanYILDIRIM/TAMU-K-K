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
  return {vertices=v,released=false,release=function(self) self.released=true end}
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

-- Deterministic parity, bounded cooperative work and GPU eviction.
-- Exercise the real production timer path even though this is a CPU mesh mock.
love.timer={getTime=os.clock}
local iq=Query.new(20261015)
local staged=Stream.new(iq,{size=256,step=32,max_loaded=1,
 build_budget=1,generation_ms=.12})
local staged_cam=Camera.new()
staged_cam.x,staged_cam.y=128,128
local wanted=staged:needed(staged_cam,360,780)[1]
local ref_chunk=Chunks.new(iq,{size=256,step=32}):build(wanted.cx,wanted.cy)
local ref_stream={query=iq,visible=function() return {ref_chunk} end}
love.timer=nil
Terrain.draw(ref_stream,staged_cam,360,780,{atmosphere=false})
local expected=ref_chunk._terrain_meshes
love.timer={getTime=os.clock}
local first=staged:update(staged_cam,360,780)
assert(first.created==0,"a chunk should not block until full completion")
local nframes=0
local ready
repeat
 nframes=nframes+1
 staged:update(staged_cam,360,780)
 Terrain.draw(staged,staged_cam,360,780,{atmosphere=false})
 ready=staged:visible()[1]
 if ready and ready._terrain_meshes then break end
until nframes>=4000
assert(nframes<4000 and ready and ready._terrain_meshes,
 "time-sliced geometry failed to become visible")
for _,name in ipairs({"meadow","forest","rocky","water","detail"}) do
 local a,b=expected[name],ready._terrain_meshes[name]
 assert((a==nil)==(b==nil),"material layer missing: "..name)
 if a then
  assert(#a.vertices==#b.vertices,"triangle loss: "..name)
  for i=1,math.min(100,#a.vertices) do
   for k=1,8 do
    assert(math.abs(a.vertices[i][k]-b.vertices[i][k])<1e-9,
     "staged mesh changed geometry/color: "..name)
   end
  end
 end
end
local evicted_mesh=ready._terrain_meshes.meadow
staged_cam.x,staged_cam.y=9000,9000
staged:update(staged_cam,360,780)
assert(evicted_mesh.released,"evicted asynchronous terrain leaked GPU mesh")
print("CHUNK_PERF_INCREMENTAL_OK frames="..nframes.." layers=5 parity=1 eviction=1")

-- Fully prepared terrain must be persisted even when other nearby
-- chunks are still pending. Avoids losing complete geometry during travel.
local write_calls=0
local fake_cache={write=function(self,cx,cy,payload,checkpoint)
 write_calls=write_calls+1
 assert(type(payload)=="table" and cx==math.floor(cx) and
   cy==math.floor(cy),"invalid queued terrain write")
 return true
end}
local saving=Stream.new(iq,{size=256,step=32,max_loaded=12,
 build_budget=1,cache=fake_cache,generation_ms=.12})
local save_cam=Camera.new()
save_cam.x,save_cam.y=128,128
local near=saving:needed(save_cam,360,780)
assert(#near>1 and near[1].cx==0 and near[1].cy==0,
 "focal chunk must have highest stream priority")
local first_chunk=near[1]
saving.resident[first_chunk.key]={
 key=first_chunk.key,cx=first_chunk.cx,cy=first_chunk.cy,
 x=first_chunk.cx*256,y=first_chunk.cy*256,size=256,
 _terrain_meshes={meadow={release=function() end}},
 _cache_payload={meadow={},forest={},rocky={},water={},detail={}}}
local incomplete=saving:update(save_cam,360,780,0)
assert(incomplete.pending>0 and write_calls==1,
 "ready terrain was not cached with other chunks pending")
assert(saving.resident[first_chunk.key]._cache_payload==nil,
 "completed write still retains the large CPU vertex arrays")
saving:update(save_cam,360,780,0)
assert(write_calls==1,"already cached chunk was redundantly written")
print("CHUNK_CACHE_PENDING_SAVE_OK writes=1 pending="..incomplete.pending)

love=nil

-- Lightweight syntax gate; the expensive travel simulation is manual-only.
assert(loadfile("tests/r2_long_traversal.lua"),"long traversal profiler syntax invalid")
-- Renderer candidates must be queried once per resident chunk, not each
-- frame. Live depletion, regrowth, duplicate IDs, world replacement and
-- chunk re-entry must exactly retain original render/pick membership.
local Renderer=require("objects.renderer")
local objA={id="worldobj:v1:1:1:1",cx=0,cy=0,x=32,y=36,radius=6}
local objB={id="worldobj:v1:1:2:2",cx=1,cy=0,x=280,y=40,radius=7}
local objWrong={id="worldobj:v1:1:3:3",cx=2,cy=0,x=512,y=64,radius=3}
local calls=0
local depleted={}
local fixtureWorld={generator_version=1}
function fixtureWorld:is_depleted(id) return depleted[id]==true end
function fixtureWorld:objects_in(bounds,include_depleted)
 calls=calls+1
 local raw=bounds.min_x==0 and {objA,objWrong,objB} or {objB,objWrong}
 local out={}
 for _,o in ipairs(raw) do
  if include_depleted or not self:is_depleted(o.id) then out[#out+1]=o end
 end
 return out
end
local c0={key="0:0",cx=0,cy=0,x=0,y=0,size=256}
local c1={key="1:0",cx=1,cy=0,x=256,y=0,size=256}
local scene={visible=function() return {c0,c1} end}
local first=Renderer.collect(fixtureWorld,scene)
assert(#first==2 and first[1]==objA and first[2]==objB)
for i=1,30 do
 local again=Renderer.collect(fixtureWorld,scene)
 assert(#again==2 and again[1]==objA and again[2]==objB)
end
assert(calls==2,"renderer rescanned static chunk objects every frame")
depleted[objA.id]=true
local removed=Renderer.collect(fixtureWorld,scene)
assert(#removed==1 and removed[1]==objB and calls==2,
 "depleted object remains rendered or cache reruns world query")
depleted[objA.id]=nil -- R2 regrowth after world.day advancement
local grown=Renderer.collect(fixtureWorld,scene)
assert(#grown==2 and grown[1]==objA and calls==2,
 "regrown object missing from resident static candidates")
local replacement={generator_version=1,is_depleted=fixtureWorld.is_depleted,
 objects_in=fixtureWorld.objects_in}
Renderer.collect(replacement,scene)
assert(calls==4,"new world identity failed to invalidate render candidates")
local newChunk={key="0:0",cx=0,cy=0,x=0,y=0,size=256}
Renderer.collect(fixtureWorld,{visible=function() return {newChunk} end})
assert(calls==5,"revisited chunk did not refresh after eviction")
-- A future mutable world must retain legacy live queries.
local live={objects_in=fixtureWorld.objects_in,is_depleted=fixtureWorld.is_depleted}
Renderer.collect(live,scene);Renderer.collect(live,scene)
assert(calls==9,"non-v1 renderer queries were incorrectly cached")
print("OBJECT_RENDER_CACHE_OK static=2 liveDeplete=1 regrow=1 identity=1 revisit=1")

print("WORLD_STAGE2_TEST_OK seed, masks, seam, query, streaming, revisit")
